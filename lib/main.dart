import 'package:flutter/material.dart';

import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/auth_gate.dart';
import 'features/authentication/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No keys given: run in demo mode with sample data.
  if (SupabaseConfig.isConfigured) await initSupabase();
  runApp(const GreenSyncApp());
}

class GreenSyncApp extends StatefulWidget {
  const GreenSyncApp({super.key});

  @override
  State<GreenSyncApp> createState() => _GreenSyncAppState();
}

class _GreenSyncAppState extends State<GreenSyncApp> {
  late final SessionController _session = SessionController();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: MaterialApp(
        title: 'GreenSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
