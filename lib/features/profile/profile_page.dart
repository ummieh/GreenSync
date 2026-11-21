import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';
import '../authentication/session_controller.dart';
import 'vendor_application_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  String _roleLabel(UserRole role) => switch (role) {
        UserRole.user => 'Member',
        UserRole.vendor => 'Vendor',
        UserRole.admin => 'Admin',
      };

  void _editDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _EditDetailsDialog(session: SessionScope.read(context)),
    );
  }

  Widget _vendorSection(BuildContext context, SessionController session) {
    final role = session.profile!.role;
    final application = session.application;

    if (role == UserRole.vendor) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Vendor view'),
        subtitle: const Text('Manage pickups, orders and listings'),
        value: session.viewAsVendor,
        onChanged: session.setViewAsVendor,
      );
    }

    if (application == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.storefront_outlined),
        title: const Text('Become a vendor'),
        subtitle: const Text('Collect recyclables and fulfil orders'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const VendorApplicationPage(),
          ),
        ),
      );
    }

    final (title, subtitle) = switch (application.status) {
      ApprovalStatus.pending => (
          'Vendor application under review',
          'Your account updates automatically once it is approved.'
        ),
      ApprovalStatus.rejected => (
          'Vendor application not approved',
          'Contact support to discuss next steps.'
        ),
      ApprovalStatus.approved => (
          'Vendor application approved',
          'Pull down on Home to refresh your account.'
        ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.storefront_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final email = supabase.auth.currentUser?.email ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.forest,
              child: Text(
                profile.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName, style: theme.textTheme.titleLarge),
                  Text(email,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  const SizedBox(height: 4),
                  Text(_roleLabel(profile.role),
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 40),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Name'),
          subtitle: Text(profile.hasName ? profile.fullName!.trim() : 'Not set'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editDetails(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Phone'),
          subtitle: Text((profile.phone ?? '').isEmpty
              ? 'Not set'
              : profile.phone!),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editDetails(context),
        ),
        const Divider(height: 40),
        _vendorSection(context, session),
        const Divider(height: 40),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: session.signOut,
        ),
      ],
    );
  }
}

class _EditDetailsDialog extends StatefulWidget {
  const _EditDetailsDialog({required this.session});

  final SessionController session;

  @override
  State<_EditDetailsDialog> createState() => _EditDetailsDialogState();
}

class _EditDetailsDialogState extends State<_EditDetailsDialog> {
  late final _name =
      TextEditingController(text: widget.session.profile?.fullName ?? '');
  late final _phone =
      TextEditingController(text: widget.session.profile?.phone ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session
          .updateDetails(fullName: _name.text, phone: _phone.text);
      if (mounted) Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save. Try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: appInput('Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: appInput('Phone number'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
