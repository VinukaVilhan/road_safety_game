import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      final createFuture = FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final credential = await createFuture.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Create account timed out'),
      );
      if (!mounted) return;
      // Pop immediately so user sees the menu; update display name in background
      Navigator.of(context).pop();
      final name = _displayNameController.text.trim();
      if (name.isNotEmpty && credential.user != null) {
        credential.user!.updateDisplayName(name); // fire-and-forget
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'This is taking too long. Check your connection and try again.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final friendlyMessage = _friendlySignUpError(e);
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

  String _friendlySignUpError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use. Sign in above or use a different email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
        return 'Email sign-up is not enabled. Please contact support.';
      default:
        return e.message ?? 'Sign up failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.inter(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      height: 0.9,
      letterSpacing: -1.0,
      color: SwissTheme.textPrimary,
    );
    final labelStyle = AppFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    final bodyStyle = AppFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
    );
    final buttonStyle = AppFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.backgroundWhite,
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CREATE ACCOUNT', style: titleStyle),
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
                      return 'Enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text('DISPLAY NAME (optional)', style: labelStyle),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
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
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: AppFonts.inter(
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
                              _createAccount();
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
                        : Text('CREATE ACCOUNT', style: buttonStyle),
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
