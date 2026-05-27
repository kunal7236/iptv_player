import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model/channel_catalog_model.dart';

class IptvRepository {
  static const String _channelsUrl =
      'https://iptv-org.github.io/api/channels.json';
  static const String _logosUrl = 'https://iptv-org.github.io/api/logos.json';
  static const String _feedsUrl = 'https://iptv-org.github.io/api/feeds.json';
  static const String _streamsUrl =
      'https://iptv-org.github.io/api/streams.json';

  List<dynamic> _channels = [];
  List<dynamic> _logos = [];
  List<dynamic> _feeds = [];
  List<dynamic> _streams = [];
  ChannelCatalog? _cachedCatalog;

  Future<void> fetchAllData() async {
    final responses = await Future.wait<http.Response>([
      http.get(Uri.parse(_channelsUrl)),
      http.get(Uri.parse(_logosUrl)),
      http.get(Uri.parse(_feedsUrl)),
      http.get(Uri.parse(_streamsUrl)),
    ]);

    for (final response in responses) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to load IPTV API data (${response.statusCode}).',
        );
      }
    }

    _channels = _decodeJsonArray(responses[0].body, 'channels');
    _logos = _decodeJsonArray(responses[1].body, 'logos');
    _feeds = _decodeJsonArray(responses[2].body, 'feeds');
    _streams = _decodeJsonArray(responses[3].body, 'streams');
    _cachedCatalog = null;
  }

  Future<ChannelCatalog> fetchCatalog() async {
    if (_cachedCatalog != null) {
      return _cachedCatalog!;
    }

    if (_channels.isEmpty || _feeds.isEmpty || _streams.isEmpty) {
      await fetchAllData();
    }

    _cachedCatalog = ChannelCatalog.fromApiData(
      channelsJson: _channels,
      logosJson: _logos,
      feedsJson: _feeds,
      streamsJson: _streams,
    );

    return _cachedCatalog!;
  }

  List<dynamic> _decodeJsonArray(String body, String label) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw FormatException('Expected $label response to be a JSON array.');
    }

    return decoded;
  }
}
