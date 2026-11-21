import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// One row coming back from the database.
typedef Json = Map<String, dynamic>;

/// 12500 -> ₦12,500   |   99.5 -> ₦99.50
String money(num value) {
  final isWhole = value % 1 == 0;
  final fixed = value.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '₦$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String kgText(num value) =>
    '${value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1)} kg';

String niceStatus(String status) {
  final s = status.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String errorText(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}

/// Looks up display names for a set of user ids.
Future<Map<String, String>> fetchNames(Iterable<String> ids) async {
  final list = ids.toSet().toList();
  if (list.isEmpty) return {};
  final rows = await supabase
      .from('public_profiles')
      .select('id, full_name')
      .inFilter('id', list);
  final result = <String, String>{};
  for (final r in rows) {
    final name = (r['full_name'] as String?)?.trim() ?? '';
    result[r['id'] as String] = name.isEmpty ? 'GreenSync member' : name;
  }
  return result;
}

IconData categoryIcon(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('plastic')) return Icons.local_drink_outlined;
  if (n.contains('glass')) return Icons.wine_bar_outlined;
  if (n.contains('paper')) return Icons.description_outlined;
  if (n.contains('metal')) return Icons.hardware_outlined;
  if (n.contains('electr')) return Icons.devices_other_outlined;
  if (n.contains('organic')) return Icons.eco_outlined;
  if (n.contains('textile')) return Icons.checkroom_outlined;
  return Icons.recycling;
}

Color statusColor(String status) {
  switch (status) {
    case 'pending':
    case 'placed':
      return AppColors.sand;
    case 'accepted':
    case 'confirmed':
      return const Color(0xFF2F80ED);
    case 'completed':
    case 'active':
      return AppColors.forest;
    case 'cancelled':
    case 'removed':
      return const Color(0xFFB3412F);
    default:
      return const Color(0xFF7A7A7A);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        niceStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Shows a spinner while loading, an error with a retry button, or the data.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load this',
            message: errorText(snapshot.error!),
            action: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// White rounded card used across the app.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

/// A listing's photo, or the category icon when it has none.
class ProductThumb extends StatelessWidget {
  const ProductThumb(this.product,
      {super.key, this.size = 56, this.height, this.radius = 12});

  final Json product;
  final double size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cat = (product['categories'] as Map?)?['name'] as String?;
    final asset = product['image_asset'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size.isInfinite ? null : size,
        height: height ?? size,
        child: asset != null
            ? Image.asset(asset, fit: BoxFit.cover)
            : ColoredBox(
                color: AppColors.sandSoft,
                child: Center(
                  child: Icon(categoryIcon(cat),
                      color: AppColors.forest, size: size.isInfinite ? 64 : size * 0.5),
                ),
              ),
      ),
    );
  }
}

/// Lays children out as a grid that adapts to the screen width.
/// Use inside a ListView.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxExtent = 230,
    this.aspect = 0.72,
  });

  final List<Widget> children;
  final double maxExtent;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: aspect,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      children: children,
    );
  }
}
