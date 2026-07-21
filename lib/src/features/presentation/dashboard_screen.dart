import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../data/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);
    final isAdmin = roleAsync.valueOrNull == UserRole.admin;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '🌅 Good Morning'
        : hour < 17
            ? '☀️ Good Afternoon'
            : '🌙 Good Evening';
    final userName =
        Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
            'Teacher';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(classesProvider);
        ref.invalidate(currentUserRoleProvider);
        ref.invalidate(allNoticesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting card with logo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      Text(userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const Text('Aaj ka kaam poora karein 💪',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // School logo
                ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Notices Section ─────────────────────────────────────────────────
          _NoticesBanner(isAdmin: isAdmin),
          const SizedBox(height: 16),

          // My Classes section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Meri Classes',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              classes.when(
                data: (items) => Text('${items.length} class',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          classes.when(
            data: (items) => items.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.class_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant),
                          const SizedBox(height: 8),
                          const Text('Koi class assign nahi.\nAdmin se contact karein.',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: items
                        .map((room) => _ClassCard(room: room))
                        .toList(),
                  ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.wifi_off, color: Colors.orange),
                title: const Text('Classes load nahi huyi'),
                subtitle: const Text('Pull down to retry'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(classesProvider),
                ),
              ),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text('Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _QuickActionCard(
                icon: Icons.fact_check_rounded,
                label: 'Attendance',
                color: AppTheme.attendanceColor,
                onTap: classes.valueOrNull?.isNotEmpty == true
                    ? () => context
                        .go('/attendance/${classes.value!.first.id}')
                    : null,
              ),
              _QuickActionCard(
                icon: Icons.assignment_rounded,
                label: 'Homework',
                color: AppTheme.homeworkColor,
                onTap: classes.valueOrNull?.isNotEmpty == true
                    ? () =>
                        context.go('/homework/${classes.value!.first.id}')
                    : null,
              ),
              _QuickActionCard(
                icon: Icons.message_rounded,
                label: 'WhatsApp',
                color: AppTheme.whatsappColor,
                onTap: classes.valueOrNull?.isNotEmpty == true
                    ? () =>
                        context.go('/absent/${classes.value!.first.id}')
                    : null,
              ),
              _QuickActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                color: AppTheme.infoColor,
                onTap: () => context.go('/reports'),
              ),
            ],
          ),

          if (isAdmin) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.go('/admin'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Panel',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('Classes, Teachers, Students manage karein',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Notices Banner ─────────────────────────────────────────────────────────────

class _NoticesBanner extends ConsumerWidget {
  const _NoticesBanner({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(allNoticesProvider);

    return notices.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 6),
                Text('School Notices',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7C3AED))),
                const Spacer(),
                Text('${items.length} notice',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ...items.take(3).map((n) => _NoticeCard(notice: n)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTime(notice.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF7C3AED).withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF7C3AED).withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_rounded,
                  size: 16, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (notice.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notice.body,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Text(timeAgo,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }
}

// ── Class Card ─────────────────────────────────────────────────────────────────

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.room});
  final ClassRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceDone = ref.watch(attendanceDoneTodayProvider(room.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.go('/class/${room.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(room.name,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class ${room.label}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    attendanceDone.when(
                      data: (done) => Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: done
                                  ? AppTheme.attendanceColor.withOpacity(0.15)
                                  : AppTheme.pendingColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  done
                                      ? Icons.check_circle_rounded
                                      : Icons.pending_rounded,
                                  size: 12,
                                  color: done
                                      ? AppTheme.attendanceColor
                                      : AppTheme.pendingColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  done
                                      ? 'Attendance done'
                                      : 'Attendance pending',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: done
                                          ? AppTheme.attendanceColor
                                          : AppTheme.pendingColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.5)),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Action Card ──────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
