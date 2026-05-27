import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'model/channel_catalog_model.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final List<StreamVariant> variants;
  final int initialVariantIndex;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.variants,
    this.initialVariantIndex = 0,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const Duration _adaptiveCheckInterval = Duration(seconds: 4);
  static const Duration _bufferingDowngradeThreshold = Duration(seconds: 8);
  static const Duration _autoSwitchCooldown = Duration(seconds: 20);

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isSwitchingVariant = false;
  bool _showControls = true;
  bool _isScreenLocked = false;
  bool _showUnlockButton = false;
  double _aspectRatio = 16 / 9;
  late int _currentVariantIndex;
  Timer? _adaptiveTimer;
  Timer? _screenLockIndicatorTimer;
  DateTime? _bufferingStartedAt;
  DateTime? _lastAutoSwitchAt;
  Duration _lastObservedPosition = Duration.zero;
  int _stalledTicks = 0;

  final List<Map<String, dynamic>> _aspectRatios = [
    {'name': '16:9', 'ratio': 16 / 9},
    {'name': '4:3', 'ratio': 4 / 3},
    {'name': '21:9', 'ratio': 21 / 9},
    {'name': '1:1', 'ratio': 1.0},
    {'name': 'Auto', 'ratio': 0.0},
  ];

  int _currentAspectRatioIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentVariantIndex = widget.variants.isEmpty
        ? 0
        : _bestInitialVariantIndex(widget.variants);

    _initializeVariant(_currentVariantIndex);
    _adaptiveTimer = Timer.periodic(_adaptiveCheckInterval, (_) {
      _adaptiveQualityCheck();
    });
    _hideControlsAfterDelay();
  }

  @override
  void dispose() {
    _adaptiveTimer?.cancel();
    _screenLockIndicatorTimer?.cancel();
    _controller?.removeListener(_onControllerUpdated);
    unawaited(_controller?.dispose());
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  StreamVariant get _currentVariant => widget.variants[_currentVariantIndex];

  int _bestInitialVariantIndex(List<StreamVariant> variants) {
    if (variants.isEmpty) {
      return 0;
    }

    var bestIndex = 0;
    var bestScore = -1;
    for (var index = 0; index < variants.length; index++) {
      final variant = variants[index];
      final score =
          _qualityScore(variant.quality) +
          _qualityScore(variant.label) +
          _qualityScore(variant.title);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  int _qualityScore(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 0;
    }

    final normalized = value.toLowerCase();
    final match = RegExp(r'(\d{3,4})').firstMatch(normalized);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }

    if (normalized.contains('uhd') || normalized.contains('4k')) {
      return 4000;
    }
    if (normalized.contains('fhd') || normalized.contains('1080')) {
      return 1080;
    }
    if (normalized.contains('hd') || normalized.contains('720')) {
      return 720;
    }
    if (normalized.contains('sd') || normalized.contains('480')) {
      return 480;
    }

    return 0;
  }

  void _onControllerUpdated() {
    final controller = _controller;
    if (controller == null || !_isInitialized || _isSwitchingVariant) {
      return;
    }

    if (controller.value.hasError) {
      unawaited(_attemptAdaptiveDowngrade('Playback error'));
    }
  }

  void _adaptiveQualityCheck() {
    final controller = _controller;
    if (controller == null || !_isInitialized || _isSwitchingVariant) {
      return;
    }

    final value = controller.value;
    if (!value.isPlaying) {
      _bufferingStartedAt = null;
      _stalledTicks = 0;
      _lastObservedPosition = value.position;
      return;
    }

    if (value.isBuffering) {
      _bufferingStartedAt ??= DateTime.now();
      final bufferingDuration = DateTime.now().difference(_bufferingStartedAt!);
      if (bufferingDuration >= _bufferingDowngradeThreshold) {
        unawaited(_attemptAdaptiveDowngrade('Buffering too long'));
      }
      return;
    }

    _bufferingStartedAt = null;

    if (value.position <=
        _lastObservedPosition + const Duration(milliseconds: 250)) {
      _stalledTicks += 1;
    } else {
      _stalledTicks = 0;
    }
    _lastObservedPosition = value.position;

    if (_stalledTicks >= 3) {
      unawaited(_attemptAdaptiveDowngrade('Lag detected'));
    }
  }

  Future<void> _attemptAdaptiveDowngrade(String reason) async {
    if (_isSwitchingVariant || widget.variants.length <= 1) {
      return;
    }

    if (_currentVariantIndex >= widget.variants.length - 1) {
      return;
    }

    final now = DateTime.now();
    if (_lastAutoSwitchAt != null &&
        now.difference(_lastAutoSwitchAt!) < _autoSwitchCooldown) {
      return;
    }

    _lastAutoSwitchAt = now;
    final nextIndex = _currentVariantIndex + 1;
    final nextLabel = widget.variants[nextIndex].displayLabel;

    await _initializeVariant(nextIndex);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adaptive mode: $reason, switched to $nextLabel'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _initializeVariant(int variantIndex) async {
    if (widget.variants.isEmpty) {
      return;
    }

    if (variantIndex < 0 || variantIndex >= widget.variants.length) {
      return;
    }

    final previousController = _controller;
    previousController?.removeListener(_onControllerUpdated);
    setState(() {
      _isInitialized = false;
      _isSwitchingVariant = true;
      _currentVariantIndex = variantIndex;
    });

    await previousController?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.variants[variantIndex].url),
    );
    controller.addListener(_onControllerUpdated);

    try {
      await controller.initialize();
    } catch (_) {
      controller.removeListener(_onControllerUpdated);
      await controller.dispose();

      if (!mounted) {
        return;
      }

      if (variantIndex < widget.variants.length - 1) {
        final fallbackIndex = variantIndex + 1;
        final fallbackLabel = widget.variants[fallbackIndex].displayLabel;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.variants[variantIndex].displayLabel} unavailable, trying $fallbackLabel',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        await _initializeVariant(fallbackIndex);
        return;
      }

      setState(() {
        _controller = null;
        _isSwitchingVariant = false;
        _isInitialized = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load ${widget.variants[variantIndex].displayLabel}',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      controller.removeListener(_onControllerUpdated);
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _isInitialized = true;
      _isSwitchingVariant = false;
      _aspectRatio = controller.value.aspectRatio;
    });

    _bufferingStartedAt = null;
    _stalledTicks = 0;
    _lastObservedPosition = Duration.zero;

    await controller.play();
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
          _showUnlockButton = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      if (_isScreenLocked) {
        _showUnlockButton = !_showUnlockButton;
        if (_showUnlockButton) {
          _hideControlsAfterDelay();
        }
      } else {
        _showControls = !_showControls;
        if (_showControls) {
          _hideControlsAfterDelay();
        }
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      final controller = _controller;
      if (controller == null) {
        return;
      }
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  Future<void> _showQualityPicker() async {
    if (widget.variants.length <= 1) {
      return;
    }

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.variants.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, index) {
              final variant = widget.variants[index];
              final isSelected = index == _currentVariantIndex;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? Colors.blueAccent : Colors.white54,
                ),
                title: Text(
                  variant.displayLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  variant.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () => Navigator.pop(context, index),
              );
            },
          ),
        );
      },
    );

    if (selectedIndex != null && selectedIndex != _currentVariantIndex) {
      _lastAutoSwitchAt = DateTime.now();
      await _initializeVariant(selectedIndex);
    }
  }

  void _changeAspectRatio() {
    setState(() {
      _currentAspectRatioIndex =
          (_currentAspectRatioIndex + 1) % _aspectRatios.length;

      if (_aspectRatios[_currentAspectRatioIndex]['ratio'] == 0.0) {
        _aspectRatio = _controller?.value.aspectRatio ?? _aspectRatio;
      } else {
        _aspectRatio = _aspectRatios[_currentAspectRatioIndex]['ratio'];
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aspect Ratio: ${_aspectRatios[_currentAspectRatioIndex]['name']}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _rotateScreen() {
    final currentOrientation = MediaQuery.of(context).orientation;

    if (currentOrientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _toggleScreenLock() {
    setState(() {
      _isScreenLocked = !_isScreenLocked;
      if (_isScreenLocked) {
        _showControls = false;
        _showUnlockButton = false;
      } else {
        _showControls = true;
        _showUnlockButton = false;
        _hideControlsAfterDelay();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isScreenLocked ? 'Screen Locked' : 'Screen Unlocked'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _unlockScreen() {
    setState(() {
      _isScreenLocked = false;
      _showUnlockButton = false;
      _showControls = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Screen Unlocked'),
        duration: Duration(seconds: 1),
      ),
    );

    _hideControlsAfterDelay();
  }

  void _goBack() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variants.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.signal_wifi_off, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'No playable stream available',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isInitialized && _controller != null
            ? GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),
                    ),
                    if (_showControls && !_isScreenLocked)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          minimum: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _goBack,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (widget.variants.length > 1)
                                      TextButton.icon(
                                        onPressed: _showQualityPicker,
                                        icon: const Icon(
                                          Icons.hd,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          _currentVariant.displayLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.aspect_ratio,
                                        color: Colors.white,
                                      ),
                                      onPressed: _changeAspectRatio,
                                      tooltip: 'Change Aspect Ratio',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.screen_rotation,
                                        color: Colors.white,
                                      ),
                                      onPressed: _rotateScreen,
                                      tooltip: 'Rotate Screen',
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      iconSize: 64,
                                      icon: Icon(
                                        _controller!.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      onPressed: _togglePlayPause,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _isScreenLocked
                                            ? Icons.lock
                                            : Icons.lock_open,
                                        color: Colors.white,
                                      ),
                                      onPressed: _toggleScreenLock,
                                      tooltip: 'Toggle Screen Lock',
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _aspectRatios[_currentAspectRatioIndex]['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isScreenLocked && _showUnlockButton)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_open,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Screen is Locked',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap unlock to continue',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _unlockScreen,
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('Unlock'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_isSwitchingVariant)
                      Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
