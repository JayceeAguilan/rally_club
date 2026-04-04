import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _feedbackMessage;
  bool _isError = false;

  static const _bgDark = Color(0xFF0F1A00);
  static const _lime = Color(0xFFCAFD00);
  static const _limeDark = Color(0xFF3D4E00);
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _inputFill = Color(0xFFF3F4F6);
  static const _inputBorder = Color(0xFFD1D5DB);
  static const _errorRed = Color(0xFFEF4444);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _isError = false;
    });

    try {
      final auth = context.read<AuthProvider>();
      final input = _codeController.text.trim();
      if (input.isNotEmpty) {
        await auth.applyEmailVerificationCode(input);
      } else {
        await auth.refreshCurrentUser();
      }

      if (!mounted) {
        return;
      }

      if (!auth.isEmailVerified) {
        setState(() {
          _feedbackMessage =
              'Your email is not verified yet. Open the email link or paste the verification code above.';
          _isError = true;
          _isSubmitting = false;
        });
        return;
      }

      setState(() {
        _feedbackMessage = 'Email verified successfully. Redirecting...';
        _isError = false;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage = _friendlyError(e.toString());
        _isError = true;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    if (_isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _feedbackMessage = null;
      _isError = false;
    });

    try {
      await context.read<AuthProvider>().sendEmailVerification();
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage =
            'Verification email sent. Check your inbox and spam folder.';
        _isError = false;
        _isResending = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feedbackMessage = _friendlyError(e.toString());
        _isError = true;
        _isResending = false;
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('invalid-action-code')) {
      return 'That verification code is invalid or has already been used.';
    }
    if (raw.contains('expired-action-code')) {
      return 'That verification code has expired. Request a new verification email.';
    }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Contact support.';
    }
    if (raw.contains('network-request-failed')) {
      return 'Network error. Check your connection and try again.';
    }
    if (raw.contains('Please enter the verification code')) {
      return 'Paste the verification code or full email link, then try again.';
    }
    return 'Verification failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthProvider, String?>(
      (auth) => auth.firebaseUser?.email ?? auth.appUser?.email,
    );

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: _limeDark,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify Your Email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email == null
                          ? 'Check your email inbox for a verification message before using the app.'
                          : 'We sent a verification email to $email. Open the link in that email, then return here and continue. If the link opens outside the app, you can also paste the full link below.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Verification link or action code',
                        labelStyle: const TextStyle(color: _textSecondary),
                        hintText: 'Optional: paste the full email link or code',
                        hintStyle: const TextStyle(color: _textSecondary),
                        prefixIcon: const Icon(
                          Icons.password_outlined,
                          color: _textSecondary,
                        ),
                        filled: true,
                        fillColor: _inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _lime, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_feedbackMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (_isError ? _errorRed : _limeDark).withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isError ? _errorRed : _limeDark)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _isError ? _errorRed : _limeDark,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: TextStyle(
                                  color: _isError ? _errorRed : _limeDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _verifyEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lime,
                          foregroundColor: _limeDark,
                          disabledBackgroundColor: _lime.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _limeDark,
                                ),
                              )
                            : const Text(
                                'I VERIFIED MY EMAIL',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isResending ? null : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _limeDark,
                        side: const BorderSide(color: _lime),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _limeDark,
                              ),
                            )
                          : const Text(
                              'RESEND EMAIL',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                    TextButton(
                      onPressed: () => context.read<AuthProvider>().signOut(),
                      child: const Text(
                        'Back to Sign In',
                        style: TextStyle(
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
