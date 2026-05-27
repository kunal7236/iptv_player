class StreamVariant {
  final String? feed;
  final String? label;
  final String? quality;
  final String? referrer;
  final String? title;
  final String url;
  final String? userAgent;

  StreamVariant({
    this.feed,
    this.label,
    this.quality,
    this.referrer,
    this.title,
    required this.url,
    this.userAgent,
  });

  String get displayQuality =>
      quality?.trim().isNotEmpty == true ? quality!.trim() : 'Live';

  String get displayLabel =>
      label?.trim().isNotEmpty == true ? label!.trim() : displayQuality;
}

class ChannelCard {
  final String id;
  final String name;
  final String? logo;
  final int? logoWidth;
  final int? logoHeight;
  final String? country;
  final List<String> categories;
  final List<String> languages;
  final List<StreamVariant> variants;
  final Set<String> searchTokens;

  ChannelCard({
    required this.id,
    required this.name,
    required this.logo,
    required this.logoWidth,
    required this.logoHeight,
    required this.country,
    required this.categories,
    required this.languages,
    required this.variants,
  }) : searchTokens = _buildSearchTokens(
         id: id,
         name: name,
         logo: logo,
         country: country,
         categories: categories,
         languages: languages,
         variants: variants,
       );

  String get primaryCategory => categories.isEmpty ? 'Other' : categories.first;
}

class ChannelCatalog {
  final List<ChannelCard> channels;
  final List<String> categories;
  final ChannelSearchTrie trie;

  ChannelCatalog({
    required this.channels,
    required this.categories,
    required this.trie,
  });

  factory ChannelCatalog.fromApiData({
    required List<dynamic> channelsJson,
    required List<dynamic> logosJson,
    required List<dynamic> feedsJson,
    required List<dynamic> streamsJson,
  }) {
    final logosByChannel = <String, List<_LogoAsset>>{};
    for (final rawLogo in logosJson) {
      if (rawLogo is! Map) {
        continue;
      }

      final channelId = rawLogo['channel']?.toString();
      final url = rawLogo['url']?.toString();
      final format = rawLogo['format']?.toString().toUpperCase();
      if (channelId == null ||
          channelId.isEmpty ||
          url == null ||
          url.isEmpty) {
        continue;
      }

      if (!_isSupportedLogoFormat(format)) {
        continue;
      }

      logosByChannel
          .putIfAbsent(channelId, () => <_LogoAsset>[])
          .add(
            _LogoAsset(
              url: url,
              width: _parsePositiveInt(rawLogo['width']),
              height: _parsePositiveInt(rawLogo['height']),
              feed: rawLogo['feed']?.toString(),
              inUse: rawLogo['in_use'] == true,
            ),
          );
    }

    final streamsByChannel = <String, List<StreamVariant>>{};
    for (final rawStream in streamsJson) {
      if (rawStream is! Map) {
        continue;
      }

      final channelId = rawStream['channel']?.toString();
      final url = rawStream['url']?.toString();
      if (channelId == null ||
          channelId.isEmpty ||
          url == null ||
          url.isEmpty) {
        continue;
      }

      streamsByChannel
          .putIfAbsent(channelId, () => <StreamVariant>[])
          .add(
            StreamVariant(
              feed: rawStream['feed']?.toString(),
              label: rawStream['label']?.toString(),
              quality: rawStream['quality']?.toString(),
              referrer: rawStream['referrer']?.toString(),
              title: rawStream['title']?.toString(),
              url: url,
              userAgent: rawStream['user_agent']?.toString(),
            ),
          );
    }

    final feedsByChannel = <String, List<Map<String, dynamic>>>{};
    for (final rawFeed in feedsJson) {
      if (rawFeed is! Map) {
        continue;
      }

      final channelId = rawFeed['channel']?.toString();
      if (channelId == null || channelId.isEmpty) {
        continue;
      }

      feedsByChannel
          .putIfAbsent(channelId, () => <Map<String, dynamic>>[])
          .add(Map<String, dynamic>.from(rawFeed.cast<String, dynamic>()));
    }

    final channels = <ChannelCard>[];
    for (final rawChannel in channelsJson) {
      if (rawChannel is! Map) {
        continue;
      }

      final channelId = rawChannel['id']?.toString();
      final country = rawChannel['country']?.toString();
      if (channelId == null || channelId.isEmpty || country != 'IN') {
        continue;
      }

      final variants = _sortVariants(
        streamsByChannel[channelId] ?? const <StreamVariant>[],
      );
      if (variants.isEmpty) {
        continue;
      }

      final name =
          rawChannel['name']?.toString() ??
          rawChannel['title']?.toString() ??
          channelId;
      final categories = _asStringList(rawChannel['categories']);
      final languages = _extractLanguages(feedsByChannel[channelId]);
      final logo = _selectLogoAsset(logosByChannel[channelId], variants);

      channels.add(
        ChannelCard(
          id: channelId,
          name: name,
          logo: logo?.url,
          logoWidth: logo?.width,
          logoHeight: logo?.height,
          country: country,
          categories: categories,
          languages: languages,
          variants: variants,
        ),
      );
    }

    channels.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );

    final trie = ChannelSearchTrie();
    for (final channel in channels) {
      trie.insert(channel);
    }

    final categories = <String>{'All'};
    for (final channel in channels) {
      categories.addAll(channel.categories);
    }

