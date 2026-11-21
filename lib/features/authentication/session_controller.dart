import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../models/vendor_application.dart';

/// Holds everything the app needs to know about "who is signed in":
/// their profile, role, vendor application and points balance.
/// Screens read it with SessionScope.of(context) and rebuild when it changes.
class SessionController extends ChangeNotifier {
  SessionController() {
    _signedIn = supabase.auth.currentSession != null;
    _authSub = supabase.auth.onAuthStateChange.listen(_onAuthChange);
    if (_signedIn) loadProfile();
  }

  late final StreamSubscription<AuthState> _authSub;

  bool _signedIn = false;
  bool _loading = false;
  String? _error;
  Profile? _profile;
  VendorApplication? _application;
  int _points = 0;
  bool _viewAsVendor = false;

  bool get isSignedIn => _signedIn;
  bool get isLoading => _loading;
  String? get error => _error;
  Profile? get profile => _profile;
  VendorApplication? get application => _application;
  int get points => _points;
  bool get viewAsVendor => _viewAsVendor;

  void _onAuthChange(AuthState state) {
    final session = state.session;
    if (session == null) {
      _signedIn = false;
      _loading = false;
      _error = null;
      _profile = null;
      _application = null;
      _points = 0;
      _viewAsVendor = false;
      notifyListeners();
    } else if (!_signedIn || _profile?.id != session.user.id) {
      _signedIn = true;
      loadProfile();
    }
  }

  /// Loads (or reloads) the profile, vendor application and points balance.
  Future<void> loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || _loading) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final profileRow =
          await supabase.from('profiles').select().eq('id', uid).single();
      final applicationRow = await supabase
          .from('vendor_profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      final pointsRow = await supabase
          .from('user_points')
          .select('balance')
          .eq('user_id', uid)
          .maybeSingle();

      final previousRole = _profile?.role;
      _profile = Profile.fromMap(profileRow);
      _application = applicationRow == null
          ? null
          : VendorApplication.fromMap(applicationRow);
      _points = (pointsRow?['balance'] as num?)?.toInt() ?? 0;

      // Start in vendor view for vendors; reset if the role has changed.
      if (previousRole != _profile!.role) {
        _viewAsVendor = _profile!.role == UserRole.vendor && !demoMode;
      }
    } catch (e) {
      debugPrint('loadProfile failed: $e');
      _error = 'We could not load your account. Check your connection '
          'and try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setViewAsVendor(bool value) {
    if (_profile?.role != UserRole.vendor) return;
    _viewAsVendor = value;
    notifyListeners();
  }

  /// Saves name and phone. Throws PostgrestException if the database refuses.
  Future<void> updateDetails({
    required String fullName,
    required String phone,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
    }).eq('id', uid);
    await loadProfile();
  }

  /// Sends a vendor application. An admin approves it in Supabase.
  Future<void> applyAsVendor({
    required String businessName,
    required String phone,
    required String serviceArea,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('vendor_profiles').insert({
      'user_id': uid,
      'business_name': businessName.trim(),
      'phone': phone.trim(),
      'service_area': serviceArea.trim(),
    });
    await loadProfile();
  }

  Future<void> signOut() => supabase.auth.signOut();

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

/// Makes the SessionController available to every screen below it.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Use inside build(): the screen rebuilds when the session changes.
  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found above this widget.');
    return scope!.notifier!;
  }

  /// Use inside button handlers: reads the session without subscribing.
  static SessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found above this widget.');
    return scope!.notifier!;
  }
}
