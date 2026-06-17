import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'auth_screen.dart';
import '../home/menu_screen.dart';

/// Decides whether to show [AuthScreen] or [MenuScreen] based on auth state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: SwissTheme.backgroundWhite,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: SwissTheme.accentRed,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'LOADING',
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SwissTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          return const AuthScreen();
        }
        return MenuScreen();
      },
    );
  }
}
