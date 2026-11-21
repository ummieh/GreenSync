import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'login_page.dart';
import 'session_controller.dart';

/// Decides what to show: login, a loading screen, or the app itself.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (!session.isSignedIn) return const LoginPage();

    if (session.profile == null) {
      if (session.error != null) {
        return _LoadError(
          message: session.error!,
          onRetry: session.loadProfile,
          onSignOut: session.signOut,
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const AppShell();
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
