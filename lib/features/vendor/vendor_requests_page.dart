import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';

const _select =
    '*, collection_request_items(estimated_weight_kg, quantity, categories(name))';

/// Vendor view: pickups waiting for a vendor, and the ones I accepted.
class VendorRequestsPage extends StatefulWidget {
  const VendorRequestsPage({super.key});

  @override
  State<VendorRequestsPage> createState() => _VendorRequestsPageState();
}

class _VendorRequestsPageState extends State<VendorRequestsPage> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final uid = supabase.auth.currentUser!.id;
    final available = await supabase
        .from('collection_requests')
        .select(_select)
        .eq('status', 'pending')
        .neq('user_id', uid)
        .order('scheduled_date');
    final mine = await supabase
        .from('collection_requests')
        .select(_select)
        .eq('vendor_id', uid)
        .order('scheduled_date', ascending: false);
    final ids = <String>[
      for (final r in available) r['user_id'] as String,
      for (final r in mine) r['user_id'] as String,
    ];
    final names = await fetchNames(ids);
    return _Data(available, mine, names);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _accept(String id) async {
    try {
      await supabase.rpc('accept_collection_request', params: {
        'p_request_id': id,
      });
      if (mounted) showMessage(context, 'Pickup accepted. It is in My pickups.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
      _reload();
    }
  }

  Future<void> _complete(String id) async {
    final result = await showDialog<List<double>>(
      context: context,
      builder: (_) => const _CompleteDialog(),
    );
    if (result == null) return;
    try {
      await supabase.rpc('complete_collection_request', params: {
        'p_request_id': id,
        'p_weight_kg': result[0],
        'p_price_per_kg': result[1],
      });
      if (mounted) {
        showMessage(context,
            'Pickup completed. ${(result[0] * 10).floor()} points awarded to the customer.');
      }
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  String _items(Json r) {
    final items = (r['collection_request_items'] as List?) ?? [];
    if (items.isEmpty) return 'No items listed';
    return items.map((i) {
      final name = (i['categories'] as Map?)?['name'] ?? 'Item';
      final w = (i['estimated_weight_kg'] as num?) ?? 0;
      return '$name ${kgText(w)}';
    }).join(' · ');
  }

  Widget _card(Json r, Map<String, String> names, {required bool mine}) {
    final status = r['status'] as String;
    final when = DateTime.parse(r['scheduled_date'] as String).toLocal();
    final weight = r['actual_weight_kg'] as num?;
    final price = r['price_per_kg'] as num?;
    final phone = r['phone'] as String?;
    final notes = r['notes'] as String?;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatDate(when)}, ${formatTime(when)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(names[r['user_id']] ?? 'Customer',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(r['address'] as String),
          if (phone != null && phone.isNotEmpty)
            Text(phone, style: TextStyle(color: muted)),
          const SizedBox(height: 4),
          Text(_items(r), style: TextStyle(color: muted)),
          if (notes != null && notes.isNotEmpty)
            Text('Note: $notes', style: TextStyle(color: muted)),
          if (status == 'completed' && weight != null && price != null) ...[
            const SizedBox(height: 8),
            Text(
              'Collected ${kgText(weight)} at ${money(price)}/kg = ${money(weight * price)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (!mine && status == 'pending') ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _accept(r['id'] as String),
              child: const Text('Accept pickup'),
            ),
          ],
          if (mine && status == 'accepted') ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _complete(r['id'] as String),
              child: const Text('Mark as collected'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(List<Json> rows, Map<String, String> names,
      {required bool mine}) {
    if (rows.isEmpty) {
      return EmptyState(
        icon: mine ? Icons.inventory_2_outlined : Icons.inbox_outlined,
        title: mine ? 'Nothing accepted yet' : 'No open requests',
        message: mine
            ? 'Accepted pickups show up here.'
            : 'New requests from customers appear here. Pull down to refresh.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: rows.length,
        itemBuilder: (context, i) => _card(rows[i], names, mine: mine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.forest,
            indicatorColor: AppColors.forest,
            tabs: [Tab(text: 'Available'), Tab(text: 'My pickups')],
          ),
          Expanded(
            child: AsyncBody<_Data>(
              future: _future,
              onRetry: _reload,
              builder: (context, data) => TabBarView(
                children: [
                  _list(data.available, data.names, mine: false),
                  _list(data.mine, data.names, mine: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Data {
  _Data(this.available, this.mine, this.names);
  final List<Json> available;
  final List<Json> mine;
  final Map<String, String> names;
}

class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog();

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  final _weight = TextEditingController();
  final _price = TextEditingController(text: '100');
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _price.dispose();
    super.dispose();
  }

  void _ok() {
    final w = double.tryParse(_weight.text.trim());
    final p = double.tryParse(_price.text.trim());
    if (w == null || w <= 0 || p == null || p < 0) {
      setState(() => _error = 'Enter a weight above 0 and a price.');
      return;
    }
    Navigator.of(context).pop(<double>[w, p]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete pickup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: appInput('Actual weight (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: appInput('Price you pay per kg (₦)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Complete')),
      ],
    );
  }
}
