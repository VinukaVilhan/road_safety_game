import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'data/local/local_db.dart';
import 'data/sync/sync_service.dart';
import 'screens/auth_wrapper.dart';
import 'theme/swiss_theme.dart';
import 'services/image_preloader.dart';
import 'services/music_service.dart';

/// Industry-standard app initialization using MaterialApp.builder pattern
/// This ensures UI shows immediately while resources load in background
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalDb.instance.initialize();
  await SyncService.instance.initialize();
  await MusicService.loadSavedMusicFolderPath();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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