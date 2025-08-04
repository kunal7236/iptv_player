import 'package:flutter/material.dart';
import 'video_player_screen.dart';
import 'model/json_conversion_model.dart' as model;

class ChannelListScreen extends StatefulWidget {
  final List<model.Stream> channels;

  const ChannelListScreen({super.key, required this.channels});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<model.Stream> _filteredChannels = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredChannels = widget.channels;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredChannels = widget.channels.where((channel) {
        final channelTitle = channel.title?.toLowerCase() ?? '';
        final searchQuery = _searchController.text.toLowerCase();
        return channelTitle.contains(searchQuery);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredChannels = widget.channels;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search channels...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                ),
              )
            : const Text("Live Channels"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search results count
          if (_isSearching && _searchController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[800],
              child: Text(
                '${_filteredChannels.length} channel(s) found',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          // Channel list
          Expanded(
            child:
                _filteredChannels.isEmpty && _searchController.text.isNotEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No channels found',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your search terms',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = _filteredChannels[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(channel.title ?? "Unnamed Channel"),
                          subtitle: Text(channel.quality ?? ""),
                          trailing: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.green,
                          ),
                          onTap: () {
                            if (channel.url != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(
                                    title: channel.title ?? "Channel",
                                    streamUrl: channel.url!,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
