import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'config/assistant_config.dart';
import 'config/cloudinary_config.dart';
import 'firebase_options.dart';
import 'data/local/local_db.dart';
import 'data/sync/sync_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'theme/swiss_theme.dart';
import 'services/content/image_preloader.dart';
import 'services/audio/music_service.dart';
import 'services/audio/ui_sound_service.dart';
import 'utils/app_orientation.dart';

/// Industry-standard app initialization using MaterialApp.builder pattern
/// This ensures UI shows immediately while resources load in background
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppOrientation.lockLandscape();
  final uiSoundsPreload = UiSoundService().preload();
  await AssistantConfig.ensureLoaded();
  await CloudinaryConfig.ensureLoaded();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalDb.instance.initialize();
  await SyncService.instance.initialize();
  await MusicService.loadSavedMusicFolderPath();
  await uiSoundsPreload;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UiSoundService().playAppOpenEngineStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Rules',
      theme: SwissTheme.themeData,
      debugShowCheckedModeBanner: false,
      // Industry-standard: Use builder to handle initialization without blocking UI
      builder: (context, child) {
        // Preload images after first frame (non-blocking)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ImagePreloader.preloadImages(context);
          }
        });
        return child ?? const SizedBox.shrink();
      },
      home: AuthWrapper(),
    );
  }
}