import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController();
  final _location = TextEditingController();
  late Future<List<Json>> _cats;
  int? _categoryId;
  String _unit = 'kg';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cats = _loadCats();
  }

  Future<List<Json>> _loadCats() async {
    final rows = await supabase.from('categories').select().order('name');
    return rows;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _qty.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await supabase.from('products').insert({
        'seller_id': supabase.auth.currentUser!.id,
        'category_id': _categoryId,
        'title': _title.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'price': double.parse(_price.text.trim()),
        'unit': _unit,
        'quantity_available': double.parse(_qty.text.trim()),
        'location':
            _location.text.trim().isEmpty ? null : _location.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, 'Listing published.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell recyclables')),
      body: AsyncBody<List<Json>>(
        future: _cats,
        onRetry: () => setState(() => _cats = _loadCats()),
        builder: (context, cats) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _title,
                decoration: appInput('Title', hint: 'e.g. Clean PET bottles'),
                validator: (v) =>
                    (v ?? '').trim().length < 3 ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoryId,
                isExpanded: true,
                decoration: appInput('Material'),
                items: [
                  for (final c in cats)
                    DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(c['name'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Choose a material' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: appInput('Price (₦)'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return (n == null || n < 0) ? 'Enter a price' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: appInput('Per'),
                      items: const [
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'piece', child: Text('piece')),
                        DropdownMenuItem(value: 'bag', child: Text('bag')),
                        DropdownMenuItem(value: 'ton', child: Text('ton')),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? 'kg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: appInput('Quantity available'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n <= 0) ? 'Enter a quantity' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: appInput('Location', hint: 'e.g. Kano'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: appInput('Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Publish listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
