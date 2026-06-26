/// Pre-level tips shown in a paginated carousel before driving starts.
class LevelBriefingSlide {
  final String title;
  final String body;

  const LevelBriefingSlide({
    required this.title,
    required this.body,
  });
}

class LevelBriefing {
  final String headline;
  final List<LevelBriefingSlide> slides;

  const LevelBriefing({
    required this.headline,
    required this.slides,
  });
}
