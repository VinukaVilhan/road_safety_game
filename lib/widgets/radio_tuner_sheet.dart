import 'package:flutter/material.dart';

import '../services/audio/music_service.dart';
import '../services/audio/radio_api_service.dart';
import '../services/audio/radio_station.dart';

/// In-app internet radio: stations from Radio Browser API, playback via [MusicService].
class RadioTunerSheet extends StatefulWidget {
  const RadioTunerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const RadioTunerSheet(),
    );
  }

  @override
  State<RadioTunerSheet> createState() => _RadioTunerSheetState();
}

class _RadioTunerSheetState extends State<RadioTunerSheet> {
  final MusicService _music = MusicService();
  final TextEditingController _searchController = TextEditingController();

  List<RadioStation> _stations = [];
  String? _error;
  bool _loading = true;
  RadioStation? _currentStation;
  String? _playbackError;

  void _onDrivingLessonChanged() {
    if (!mounted) return;
    if (!_music.isDrivingLessonActive) {
      setState(() {
        _currentStation = null;
        _playbackError = null;
      });
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _music.drivingLessonActive.addListener(_onDrivingLessonChanged);
    _loadStations();
  }

  @override
  void dispose() {
    _music.drivingLessonActive.removeListener(_onDrivingLessonChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = query == null
          ? await RadioApiService.fetchPopular()
          : await RadioApiService.search(query: query);
      if (!mounted) return;
      setState(() {
        _stations = list;
        _loading = false;
        if (list.isEmpty) {
          _error = 'No stations found. Try another search.';
        }
      });
    } on RadioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load stations: $e';
      });
    }
  }

  Future<void> _playStation(RadioStation station) async {
    setState(() {
      _playbackError = null;
      _currentStation = station;
    });

    final err = await _music.playUrl(station.streamUrl);
    if (!mounted) return;
    setState(() => _playbackError = err);
  }

  Future<void> _togglePlayback() async {
    await _music.togglePlayPause();
    if (mounted) setState(() {});
  }

  Future<void> _stopPlayback() async {
    await _music.stop();
    if (!mounted) return;
    setState(() {
      _currentStation = null;
      _playbackError = null;
    });
  }

  void _onSearchSubmitted(String value) {
    _loadStations(query: value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Internet radio',
                style: theme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stations load from the Radio Browser API and play inside the game '
                'while the lesson is active.',
                style: theme.bodySmall!.copyWith(color: Colors.white60, height: 1.35),
              ),
              if (!_music.isDrivingLessonActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Radio starts after the level briefing. Playback stops when the lesson ends.',
                    style: theme.bodySmall!.copyWith(color: Colors.orange.shade200, height: 1.3),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search stations…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      _loadStations();
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF252540),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
              ),
              if (_currentStation != null) ...[
                const SizedBox(height: 12),
                _NowPlayingBar(
                  station: _currentStation!,
                  isPlaying: _music.isPlaying,
                  error: _playbackError,
                  onToggle: _togglePlayback,
                  onStop: _stopPlayback,
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildStationList(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationList(TextTheme theme) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.bodyMedium!.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadStations(query: _searchController.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _stations.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final station = _stations[index];
        final isActive = _currentStation?.streamUrl == station.streamUrl;
        final subtitle = [
          if (station.country != null && station.country!.isNotEmpty) station.country,
          if (station.tags.isNotEmpty) station.tags.take(3).join(', '),
        ].whereType<String>().join(' · ');

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isActive && _music.isPlaying ? Icons.graphic_eq : Icons.radio,
            color: isActive ? Colors.amber : Colors.white54,
          ),
          title: Text(
            station.name,
            style: theme.bodyLarge!.copyWith(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: theme.bodySmall!.copyWith(color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => _playStation(station),
        );
      },
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({
    required this.station,
    required this.isPlaying,
    required this.onToggle,
    required this.onStop,
    this.error,
  });

  final RadioStation station;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onStop;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Now playing',
            style: theme.labelSmall!.copyWith(color: Colors.amber),
          ),
          const SizedBox(height: 4),
          Text(
            station.name,
            style: theme.bodyMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: theme.bodySmall!.copyWith(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filled(
                onPressed: onToggle,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onStop,
                icon: const Icon(Icons.stop, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
