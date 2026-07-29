// Fees Management — Home Menu
// Phase 3C: replaces the old 4-tabs-inside-a-screen layout with a clean
// menu of dedicated screens — each fee action gets its own proper button,
// matching how the rest of Admin Panel was split up in Phase 3B.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeesHomeScreen extends StatelessWidget {
  const FeesHomeScreen({super.key});

  static const _items = [
    _FeesMenuItem(
      icon: Icons.category,
      color: Color(0xFF4F46E5),
      title: 'Fee Types',
      subtitle: 'Tuition, Transport, Exam Fee jaise types banayein',
      route: '/admin/fees/types',
    ),
    _FeesMenuItem(
      icon: Icons.class_rounded,
      color: Color(0xFF0891B2),
      title: 'Class Fee Config',
      subtitle: 'Har class ke liye fee amount set karein',
      route: '/admin/fees/class-config',
    ),
    _FeesMenuItem(
      icon: Icons.payments_rounded,
      color: Color(0xFF059669),
      title: 'Collect Fees & Receipts',
      subtitle: 'Payment collect karein, receipt print/delete karein',
      route: '/fee-collection',
    ),
    _FeesMenuItem(
      icon: Icons.analytics_rounded,
      color: Color(0xFFD97706),
      title: 'Fee Reports',
      subtitle: 'Due List, Collection aur Export — ek jagah',
      route: '/admin/fees/reports',
    ),
    _FeesMenuItem(
      icon: Icons.upload_file_rounded,
      color: Color(0xFF7C3AED),
      title: 'Import / Export (Advanced)',
      subtitle: 'CSV/Excel se bulk fees import ya export karein',
      route: '/admin/fees/advanced',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees Management')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = _items[i];
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(item.route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(item.subtitle,
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeesMenuItem {
  const _FeesMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
}
