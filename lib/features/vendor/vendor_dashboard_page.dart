import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import '../authentication/session_controller.dart';

class VendorDashboardPage extends StatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  State<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends State<VendorDashboardPage> {
  late Future<Map<String, num>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, num>> _load() async {
    final uid = supabase.auth.currentUser!.id;
    final open = await supabase
        .from('collection_requests')
        .select('id')
        .eq('status', 'pending')
        .neq('user_id', uid);
    final mine = await supabase
        .from('collection_requests')
        .select('status, actual_weight_kg')
        .eq('vendor_id', uid);
    final orders = await supabase
        .from('orders')
        .select('status, total_amount')
        .eq('seller_id', uid);
    final listings = await supabase
        .from('products')
        .select('id')
        .eq('seller_id', uid)
        .eq('status', 'active');

    num kg = 0;
    var done = 0;
    var inProgress = 0;
    for (final r in mine) {
      if (r['status'] == 'completed') {
        done++;
        kg += (r['actual_weight_kg'] as num?) ?? 0;
      } else if (r['status'] == 'accepted') {
        inProgress++;
      }
    }
    num sales = 0;
    var toHandle = 0;
    for (final o in orders) {
      final s = o['status'] as String;
      if (s == 'completed') sales += (o['total_amount'] as num?) ?? 0;
      if (s == 'placed' || s == 'confirmed') toHandle++;
    }
    return {
      'open': open.length,
      'done': done,
      'inProgress': inProgress,
      'kg': kg,
      'sales': sales,
      'toHandle': toHandle,
      'listings': listings.length,
    };
  }

  void _reload() => setState(() => _future = _load());

  Widget _stat(String label, String value, IconData icon) {
    return InfoCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.forest),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.forest, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final business = session.application?.businessName ?? session.profile!.displayName;
    return AsyncBody<Map<String, num>>(
      future: _future,
      onRetry: _reload,
      builder: (context, s) => RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(business, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Your vendor dashboard',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _stat('Open pickup requests', '${s['open']}', Icons.inbox_outlined),
            _stat('Pickups in progress', '${s['inProgress']}',
                Icons.local_shipping_outlined),
            _stat('Pickups completed', '${s['done']}', Icons.check_circle_outline),
            _stat('Waste collected', kgText(s['kg']!), Icons.recycling),
            _stat('Orders to handle', '${s['toHandle']}',
                Icons.receipt_long_outlined),
            _stat('Sales completed', money(s['sales']!), Icons.payments_outlined),
            _stat('Active listings', '${s['listings']}', Icons.sell_outlined),
          ],
        ),
      ),
    );
  }
}
