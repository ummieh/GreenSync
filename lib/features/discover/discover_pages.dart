import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';

/// Where to drop recyclables off.
class RecyclingCentresPage extends StatefulWidget {
  const RecyclingCentresPage({super.key});

  @override
  State<RecyclingCentresPage> createState() => _RecyclingCentresPageState();
}

class _RecyclingCentresPageState extends State<RecyclingCentresPage> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final rows = await supabase
        .from('recycling_centres')
        .select('*, recycling_centre_categories(categories(name))')
        .eq('is_active', true)
        .order('name');
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Recycling centres')),
      body: AsyncBody<List<Json>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.place_outlined,
              title: 'No centres listed yet',
              message: 'Drop-off points will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final c = rows[i];
              final cats = ((c['recycling_centre_categories'] as List?) ?? [])
                  .map((e) => (e['categories'] as Map?)?['name'] as String?)
                  .whereType<String>()
                  .toList();
              final hours = c['operating_hours'];
              final desc = c['description'] as String?;
              final phone = c['phone'] as String?;
              return InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 18, color: muted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c['address'] as String)),
                      ],
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.phone_outlined, size: 18, color: muted),
                          const SizedBox(width: 6),
                          Text(phone),
                        ]),
                      ),
                    if (hours is Map && hours.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.schedule, size: 18, color: muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(hours.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join('\n')),
                            ),
                          ],
                        ),
                      ),
                    if (desc != null && desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(desc, style: TextStyle(color: muted)),
                    ],
                    if (cats.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final name in cats)
                            Chip(
                              avatar: Icon(categoryIcon(name),
                                  size: 16, color: AppColors.forest),
                              label: Text(name),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Articles and tips about recycling.
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final rows = await supabase
        .from('educational_resources')
        .select()
        .eq('is_published', true)
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false);
    return rows;
  }

  IconData _icon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline;
      case 'tip':
        return Icons.lightbulb_outline;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: AsyncBody<List<Json>>(
        future: _future,
        onRetry: () => setState(() => _future = _load()),
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Nothing to read yet',
              message: 'Recycling guides and tips will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final body = (r['body'] as String?) ?? '';
              return InfoCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _ArticlePage(article: r)),
                ),
                child: Row(
                  children: [
                    Icon(_icon(r['type'] as String),
                        size: 30, color: AppColors.forest),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['title'] as String,
                              style: Theme.of(context).textTheme.titleSmall),
                          if (body.isNotEmpty)
                            Text(body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArticlePage extends StatelessWidget {
  const _ArticlePage({required this.article});

  final Json article;

  @override
  Widget build(BuildContext context) {
    final author = article['author_name'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(article['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall),
          if (author != null && author.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('By $author',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 16),
          Text((article['body'] as String?) ?? '',
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
