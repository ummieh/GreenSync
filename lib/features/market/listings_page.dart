import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import 'create_listing_page.dart';

/// Products I am selling.
class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final rows = await supabase
        .from('products')
        .select('*, categories(name)')
        .eq('seller_id', supabase.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _add() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingPage()),
    );
    if (ok == true) _reload();
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await supabase.from('products').update({'status': status}).eq('id', id);
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await supabase.from('products').delete().eq('id', id);
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: AsyncBody<List<Json>>(
        future: _future,
        onRetry: _reload,
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.sell_outlined,
              title: 'No listings yet',
              message: 'List recyclable materials for others to buy.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              childAspectRatio: 0.78,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final p = rows[i];
              final status = p['status'] as String;
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ProductThumb(p,
                              size: double.infinity,
                              height: double.infinity,
                              radius: 0),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white70,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (v) {
                                  final id = p['id'] as String;
                                  if (v == 'delete') {
                                    _delete(id);
                                  } else {
                                    _setStatus(id, v);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (status != 'active')
                                    const PopupMenuItem(
                                        value: 'active',
                                        child: Text('Make active')),
                                  if (status == 'active')
                                    const PopupMenuItem(
                                        value: 'removed',
                                        child: Text('Hide listing')),
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(
                              '${money(p['price'] as num)}/${p['unit']} · ${p['quantity_available']} left',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          StatusChip(status),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: body,
    );
  }
}
