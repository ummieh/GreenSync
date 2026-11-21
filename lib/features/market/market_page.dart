import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import 'cart_page.dart';
import 'create_listing_page.dart';
import 'listings_page.dart';
import 'orders_page.dart';
import 'product_detail_page.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  late Future<_MarketData> _future;
  final _search = TextEditingController();
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_MarketData> _load() async {
    final products = await supabase
        .from('products')
        .select('*, categories(name)')
        .eq('status', 'active')
        .order('created_at', ascending: false);
    final cats = await supabase.from('categories').select().order('name');
    return _MarketData(products, cats);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser!.id;
    return AsyncBody<_MarketData>(
      future: _future,
      onRetry: _reload,
      builder: (context, data) {
        final q = _search.text.trim().toLowerCase();
        final shown = data.products.where((p) {
          if (_categoryId != null && p['category_id'] != _categoryId) {
            return false;
          }
          if (q.isEmpty) return true;
          final hay =
              '${p['title']} ${p['description'] ?? ''} ${p['location'] ?? ''}'
                  .toLowerCase();
          return hay.contains(q);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: appInput('Search materials',
                        suffix: const Icon(Icons.search))
                    .copyWith(isDense: true),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _action(Icons.shopping_cart_outlined, 'Cart',
                        () => _open(const CartPage())),
                    _action(Icons.receipt_long_outlined, 'My orders',
                        () => _open(const OrdersPage(asSeller: false))),
                    _action(Icons.sell_outlined, 'My listings',
                        () => _open(const ListingsPage())),
                    _action(Icons.add_circle_outline, 'Sell',
                        () => _open(const CreateListingPage())),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                    ),
                    for (final c in data.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c['name'] as String),
                          selected: _categoryId == c['id'],
                          onSelected: (_) =>
                              setState(() => _categoryId = c['id'] as int),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Nothing listed here yet',
                    message: 'Try another category, or list something to sell.',
                  ),
                )
              else
                ResponsiveGrid(children: [
                  for (final p in shown) _productTile(p, uid),
                ]),
            ],
          ),
        );
      },
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.forest),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }

  Widget _productTile(Json p, String uid) {
    final cat = (p['categories'] as Map?)?['name'] as String?;
    final mine = p['seller_id'] == uid;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final loc = (p['location'] as String?) ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _open(ProductDetailPage(product: p)),
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
                  if (mine)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Chip(
                        label: Text('Yours', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
                  const SizedBox(height: 2),
                  Text('${money(p['price'] as num)}/${p['unit']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest)),
                  Text(loc.isEmpty ? (cat ?? 'Recyclable') : '${cat ?? 'Recyclable'} · $loc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketData {
  _MarketData(this.products, this.categories);
  final List<Json> products;
  final List<Json> categories;
}
