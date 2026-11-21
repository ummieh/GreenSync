import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo/demo_backend.dart';

/// Connection settings, supplied when you run or build the app:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Never put the service_role / secret key in the app. Only the anon (publishable) key.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}

/// With no keys supplied the app runs on built-in sample data (demo mode),
/// signed in as a demo user. Nothing is sent anywhere.
bool get demoMode => !SupabaseConfig.isConfigured;

final DemoClient _demo = DemoClient();

/// Shortcut used across the app: supabase.from('products')...
/// Typed dynamic so the real client and the demo client are interchangeable.
dynamic get supabase => demoMode ? _demo : Supabase.instance.client;
