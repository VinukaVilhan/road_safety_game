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
      streamUrl: (resolved != null && resolved.isNotEmpty) ? resolved : (url ?? ''),
      country: (json['country'] as String?)?.trim(),
      tags: tags,
      faviconUrl: (json['favicon'] as String?)?.trim(),
    );
  }
}