    final sortedCategories = categories.toList()
      ..remove('All')
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );

    return ChannelCatalog(
      channels: channels,
      categories: <String>['All', ...sortedCategories],
      trie: trie,
    );
  }

  List<ChannelCard> search({required String query, required String category}) {
    final categoryFiltered = category == 'All'
        ? channels
        : channels
              .where((channel) => channel.categories.contains(category))
              .toList();

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return categoryFiltered;
    }

    final matchingIds = trie.search(normalizedQuery);
    return categoryFiltered
        .where((channel) => matchingIds.contains(channel.id))
        .toList();
  }
}

class ChannelSearchTrie {
  final _TrieNode _root = _TrieNode();
  final Map<String, ChannelCard> _channelsById = {};

  void insert(ChannelCard channel) {
    _channelsById[channel.id] = channel;

    for (final token in channel.searchTokens) {
      if (token.isEmpty) {
        continue;
      }

      _insertToken(token, channel.id);
    }
  }

  Set<String> search(String query) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) {
      return _channelsById.keys.toSet();
    }

    Set<String>? result;
    for (final token in tokens) {
      final matches = _searchPrefix(token);
      result = result == null ? matches : result.intersection(matches);

      if (result.isEmpty) {
        return result;
      }
    }

    return result ?? <String>{};
  }

  void _insertToken(String token, String channelId) {
    var node = _root;
    for (final rune in token.runes) {
      final character = String.fromCharCode(rune);
      node = node.children.putIfAbsent(character, () => _TrieNode());
      node.channelIds.add(channelId);
    }
  }

  Set<String> _searchPrefix(String prefix) {
    var node = _root;
    for (final rune in prefix.runes) {
      final character = String.fromCharCode(rune);
      final nextNode = node.children[character];
      if (nextNode == null) {
        return <String>{};
      }
      node = nextNode;
    }

    return Set<String>.from(node.channelIds);
  }
}

class _TrieNode {
  final Map<String, _TrieNode> children = {};
  final Set<String> channelIds = <String>{};
}

Set<String> _buildSearchTokens({
  required String id,
  required String name,
  required String? logo,
  required String? country,
  required List<String> categories,
  required List<String> languages,
  required List<StreamVariant> variants,
}) {
  final tokens = <String>{};
  _addTokens(tokens, id);
  _addTokens(tokens, name);
  _addTokens(tokens, logo);
  _addTokens(tokens, country);

  for (final category in categories) {
    _addTokens(tokens, category);
  }

  for (final language in languages) {
    _addTokens(tokens, language);
  }

  for (final variant in variants) {
    _addTokens(tokens, variant.title);
    _addTokens(tokens, variant.feed);
    _addTokens(tokens, variant.label);
    _addTokens(tokens, variant.quality);
  }

  return tokens;
}

void _addTokens(Set<String> tokens, String? value) {
  for (final token in _tokenize(value)) {
    tokens.add(token);
  }
}

List<String> _tokenize(String? value) {
  if (value == null) {
    return const [];
  }

  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  if (value is String && value.trim().isNotEmpty) {
    return <String>[value.trim()];
  }

  return const <String>[];
}

List<String> _extractLanguages(List<Map<String, dynamic>>? feeds) {
  if (feeds == null || feeds.isEmpty) {
    return const <String>[];
  }

  final languages = <String>{};
  for (final feed in feeds) {
    languages.addAll(_asStringList(feed['languages']));

    final language = feed['language']?.toString();
    if (language != null && language.trim().isNotEmpty) {
      languages.add(language.trim());
    }
  }

  final sortedLanguages = languages.toList()
    ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return sortedLanguages;
}

List<StreamVariant> _sortVariants(List<StreamVariant> variants) {
  final sortedVariants = [...variants];
  sortedVariants.sort(
    (left, right) => _compareQuality(right.quality, left.quality),
  );
  return sortedVariants;
}

int _compareQuality(String? left, String? right) {
  final leftScore = _qualityScore(left);
  final rightScore = _qualityScore(right);
  return leftScore.compareTo(rightScore);
}

int _qualityScore(String? quality) {
  if (quality == null || quality.trim().isEmpty) {
    return 0;
  }

  final normalized = quality.toLowerCase();
  final match = RegExp(r'(\d{3,4})').firstMatch(normalized);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  if (normalized.contains('uhd') || normalized.contains('4k')) {
    return 4000;
  }

  if (normalized.contains('live')) {
    return 1;
  }

  return 0;
}

bool _isSupportedLogoFormat(String? format) {
  switch (format) {
    case 'PNG':
    case 'JPEG':
    case 'JPG':
    case 'GIF':
    case 'WEBP':
      return true;
    default:
      return false;
  }
}

_LogoAsset? _selectLogoAsset(
  List<_LogoAsset>? logos,
  List<StreamVariant> variants,
) {
  if (logos == null || logos.isEmpty) {
    return null;
  }

  final variantFeeds = variants
      .map((variant) => variant.feed?.toString())
      .whereType<String>()
      .toSet();

  _LogoAsset? selectedLogo;
  for (final logo in logos) {
    final feed = logo.feed;
    if (feed != null && feed.isNotEmpty && variantFeeds.contains(feed)) {
      if (logo.inUse) {
        return logo;
      }
      selectedLogo ??= logo;
    }
  }

  selectedLogo ??= logos.firstWhere(
    (logo) => logo.inUse,
    orElse: () => logos.first,
  );

  return selectedLogo;
}

int? _parsePositiveInt(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    return null;
  }

  return parsed;
}

class _LogoAsset {
  final String url;
  final int? width;
  final int? height;
  final String? feed;
  final bool inUse;

  const _LogoAsset({
    required this.url,
    required this.width,
    required this.height,
    required this.feed,
    required this.inUse,
  });
}
