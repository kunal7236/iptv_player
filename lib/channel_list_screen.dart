import 'dart:async';

import 'package:flutter/material.dart';
import 'model/channel_catalog_model.dart';
import 'video_player_screen.dart';

class ChannelListScreen extends StatefulWidget {
  final ChannelCatalog catalog;

  const ChannelListScreen({super.key, required this.catalog});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 24;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _filterDebounce;

  late final TabController _tabController;
  List<ChannelCard> _visibleChannels = [];
  int _visibleLimit = _pageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.catalog.categories.length,
      vsync: this,
    );
    _tabController.addListener(_handleCategoryChanged);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_handleScroll);
    _applyFilters();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _tabController.removeListener(_handleCategoryChanged);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCategoryChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    _applyFilters();
  }

  void _onSearchChanged() {
    _scheduleFilterUpdate();
  }

  void _scheduleFilterUpdate() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 180), _applyFilters);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final remainingPixels =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remainingPixels < 800) {
      _loadMore();
    }
  }

  String get _selectedCategory {
    if (widget.catalog.categories.isEmpty) {
      return 'All';
    }

    final categoryIndex = _tabController.index.clamp(
      0,
      widget.catalog.categories.length - 1,
    );

    return widget.catalog.categories[categoryIndex];
  }

  void _applyFilters() {
    final results = widget.catalog.search(
      query: _searchController.text,
      category: _selectedCategory,
    );

    setState(() {
      _visibleChannels = results;
      _visibleLimit = results.isEmpty ? 0 : _pageSize;
    });
  }

  void _loadMore() {
    if (_visibleLimit >= _visibleChannels.length) {
      return;
    }

    setState(() {
      _visibleLimit = (_visibleLimit + _pageSize).clamp(
        0,
        _visibleChannels.length,
      );
    });
  }

  void _openChannel(ChannelCard channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoPlayerScreen(title: channel.name, variants: channel.variants),
      ),
    );
  }

  int _gridColumnCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      return 5;
    }
    if (width >= 900) {
      return 4;
    }
    if (width >= 600) {
      return 3;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final channelsToShow = _visibleChannels.take(_visibleLimit).toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search channels',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final category in widget.catalog.categories)
              Tab(text: category),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black26,
              child: Text(
                '${_visibleChannels.length} channel(s) • ${_selectedCategory == 'All' ? 'All categories' : _selectedCategory}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: channelsToShow.isEmpty
                  ? _EmptyState(
                      query: _searchController.text,
                      category: _selectedCategory,
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + bottomInset,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridColumnCount(context),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      cacheExtent: 500,
                      itemCount:
                          channelsToShow.length +
                          (_visibleLimit < _visibleChannels.length ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= channelsToShow.length) {
                          return const _LoadingTile();
                        }

                        final channel = channelsToShow[index];
                        return _ChannelTile(
                          channel: channel,
                          onTap: () => _openChannel(channel),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ChannelCard channel;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    return Material(
      color: const Color(0xFF15181F),
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1D2430), Color(0xFF111318)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (channel.logo != null && channel.logo!.isNotEmpty)
                          _ChannelLogoImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.cover,
                            sourceWidth: channel.logoWidth,
                            sourceHeight: channel.logoHeight,
                            fallback: _LogoFallback(channel: channel),
                          )
                        else
                          _LogoFallback(channel: channel),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.82),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _Badge(text: channel.primaryCategory),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _Badge(
                            text:
                                '${channel.variants.length} '
                                '${channel.variants.length == 1 ? 'quality' : 'qualities'}',
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Text(
                            channel.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (channel.country != null)
                      _MiniChip(text: channel.country!),
                    if (channel.languages.isNotEmpty)
                      _MiniChip(text: channel.languages.first),
                    if (channel.variants.isNotEmpty)
                      _MiniChip(text: channel.variants.first.displayQuality),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogoImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget fallback;
  final int? sourceWidth;
  final int? sourceHeight;

  const _ChannelLogoImage({
    required this.imageUrl,
    required this.fit,
    required this.fallback,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      return fallback;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final targetWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * devicePixelRatio).round()
            : null;
        final targetHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight * devicePixelRatio).round()
            : null;

        return Image.network(
          imageUrl,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.low,
          cacheWidth: _scaledCacheDimension(targetWidth, sourceWidth),
          cacheHeight: _scaledCacheDimension(targetHeight, sourceHeight),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      },
    );
  }
}

int? _scaledCacheDimension(int? targetDimension, int? sourceDimension) {
  if (targetDimension == null || targetDimension <= 0) {
    return sourceDimension;
  }

  if (sourceDimension == null || sourceDimension <= 0) {
    return targetDimension;
  }

  return targetDimension < sourceDimension ? targetDimension : sourceDimension;
}

class _LogoFallback extends StatelessWidget {
  final ChannelCard channel;

  const _LogoFallback({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C4A5E), Color(0xFF1C2230)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv, color: Colors.white70, size: 42),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                channel.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;

  const _MiniChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final String category;

  const _EmptyState({required this.query, required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No channels found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Try another category'
                  : 'No matches for "$query" in $category',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
