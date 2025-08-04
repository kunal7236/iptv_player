class Stream {
  final String? channel;
  final String? feed;
  final String? quality;
  final String? referrer;
  final String? title;
  final String? url;
  final String? userAgent;

  Stream({
    this.channel,
    this.feed,
    this.quality,
    this.referrer,
    this.title,
    this.url,
    this.userAgent,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      channel: json['channel'],
      feed: json['feed'],
      quality: json['quality'],
      referrer: json['referrer'],
      title: json['title'],
      url: json['url'],
      userAgent: json['user_agent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel': channel,
      'feed': feed,
      'quality': quality,
      'referrer': referrer,
      'title': title,
      'url': url,
      'user_agent': userAgent,
    };
  }
}