import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/music_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../services/ui_sound_service.dart';

/// Set the folder scanned for local music (Menu → Options → Music folder).
class MusicFolderSettingsScreen extends StatefulWidget {
  const MusicFolderSettingsScreen({super.key});

  @override
  State<MusicFolderSettingsScreen> createState() =>
      _MusicFolderSettingsScreenState();
}

class _MusicFolderSettingsScreenState extends State<MusicFolderSettingsScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: MusicService.musicFolderPath ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPickDirectory =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _pickFolder() async {
    if (!_canPickDirectory) return;
    final uiSound = UiSoundService();
    uiSound.playMenuTap();
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        setState(() => _controller.text = path);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open folder picker: ${e.message}'),
          backgroundColor: SwissTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _save() async {
    final uiSound = UiSoundService();
    uiSound.playMenuTap();
    setState(() => _saving = true);
    try {
      final text = _controller.text.trim();
      await MusicService.setMusicFolderPath(text.isEmpty ? null : text);
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Music folder cleared.'),
            backgroundColor: SwissTheme.textPrimary,
          ),
        );
      } else {
        final accessOk = await MusicService.requestMusicAccessIfNeeded();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accessOk
                  ? 'Saved. Will play .mp3, .m4a, .aac, .ogg, .wav, .flac from this folder and subfolders.'
                  : 'Folder saved. Allow music/audio permission in Settings, then try playing again.',
            ),
            backgroundColor: SwissTheme.textPrimary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    UiSoundService().playMenuTap();
    setState(() {
      _controller.clear();
    });
    await MusicService.setMusicFolderPath(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Music folder cleared.'),
        backgroundColor: SwissTheme.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    final bodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
    );
    final hintStyle = AppFonts.pixelifySans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textSecondary,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: SwissTheme.backgroundWhite,
        elevation: 0,
        foregroundColor: SwissTheme.textPrimary,
        title: Text(
          'MUSIC FOLDER',
          style: AppFonts.pixelifySans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SwissTheme.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Text(
              'Practical test — phone music',
              style: titleStyle,
            ),
            const SizedBox(height: 12),
            Text(
              'Tracks in this folder and its subfolders are used when you tap '
              '"Phone music folder" during a test. On Android, allow music/audio access '
              'when the app asks. Typical path:',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            SelectableText(
              '/storage/emulated/0/Music',
              style: hintStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              style: bodyStyle,
              decoration: InputDecoration(
                labelText: 'Folder path',
                labelStyle: hintStyle,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: SwissTheme.borderBlack),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: SwissTheme.borderBlack),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: SwissTheme.accentRed, width: 2),
                ),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            if (_canPickDirectory)
              OutlinedButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open, color: SwissTheme.textPrimary),
                label: Text(
                  'CHOOSE FOLDER',
                  style: AppFonts.pixelifySans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: SwissTheme.borderBlack),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                'Folder picking is not available in the web build.',
                style: hintStyle,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: SwissTheme.accentRed,
                      foregroundColor: SwissTheme.backgroundWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SwissTheme.backgroundWhite,
                            ),
                          )
                        : Text(
                            'SAVE',
                            style: AppFonts.pixelifySans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: SwissTheme.backgroundWhite,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _saving ? null : _clear,
                  child: Text(
                    'CLEAR',
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SwissTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
