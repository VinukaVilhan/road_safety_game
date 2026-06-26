import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../services/progress/odometer_service.dart';
import '../../theme/swiss_theme.dart';
import '../../theme/landscape_layout.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/assistant_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(OdometerService.instance.refreshDisplayMiles());
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      height: 0.9,
      letterSpacing: -1.0,
      color: SwissTheme.textPrimary,
    );
    final labelStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textSecondary,
    );
    final valueStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    final buttonStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.accentRed,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: SwissTheme.backgroundWhite,
        foregroundColor: SwissTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: AssistantButton(
              inAppBar: true,
              heroTag: 'assistant_profile',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Profile',
                includeFullRoadSignCatalog: true,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: LandscapeLayout.screenPadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROFILE', style: titleStyle),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 5,
                      color: SwissTheme.accentRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              if (user != null) ...[
                Text('EMAIL', style: labelStyle),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '—',
                  style: valueStyle,
                ),
                const SizedBox(height: 24),
                Text('DISPLAY NAME', style: labelStyle),
                const SizedBox(height: 4),
                Text(
                  user.displayName?.isNotEmpty == true ? user.displayName! : '—',
                  style: valueStyle,
                ),
                const SizedBox(height: 24),
                Text('DISTANCE DRIVEN (APPROX.)', style: labelStyle),
                const SizedBox(height: 4),
                ValueListenableBuilder<double>(
                  valueListenable: OdometerService.instance.totalMiles,
                  builder: (context, miles, _) {
                    final line = miles < 0.01
                        ? 'Under 0.01 mi — syncs when signed in'
                        : '${miles.toStringAsFixed(2)} mi — synced with your account';
                    return Text(line, style: valueStyle);
                  },
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      try {
                        const webClientId =
                            '860711284288-sel11579st8pfgh3jqs7e68blp6fm3tf.apps.googleusercontent.com';
                        final googleSignIn = GoogleSignIn(serverClientId: webClientId);
                        await googleSignIn.signOut();
                        await googleSignIn.disconnect();
                      } catch (_) {}
                      try {
                        await FacebookAuth.instance.logOut();
                      } catch (_) {}
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                      child: Row(
                        children: [
                          Text(
                            'SIGN OUT',
                            style: buttonStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text('Not signed in', style: valueStyle),
                const SizedBox(height: 24),
                Text('DISTANCE DRIVEN (APPROX., THIS DEVICE)', style: labelStyle),
                const SizedBox(height: 4),
                ValueListenableBuilder<double>(
                  valueListenable: OdometerService.instance.totalMiles,
                  builder: (context, miles, _) {
                    final line = miles < 0.01
                        ? 'Under 0.01 mi — sign in to sync across devices'
                        : '${miles.toStringAsFixed(2)} mi on this device';
                    return Text(line, style: valueStyle);
                  },
                ),
              ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
