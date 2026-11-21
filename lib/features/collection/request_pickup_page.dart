import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../authentication/session_controller.dart';

class _ItemRow {
  int? categoryId;
  final TextEditingController weight = TextEditingController();
}

class RequestPickupPage extends StatefulWidget {
  const RequestPickupPage({super.key});

  @override
  State<RequestPickupPage> createState() => _RequestPickupPageState();
}

class _RequestPickupPageState extends State<RequestPickupPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final List<_ItemRow> _items = [_ItemRow()];
  late Future<List<Json>> _categories;
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;
  bool _prefilled = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  Future<List<Json>> _loadCategories() async {
    final rows = await supabase.from('categories').select().order('name');
    return rows;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled) {
      _prefilled = true;
      _phone.text = SessionScope.of(context).profile?.phone ?? '';
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.weight.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    final okForm = _formKey.currentState!.validate();
    String? dateError;
    if (_date == null || _time == null) {
      dateError = 'Choose a date and time';
    } else {
      final at = DateTime(
          _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
      if (at.isBefore(DateTime.now())) dateError = 'Choose a time in the future';
    }
    setState(() => _dateError = dateError);
    if (!okForm || dateError != null) return;

    setState(() => _saving = true);
    String? requestId;
    try {
      final uid = supabase.auth.currentUser!.id;
      final at = DateTime(
          _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
      final row = await supabase
          .from('collection_requests')
          .insert({
            'user_id': uid,
            'scheduled_date': at.toUtc().toIso8601String(),
            'address': _address.text.trim(),
            'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          })
          .select('id')
          .single();
      requestId = row['id'] as String;
      await supabase.from('collection_request_items').insert([
        for (final i in _items)
          {
            'request_id': requestId,
            'category_id': i.categoryId,
            'estimated_weight_kg': double.parse(i.weight.text.trim()),
            'quantity': 1,
          }
      ]);
      if (!mounted) return;
      showMessage(context, 'Pickup requested. A vendor will accept it soon.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (requestId != null) {
        try {
          await supabase
              .from('collection_requests')
              .update({'status': 'cancelled'}).eq('id', requestId);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Request a pickup')),
      body: AsyncBody<List<Json>>(
        future: _categories,
        onRetry: () => setState(() => _categories = _loadCategories()),
        builder: (context, cats) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('What are we collecting?',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (var n = 0; n < _items.length; n++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: _items[n].categoryId,
                          isExpanded: true,
                          decoration: appInput('Material'),
                          items: [
                            for (final c in cats)
                              DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['name'] as String),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _items[n].categoryId = v),
                          validator: (v) => v == null ? 'Choose one' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _items[n].weight,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: appInput('Weight (kg)'),
                          validator: (v) {
                            final w = double.tryParse((v ?? '').trim());
                            return (w == null || w <= 0) ? 'Enter kg' : null;
                          },
                        ),
                      ),
                      if (_items.length > 1)
                        IconButton(
                          onPressed: () => setState(() => _items.removeAt(n)),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemRow())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another material'),
                ),
              ),
              const SizedBox(height: 16),
              Text('When?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                          _date == null ? 'Pick a date' : formatDate(_date!)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                          _time == null ? 'Pick a time' : _time!.format(context)),
                    ),
                  ),
                ],
              ),
              if (_dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dateError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _address,
                decoration: appInput('Pickup address'),
                maxLines: 2,
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Enter your full address'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: appInput('Phone number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: appInput('Notes for the vendor (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'You earn 10 reward points for every kg collected.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
