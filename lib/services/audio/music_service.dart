import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'music_access_stub.dart'
    if (dart.library.io) 'music_access_io.dart' as access_impl;
import 'music_service_stub.dart' if (dart.library.io) 'music_service_io.dart' as io_impl;
import 'driving_audio_levels.dart';

/// Service for playing radio, Spotify, or local music from a folder.
/// Use [loadSavedMusicFolderPath] at startup and [setMusicFolderPath] from
/// settings (Menu → Options → Music folder).
class MusicService {
  static final MusicService _instance = MusicService._();
  factory MusicService() => _instance;

  MusicService._();

  static const String _prefsKeyMusicFolder = 'music_folder_path';

  final AudioPlayer _player = AudioPlayer();

  /// Caps stream/local playback so vehicle idle / reverse / accelerate SFX stay louder.
  Future<void> _applyDrivingMixVolume() async {
    if (!isDrivingLessonActive) return;
    await _player.setVolume(DrivingAudioLevels.radioMaxDuringLesson);
  }

  /// True while an active driving lesson is in progress (not briefing / result).
  final ValueNotifier<bool> drivingLessonActive = ValueNotifier<bool>(false);

  /// Current music folder (absolute path). Persisted via SharedPreferences.
  static String? musicFolderPath;

  bool get isDrivingLessonActive => drivingLessonActive.value;

  /// Call when the player is actively driving (after briefing, or immediately if none).
  void beginDrivingLesson() {
    drivingLessonActive.value = true;
  }

  /// Call when the lesson ends or the player leaves [GameScreen]. Stops radio playback.
  Future<void> endDrivingLesson() async {
    if (!drivingLessonActive.value) {
      await stop();
      return;
    }
    drivingLessonActive.value = false;
    await stop();
  }

  /// Android: request read access so playback works later (no-op on other platforms).
  static Future<bool> requestMusicAccessIfNeeded() async {
    return access_impl.ensureMusicFolderReadAccess();
  }

  /// Load [musicFolderPath] from device storage (call from [main] after binding).
  static Future<void> loadSavedMusicFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKeyMusicFolder)?.trim();
    musicFolderPath = (v != null && v.isNotEmpty) ? v : null;
  }

  /// Save folder path and update [musicFolderPath]. Pass null or empty to clear.
  static Future<void> setMusicFolderPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      musicFolderPath = null;
      await prefs.remove(_prefsKeyMusicFolder);
      return;
    }
    musicFolderPath = trimmed;
    await prefs.setString(_prefsKeyMusicFolder, trimmed);
  }

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
  ///
  /// Returns `null` if playback started; otherwise a short error for the UI.
  Future<String?> playLocal({String? filePath}) async {
    await _player.stop();

    final allowed = await access_impl.ensureMusicFolderReadAccess();
    if (!allowed) {
      return 'Audio/storage permission denied. Allow “Music and audio” (or Files) '
          'for this app in Android Settings, then try again.';
    }

    late final String path;
    if (filePath != null && filePath.isNotEmpty) {
      path = filePath;
    } else {
      final list = await getLocalMusicPaths();
      if (list.isEmpty) {
        final folder = musicFolderPath?.trim();
        if (folder == null || folder.isEmpty) {
          return 'No music folder set. Use Menu → Options → Music folder.';
        }
        return 'No playable files in that folder (need .mp3, .m4a, .aac, .ogg, '
            '.wav, or .flac in this folder or subfolders), or the path cannot be read.';
      }
      path = list.first;
    }

    try {
      await _player.setFilePath(path);
      await _applyDrivingMixVolume();
      await _player.play();
      return null;
    } catch (e) {
      return 'Could not play audio: $e';
    }
  }

  /// Play from a URL (e.g. internet radio stream). Returns `null` on success.
  /// Only allowed during an active driving lesson.
  Future<String?> playUrl(String url) async {
    if (!isDrivingLessonActive) {
      return 'Radio is only available while a driving lesson is in progress.';
    }
    await _player.stop();
    try {
      await _player.setUrl(url);
      await _applyDrivingMixVolume();
      await _player.play();
      return null;
    } catch (e) {
      final message = e.toString();
      if (message.contains('Cleartext HTTP') ||
          message.contains('cleartext') ||
          message.contains('cleartext-not-permitted')) {
        return 'This station uses an insecure HTTP stream that could not be played. Try another station.';
      }
      return 'Could not play stream: $e';
    }
  }

  /// Pause playback
  Future<void> pause() => _player.pause();

  /// Resume playback
  Future<void> play() async {
    await _applyDrivingMixVolume();
    await _player.play();
  }

  /// Stop and release
  Future<void> stop() => _player.stop();

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (!isDrivingLessonActive) {
      await stop();
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _applyDrivingMixVolume();
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
