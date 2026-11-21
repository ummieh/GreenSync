import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/common.dart';
import '../authentication/session_controller.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late Future<_RewardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RewardData> _load() async {
    final uid = supabase.auth.currentUser!.id;
    final rewards = await supabase
        .from('rewards')
        .select()
        .eq('is_active', true)
        .order('points_cost');
    final history = await supabase
        .from('points_ledger')
        .select('points, reason, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(15);
    return _RewardData(rewards, history);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _redeem(Json reward) async {
    final session = SessionScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem reward?'),
        content: Text(
            '${reward['title']} costs ${reward['points_cost']} points.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Redeem')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase
          .rpc('redeem_reward', params: {'p_reward_id': reward['id']});
      await session.loadProfile();
      if (mounted) showMessage(context, 'Reward redeemed.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AsyncBody<_RewardData>(
      future: _future,
      onRetry: _reload,
      builder: (context, data) => RefreshIndicator(
        onRefresh: () async {
          await session.loadProfile();
          _reload();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            InfoCard(
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      size: 36, color: AppColors.sand),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${session.points} points',
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700)),
                      Text('Earn 10 points for every kg you recycle',
                          style: TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Rewards', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (data.rewards.isEmpty)
              const EmptyState(
                icon: Icons.card_giftcard_outlined,
                title: 'No rewards available',
                message: 'Check back soon.',
              )
            else
              ResponsiveGrid(maxExtent: 260, aspect: 0.95, children: [
                for (final r in data.rewards)
                  _rewardCard(r, session.points, muted),
              ]),
            const SizedBox(height: 16),
            Text('Points history', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (data.history.isEmpty)
              Text('No points yet. Complete a pickup to earn some.',
                  style: TextStyle(color: muted))
            else
              for (final h in data.history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(h['reason'] as String),
                  subtitle: Text(formatDate(
                      DateTime.parse(h['created_at'] as String).toLocal())),
                  trailing: Text(
                    '${(h['points'] as int) > 0 ? '+' : ''}${h['points']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (h['points'] as int) > 0
                          ? AppColors.forest
                          : const Color(0xFFB3412F),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _rewardCard(Json r, int balance, Color muted) {
    final cost = r['points_cost'] as int;
    final canAfford = balance >= cost;
    final sponsor = r['sponsor_name'] as String?;
    final desc = r['description'] as String?;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.sandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.card_giftcard, color: AppColors.forest),
            ),
            const SizedBox(height: 10),
            Text(r['title'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall),
            if (desc != null && desc.isNotEmpty)
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12)),
            if (sponsor != null && sponsor.isNotEmpty)
              Text('By $sponsor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                Text('$cost pts',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton(
                  onPressed: canAfford ? () => _redeem(r) : null,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('Redeem'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardData {
  _RewardData(this.rewards, this.history);
  final List<Json> rewards;
  final List<Json> history;
}
