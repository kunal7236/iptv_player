import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  bool _isScreenLocked = false;
  bool _showUnlockButton = false;
  double _aspectRatio = 16 / 9; // Default aspect ratio
  BoxFit _videoFit = BoxFit.contain;

  // Aspect ratio presets
  final List<Map<String, dynamic>> _aspectRatios = [
    {'name': '16:9', 'ratio': 16 / 9},
    {'name': '4:3', 'ratio': 4 / 3},
    {'name': '21:9', 'ratio': 21 / 9},
    {'name': '1:1', 'ratio': 1.0},
    {'name': 'Auto', 'ratio': 0.0}, // 0.0 indicates original aspect ratio
  ];

  int _currentAspectRatioIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          // Set initial aspect ratio to video's natural ratio
          _aspectRatio = _controller.value.aspectRatio;
        });
        _controller.play();
      });

    // Hide controls after 3 seconds
    _hideControlsAfterDelay();
  }

  @override
  void dispose() {
    _controller.dispose();
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
        // When screen is locked, toggle unlock button visibility
        _showUnlockButton = !_showUnlockButton;
        if (_showUnlockButton) {
          _hideControlsAfterDelay();
        }
      } else {
        // Normal behavior when not locked
        _showControls = !_showControls;
        if (_showControls) {
          _hideControlsAfterDelay();
        }
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  void _changeAspectRatio() {
    setState(() {
      _currentAspectRatioIndex =
          (_currentAspectRatioIndex + 1) % _aspectRatios.length;

      if (_aspectRatios[_currentAspectRatioIndex]['ratio'] == 0.0) {
        // Auto - use video's original aspect ratio
        _aspectRatio = _controller.value.aspectRatio;
      } else {
        _aspectRatio = _aspectRatios[_currentAspectRatioIndex]['ratio'];
      }
    });

    // Show snackbar with current aspect ratio
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aspect Ratio: ${_aspectRatios[_currentAspectRatioIndex]['name']}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleVideoFit() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Video Fit: ${_videoFit == BoxFit.contain ? 'Fit to Screen' : 'Fill Screen'}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      // Enter fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Exit fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _rotateScreen() {
    // Get current orientation
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
        _showUnlockButton = false; // Start with unlock button hidden
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  // Video Player
                  Center(
                    child: AspectRatio(
                      aspectRatio: _aspectRatio,
                      child: FittedBox(
                        fit: _videoFit,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  ),

                  // Controls Overlay
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
                      child: Column(
                        children: [
                          // Top Controls
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context),
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
                                // Aspect Ratio Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.aspect_ratio,
                                    color: Colors.white,
                                  ),
                                  onPressed: _changeAspectRatio,
                                  tooltip: 'Change Aspect Ratio',
                                ),
                                // Fit to Screen Button
                                IconButton(
                                  icon: Icon(
                                    _videoFit == BoxFit.contain
                                        ? Icons.fit_screen
                                        : Icons.fullscreen,
                                    color: Colors.white,
                                  ),
                                  onPressed: _toggleVideoFit,
                                  tooltip: 'Toggle Video Fit',
                                ),
                                // Fullscreen Button
                                IconButton(
                                  icon: Icon(
                                    _isFullScreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: Colors.white,
                                  ),
                                  onPressed: _toggleFullScreen,
                                  tooltip: 'Toggle Fullscreen',
                                ),
                              ],
                            ),
                          ),

                          // Center Play/Pause Button
                          Expanded(
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  iconSize: 64,
                                  icon: Icon(
                                    _controller.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                              ),
                            ),
                          ),

                          // Bottom Controls
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Screen Lock Button
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

                                // Rotate Screen Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.screen_rotation,
                                    color: Colors.white,
                                  ),
                                  onPressed: _rotateScreen,
                                  tooltip: 'Rotate Screen',
                                ),

                                const Spacer(),

                                // Current Aspect Ratio Indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
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

                  // Screen Lock Indicator
                  if (_isScreenLocked && !_showUnlockButton)
                    Positioned(
                      top: 50,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Screen Locked',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap screen to unlock',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Unlock Button Overlay
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
    );
  }
}
