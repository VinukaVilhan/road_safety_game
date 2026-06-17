import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'sign_up_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const double _oauthLogoSize = 22;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  /// Prevents overlapping Google Sign-In calls (Android plugin throws if signIn is re-entrant).
  bool _googleSignInInFlight = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Auth state stream will switch to MenuScreen
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final friendlyMessage = _friendlyEmailSignInError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = friendlyMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  /// User-friendly message for email/password sign-in errors.
  String _friendlyEmailSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Wrong email or password, or this email was used with Google or Facebook sign-in. Try "Sign in with Google" or "Create account" if you haven’t yet.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_googleSignInInFlight) return;
    _googleSignInInFlight = true;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      // Web client ID from Firebase (google-services.json oauth_client type 3)
      // Required so Google returns an idToken that Firebase Auth can use.
      const webClientId =
          '860711284288-sel11579st8pfgh3jqs7e68blp6fm3tf.apps.googleusercontent.com';
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Google sign in failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Google sign in failed. ${e.toString()}';
      });
    } finally {
      _googleSignInInFlight = false;
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success || result.accessToken == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Facebook sign in failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Facebook sign in failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      color: SwissTheme.textPrimary,
    );
    final bodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
    );
    final buttonStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.accentRed,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 64),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIGN IN', style: titleStyle),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 5,
                  color: SwissTheme.accentRed,
                ),
                const SizedBox(height: 48),
                Text('EMAIL', style: labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: bodyStyle,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text('PASSWORD', style: labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SwissTheme.borderBlack, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: bodyStyle,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: SwissTheme.accentRed,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              _signIn();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: SwissTheme.accentRed,
                      foregroundColor: SwissTheme.backgroundWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: SwissTheme.borderBlack),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SwissTheme.backgroundWhite,
                            ),
                          )
                        : Text(
                            'SIGN IN',
                            style: AppFonts.pixelifySans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SwissTheme.backgroundWhite,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: SwissTheme.borderBlack,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: AppFonts.pixelifySans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SwissTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: SwissTheme.borderBlack,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: SwissTheme.borderBlack),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/google_logo.svg',
                          width: _oauthLogoSize,
                          height: _oauthLogoSize,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign in with Google',
                          style: AppFonts.pixelifySans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SwissTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signInWithFacebook,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: SwissTheme.borderBlack),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/facebook_logo.svg',
                          width: _oauthLogoSize,
                          height: _oauthLogoSize,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign in with Facebook',
                          style: AppFonts.pixelifySans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SwissTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                    child: Text('Create account', style: buttonStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
