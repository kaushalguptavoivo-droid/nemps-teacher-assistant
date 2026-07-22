// Examination Module — Admin "Exam Management" Tab
// This widget is inserted as a new tab inside the existing AdminPanelScreen.
// No existing tabs are modified.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'academic_session_screen.dart';
import 'exam_config_screen.dart';
import 'subject_config_screen.dart';
import 'grade_config_screen.dart';

class AdminExamTab extends StatelessWidget {
  const AdminExamTab({super.key});

  static const _sections = [
    _Section(
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF4F46E5),
      title: 'Academic Session',
      subtitle: '2026-27 jaise sessions banayein, active karein',
      useRouter: false,
    ),
    _Section(
      icon: Icons.assignment_turned_in_rounded,
      color: Color(0xFF0891B2),
      title: 'Exam Configuration',
      subtitle: 'Class-wise pattern set karein — Nursery ya Prep to 8',
      useRouter: false,
    ),
    _Section(
      icon: Icons.menu_book_rounded,
      color: Color(0xFF059669),
      title: 'Subject Configuration',
      subtitle: 'Har class ke subjects manage karein',
      useRouter: false,
    ),
    _Section(
      icon: Icons.grade_rounded,
      color: Color(0xFFD97706),
      title: 'Grade Configuration',
      subtitle: 'A1 se E tak grade ranges define karein',
      useRouter: false,
    ),
    // ── Phase 7: Promotion Engine ────────────────────────────────────────────
    _Section(
      icon: Icons.school_rounded,
      color: Color(0xFF0D9488),
      title: 'Promotion Engine',
      subtitle: 'Students ko promote / hold karein — override bhi kar sakte hain',
      useRouter: true,
      route: '/promotion',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = _sections[index];
        return _SectionCard(
          section: s,
          onTap: () => _navigate(context, index, s),
        );
      },
    );
  }

  void _navigate(BuildContext context, int index, _Section s) {
    if (s.useRouter && s.route != null) {
      context.push(s.route!);
      return;
    }
    final screens = [
      const AcademicSessionScreen(),
      const ExamConfigScreen(),
      const SubjectConfigScreen(),
      const GradeConfigScreen(),
    ];
    if (index < screens.length) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screens[index]),
      );
    }
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _Section {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.useRouter = false,
    this.route,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool useRouter;
  final String? route;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});
  final _Section section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: section.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: section.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
