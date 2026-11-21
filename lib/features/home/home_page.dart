import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../authentication/session_controller.dart';
import '../collection/request_pickup_page.dart';
import '../discover/discover_pages.dart';
import '../market/orders_page.dart';
import '../market/product_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenTab});

  /// Switches the bottom navigation to another tab.
  final void Function(int index) onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>?> _nextPickup;
  late Future<List<Json>> _fresh;

  @override
  void initState() {
    super.initState();
    _nextPickup = _loadNextPickup();
    _fresh = _loadFresh();
  }

  Future<Map<String, dynamic>?> _loadNextPickup() async {
    final uid = supabase.auth.currentUser!.id;
    return await supabase
        .from('collection_requests')
        .select('status, scheduled_date, address')
        .eq('user_id', uid)
        .inFilter('status', ['pending', 'accepted'])
        .order('scheduled_date', ascending: true)
        .limit(1)
        .maybeSingle();
  }

  Future<List<Json>> _loadFresh() async {
    final rows = await supabase
        .from('products')
        .select('*, categories(name)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(8);
    return List<Json>.from(rows as List);
  }

  Future<void> _refresh(SessionController session) async {
    await session.loadProfile();
    setState(() {
      _nextPickup = _loadNextPickup();
      _fresh = _loadFresh();
    });
    try {
      await _nextPickup;
    } catch (_) {
      // The FutureBuilder below shows the error.
    }
  }

  Future<void> _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _requestPickup(SessionController session) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RequestPickupPage()),
    );
    if (ok == true) _refresh(session);
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.sandSoft,
              child: Icon(icon, color: AppColors.forest),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style:
                    const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }

  Widget _hero(SessionController session, String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.forest, Color(0xFF1B8A7F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $name',
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${session.points}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text('points',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Earn 10 points for every kg you recycle',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => widget.onOpenTab(3),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sand,
              foregroundColor: const Color(0xFF2A1700),
            ),
            icon: const Icon(Icons.card_giftcard, size: 18),
            label: const Text('Rewards'),
          ),
        ],
      ),
    );
  }

  Widget _pickupCard(SessionController session, ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _nextPickup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Text('Could not load your pickups. Pull down to retry.',
              style: TextStyle(color: theme.colorScheme.error));
        }
        final pickup = snapshot.data;
        if (pickup == null) {
          return InfoCard(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.sandSoft,
                  child: Icon(Icons.local_shipping_outlined,
                      color: AppColors.forest),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('No pickups scheduled.')),
                FilledButton(
                  onPressed: () => _requestPickup(session),
                  child: const Text('Request'),
                ),
              ],
            ),
          );
        }
        final when =
            DateTime.parse(pickup['scheduled_date'] as String).toLocal();
        return InfoCard(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.sandSoft,
                child: Icon(Icons.local_shipping_outlined,
                    color: AppColors.forest),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatDate(when)}, ${formatTime(when)}',
                        style: theme.textTheme.titleSmall),
                    Text('${pickup['address']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13)),
                  ],
                ),
              ),
              StatusChip(pickup['status'] as String),
            ],
          ),
        );
      },
    );
  }

  Widget _freshGrid() {
    return FutureBuilder<List<Json>>(
      future: _fresh,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final items = snapshot.data ?? const <Json>[];
        if (items.isEmpty) return const Text('Nothing listed yet.');
        return ResponsiveGrid(
          maxExtent: 220,
          aspect: 0.8,
          children: [
            for (final p in items)
              Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => _push(ProductDetailPage(product: p)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ProductThumb(p,
                            size: double.infinity,
                            height: double.infinity,
                            radius: 0),
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
                            Text('${money(p['price'] as num)}/${p['unit']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile!;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => _refresh(session),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _hero(session, profile.firstName),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _action(Icons.local_shipping_outlined, 'Request pickup',
                        () => _requestPickup(session)),
                    _action(Icons.receipt_long_outlined, 'My orders',
                        () => _push(const OrdersPage(asSeller: false))),
                    _action(Icons.place_outlined, 'Recycling centres',
                        () => _push(const RecyclingCentresPage())),
                    _action(Icons.menu_book_outlined, 'Learn',
                        () => _push(const LearnPage())),
                  ],
                ),
              ),
              _sectionTitle('Next pickup'),
              _pickupCard(session, theme),
              _sectionTitle('Marketplace',
                  action: 'See all', onAction: () => widget.onOpenTab(2)),
              _freshGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
