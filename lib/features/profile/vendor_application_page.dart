import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../authentication/session_controller.dart';

class VendorApplicationPage extends StatefulWidget {
  const VendorApplicationPage({super.key});

  @override
  State<VendorApplicationPage> createState() => _VendorApplicationPageState();
}

class _VendorApplicationPageState extends State<VendorApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _business.dispose();
    _phone.dispose();
    _area.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Grab these before the await so we do not use context afterwards.
    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.applyAsVendor(
        businessName: _business.text,
        phone: _phone.text,
        serviceArea: _area.text,
      );
      navigator.pop();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == '23505'
              ? 'You have already applied.'
              : e.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not send your application. Try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Become a vendor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vendors collect recyclables from people and fulfil '
                'marketplace orders. We review every application.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _business,
                textCapitalization: TextCapitalization.words,
                decoration: appInput('Business name'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: appInput('Business phone'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration:
                    appInput('Service area', hint: 'e.g. Ikeja, Surulere'),
                validator: _required,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Send application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
