import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'music_service_stub.dart' if (dart.library.io) 'music_service_io.dart' as io_impl;

/// Service for playing radio, Spotify, or local music from a folder.
/// Set [musicFolderPath] to your phone's music folder path (e.g. Android:
/// /storage/emulated/0/Music or use path_provider for app dir).
class MusicService {
  static final MusicService _instance = MusicService._();
  factory MusicService() => _instance;

  MusicService._();

  final AudioPlayer _player = AudioPlayer();

  /// Set this to your device's music folder path when available.
  /// Example Android: '/storage/emulated/0/Music'
  /// Example iOS: use path_provider getApplicationDocumentsDirectory + subdir
  static String? musicFolderPath;

  AudioPlayer get player => _player;

  /// Whether audio is currently playing
  bool get isPlaying => _player.playing;

  /// Stream of player state for UI
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Current position in track
  Stream<Duration> get positionStream => _player.positionStream;

  /// Duration of current track
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Get list of audio file paths from [musicFolderPath].
  /// Returns empty list if path is null, invalid, or not accessible.
  Future<List<String>> getLocalMusicPaths() async {
    return io_impl.getLocalMusicPathsFromFolder(musicFolderPath);
  }

  /// Play from local folder: uses first available file if [filePath] is null,
  /// otherwise plays [filePath]. Requires [musicFolderPath] to be set for listing.
  Future<void> playLocal({String? filePath}) async {
    await _player.stop();
    String? path = filePath;
    if (path == null || path.isEmpty) {
      final list = await getLocalMusicPaths();
      if (list.isEmpty) return;
      path = list.first;
    }
    if (path == null) return;
    await _player.setFilePath(path);
    await _player.play();
  }

  /// Play from a URL (e.g. radio stream).
  Future<void> playUrl(String url) async {
    await _player.stop();
    await _player.setUrl(url);
    await _player.play();
  }

  /// Pause playback
  Future<void> pause() => _player.pause();

  /// Resume playback
  Future<void> play() => _player.play();

  /// Stop and release
  Future<void> stop() => _player.stop();

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Open Spotify app or web. [uri] can be spotify:... or https://open.spotify.com/...
  Future<bool> openSpotify({String? uri}) async {
    final url = uri ?? 'https://open.spotify.com';
    final parsed = Uri.tryParse(url);
    if (parsed == null) return false;
    return launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  /// Open a radio or music URL in external app (e.g. browser or radio app).
  Future<bool> openRadioUrl(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return false;
    return launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  void dispose() {
    _player.dispose();
  }
}
