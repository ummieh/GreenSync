import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';

/// Orders I placed (asSeller false) or orders placed on my listings (true).
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.asSeller, this.embedded = false});

  final bool asSeller;

  /// True when shown inside a bottom-navigation tab (no app bar of its own).
  final bool embedded;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<_OrderData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OrderData> _load() async {
    final uid = supabase.auth.currentUser!.id;
    final column = widget.asSeller ? 'seller_id' : 'buyer_id';
    final orders = await supabase
        .from('orders')
        .select('*, order_items(title, unit_price, quantity)')
        .eq(column, uid)
        .order('created_at', ascending: false);
    final otherIds = [
      for (final o in orders)
        (widget.asSeller ? o['buyer_id'] : o['seller_id']) as String,
    ];
    return _OrderData(orders, await fetchNames(otherIds));
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setStatus(String id, String status) async {
    try {
      await supabase.rpc('update_order_status', params: {
        'p_order_id': id,
        'p_status': status,
      });
      if (mounted) showMessage(context, 'Order ${status}.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  List<Widget> _actions(Json o) {
    final status = o['status'] as String;
    final id = o['id'] as String;
    if (widget.asSeller) {
      if (status == 'placed') {
        return [
          TextButton(
              onPressed: () => _setStatus(id, 'cancelled'),
              child: const Text('Decline')),
          FilledButton(
              onPressed: () => _setStatus(id, 'confirmed'),
              child: const Text('Confirm')),
        ];
      }
      if (status == 'confirmed') {
        return [
          TextButton(
              onPressed: () => _setStatus(id, 'cancelled'),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _setStatus(id, 'completed'),
              child: const Text('Mark completed')),
        ];
      }
    } else if (status == 'placed') {
      return [
        TextButton(
            onPressed: () => _setStatus(id, 'cancelled'),
            child: const Text('Cancel order')),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final body = AsyncBody<_OrderData>(
      future: _future,
      onRetry: _reload,
      builder: (context, data) {
        if (data.orders.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: widget.asSeller
                ? 'Orders placed on your listings appear here.'
                : 'Orders you place in the marketplace appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: data.orders.length,
            itemBuilder: (context, i) {
              final o = data.orders[i];
              final when = DateTime.parse(o['created_at'] as String).toLocal();
              final other = data.names[
                      (widget.asSeller ? o['buyer_id'] : o['seller_id'])] ??
                  'GreenSync member';
              final items = (o['order_items'] as List?) ?? [];
              final actions = _actions(o);
              return InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.asSeller ? 'From $other' : 'From $other',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        StatusChip(o['status'] as String),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(when)} · ${niceStatus(o['fulfilment'] as String)}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    for (final it in items)
                      Text(
                          '${it['title']}  ×  ${it['quantity']}   ${money((it['unit_price'] as num) * (it['quantity'] as num))}'),
                    if ((o['delivery_address'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Deliver to: ${o['delivery_address']}'),
                      ),
                    const SizedBox(height: 8),
                    Text('Total ${money(o['total_amount'] as num)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(widget.asSeller ? 'Orders' : 'My orders')),
      body: body,
    );
  }
}

class _OrderData {
  _OrderData(this.orders, this.names);
  final List<Json> orders;
  final Map<String, String> names;
}
