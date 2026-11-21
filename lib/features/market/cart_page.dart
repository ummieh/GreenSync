import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import 'orders_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Future<List<Json>> _future;
  final _address = TextEditingController();
  final _note = TextEditingController();
  String _fulfilment = 'pickup';
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<List<Json>> _load() async {
    final rows = await supabase
        .from('cart_items')
        .select('quantity, product_id, products(title, price, unit, quantity_available, status)')
        .eq('user_id', supabase.auth.currentUser!.id);
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setQty(Json item, double qty) async {
    final uid = supabase.auth.currentUser!.id;
    try {
      if (qty <= 0) {
        await supabase
            .from('cart_items')
            .delete()
            .eq('user_id', uid)
            .eq('product_id', item['product_id']);
      } else {
        await supabase
            .from('cart_items')
            .update({'quantity': qty})
            .eq('user_id', uid)
            .eq('product_id', item['product_id']);
      }
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  num _total(List<Json> items) {
    num total = 0;
    for (final i in items) {
      final p = i['products'] as Map?;
      if (p == null) continue;
      total += (p['price'] as num) * (i['quantity'] as num);
    }
    return total;
  }

  Future<void> _place() async {
    if (_fulfilment == 'delivery' && _address.text.trim().isEmpty) {
      showMessage(context, 'Enter a delivery address.');
      return;
    }
    setState(() => _placing = true);
    try {
      await supabase.rpc('place_orders_from_cart', params: {
        'p_fulfilment': _fulfilment,
        'p_address': _fulfilment == 'delivery' ? _address.text.trim() : null,
        'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, 'Order placed. The seller will confirm it.');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrdersPage(asSeller: false)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _placing = false);
        showMessage(context, errorText(e));
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: AsyncBody<List<Json>>(
        future: _future,
        onRetry: _reload,
        builder: (context, items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add materials from the marketplace.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final i in items) _line(i),
              const Divider(height: 32),
              Row(
                children: [
                  const Expanded(child: Text('Total')),
                  Text(money(_total(items)),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.forest, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'pickup',
                      icon: Icon(Icons.store_outlined),
                      label: Text('Pickup')),
                  ButtonSegment(
                      value: 'delivery',
                      icon: Icon(Icons.local_shipping_outlined),
                      label: Text('Delivery')),
                ],
                selected: {_fulfilment},
                onSelectionChanged: (s) =>
                    setState(() => _fulfilment = s.first),
              ),
              if (_fulfilment == 'delivery') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: appInput('Delivery address'),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: appInput('Note for the seller (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _placing ? null : _place,
                child: _placing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Place order'),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment is arranged with the seller for now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(Json item) {
    final p = item['products'] as Map?;
    final qty = (item['quantity'] as num).toDouble();
    if (p == null) {
      return const SizedBox.shrink();
    }
    return InfoCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['title'] as String,
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${money(p['price'] as num)}/${p['unit']}'),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _setQty(item, qty - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(qty % 1 == 0 ? qty.toInt().toString() : qty.toString()),
          IconButton(
            onPressed: () => _setQty(item, qty + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
