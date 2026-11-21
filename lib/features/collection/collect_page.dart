import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../authentication/session_controller.dart';
import 'request_pickup_page.dart';

/// Customer view: my pickup requests, plus a button to make a new one.
class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('collection_requests')
        .select(
            '*, collection_request_items(estimated_weight_kg, quantity, categories(name))')
        .eq('user_id', uid)
        .order('scheduled_date', ascending: false);
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _newRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RequestPickupPage()),
    );
    if (created == true) _reload();
  }

  Future<void> _cancel(String id) async {
    try {
      await supabase
          .from('collection_requests')
          .update({'status': 'cancelled'}).eq('id', id);
      if (mounted) showMessage(context, 'Pickup cancelled.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add),
        label: const Text('Request pickup'),
      ),
      body: AsyncBody<List<Json>>(
        future: _future,
        onRetry: _reload,
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No pickups yet',
              message:
                  'Request a pickup and a nearby vendor will collect your recyclables.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final status = r['status'] as String;
                final when =
                    DateTime.parse(r['scheduled_date'] as String).toLocal();
                final weight = r['actual_weight_kg'] as num?;
                final price = r['price_per_kg'] as num?;
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
                      Text(r['address'] as String),
                      const SizedBox(height: 4),
                      Text(_items(r),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      if (status == 'completed' &&
                          weight != null &&
                          price != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Collected ${kgText(weight)} · paid ${money(weight * price)} · +${(weight * 10).floor()} points',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (status == 'pending') ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancel(r['id'] as String),
                            child: const Text('Cancel request'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
