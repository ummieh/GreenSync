import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final Json product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<Map<String, String>> _seller;
  final _qty = TextEditingController(text: '1');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seller = fetchNames([widget.product['seller_id'] as String]);
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _addToCart({required bool thenOpenCart}) async {
    final p = widget.product;
    final q = double.tryParse(_qty.text.trim());
    final available = (p['quantity_available'] as num).toDouble();
    if (q == null || q <= 0) {
      showMessage(context, 'Enter a quantity above 0.');
      return;
    }
    if (q > available) {
      showMessage(context, 'Only $available ${p['unit']} available.');
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.from('cart_items').upsert({
        'user_id': supabase.auth.currentUser!.id,
        'product_id': p['id'],
        'quantity': q,
      }, onConflict: 'user_id,product_id');
      if (!mounted) return;
      if (thenOpenCart) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CartPage()),
        );
      } else {
        showMessage(context, 'Added to cart.');
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final cat = (p['categories'] as Map?)?['name'] as String?;
    final mine = p['seller_id'] == supabase.auth.currentUser!.id;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final desc = (p['description'] as String?) ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProductThumb(p, size: double.infinity, height: 260, radius: 16),
          const SizedBox(height: 16),
          Text(p['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${money(p['price'] as num)} per ${p['unit']}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppColors.forest, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (cat != null) Chip(label: Text(cat)),
              Chip(
                  label: Text(
                      '${p['quantity_available']} ${p['unit']} available')),
              if ((p['location'] as String?)?.isNotEmpty == true)
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(p['location'] as String),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, String>>(
            future: _seller,
            builder: (context, snap) {
              final name = snap.data?[p['seller_id']] ?? '...';
              return Text('Sold by $name', style: TextStyle(color: muted));
            },
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(desc),
          ],
          const SizedBox(height: 24),
          if (mine)
            Text('This is your own listing, so you cannot buy it.',
                style: TextStyle(color: muted))
          else ...[
            TextField(
              controller: _qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: appInput('Quantity (${p['unit']})'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _addToCart(thenOpenCart: true),
              child: const Text('Buy now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _addToCart(thenOpenCart: false),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Add to cart'),
            ),
          ],
        ],
      ),
    );
  }
}
