/// Internet radio station from [RadioApiService].
class RadioStation {
  const RadioStation({
    required this.name,
    required this.streamUrl,
    this.country,
    this.tags = const [],
    this.faviconUrl,
  });

  final String name;
  final String streamUrl;
  final String? country;
  final List<String> tags;
  final String? faviconUrl;

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as String? ?? '';
    final tags = rawTags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final resolved = (json['url_resolved'] as String?)?.trim();
    final url = (json['url'] as String?)?.trim();

    return RadioStation(
      name: (json['name'] as String?)?.trim() ?? 'Unknown station',
      streamUrl: _pickStreamUrl(resolved, url),
      country: (json['country'] as String?)?.trim(),
      tags: tags,
      faviconUrl: (json['favicon'] as String?)?.trim(),
    );
  }

  /// Prefer HTTPS when both schemes are available.
  static String _pickStreamUrl(String? resolved, String? url) {
    String? https;
    String? http;
    for (final candidate in [resolved, url]) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) continue;
      final lower = value.toLowerCase();
      if (lower.startsWith('https://')) {
        https ??= value;
      } else if (lower.startsWith('http://')) {
        http ??= value;
      }
    }
    return https ?? http ?? '';
  }

  bool get usesHttps => streamUrl.toLowerCase().startsWith('https://');
}
