import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/providers.dart';
import '../../core/models/models.dart';

// Navigation index provider
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

class NewShellScreen extends ConsumerWidget {
  const NewShellScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final currentIndex = ref.watch(selectedNavIndexProvider);
    final userRole = ref.watch(currentUserRoleProvider).valueOrNull;
    final isAdmin = userRole == UserRole.admin;

    // Role-based navigation items
    final navItems = isAdmin ? [
      _NavItemData(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
      _NavItemData(icon: Icons.people_rounded, label: 'Students', route: '/dashboard'),
      _NavItemData(icon: Icons.check_circle_rounded, label: 'Attendance', route: '/dashboard'),
      _NavItemData(icon: Icons.analytics_rounded, label: 'Reports', route: '/reports'),
      _NavItemData(icon: Icons.admin_panel_settings_rounded, label: 'Admin', route: '/admin'),
    ] : [
      _NavItemData(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
      _NavItemData(icon: Icons.people_rounded, label: 'Students', route: '/dashboard'),
      _NavItemData(icon: Icons.check_circle_rounded, label: 'Attendance', route: '/dashboard'),
      _NavItemData(icon: Icons.assignment_rounded, label: 'Homework', route: '/dashboard'),
      _NavItemData(icon: Icons.more_horiz_rounded, label: 'More', route: '/admin'),
    ];

    void onNavTap(int index, String route) {
      ref.read(selectedNavIndexProvider.notifier).state = index;
      context.go(route);
    }

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipOval(
                child: Image.asset('assets/logo.png', width: 32, height: 32, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('NEMPS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.amber : Colors.lightBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isAdmin ? 'Admin' : 'Teacher', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white),
              onPressed: () {
                final current = ref.read(themeProvider);
                ref.read(themeProvider.notifier).state = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
              onSelected: (value) async {
                if (value == 'logout') {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'role',
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(isAdmin ? 'Admin Account' : 'Teacher Account', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        drawer: Drawer(
          child: _MobileDrawer(selectedIndex: currentIndex, onItemSelected: (index, route) {
            onNavTap(index, route);
            Navigator.pop(context);
          }, isAdmin: isAdmin),
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => onNavTap(index, navItems[index].route),
          destinations: navItems.map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label)).toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: _DesktopSidebar(selectedIndex: currentIndex, onItemSelected: onNavTap, isAdmin: isAdmin),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Text(_getPageTitle(GoRouterState.of(context).matchedLocation),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, size: 16, color: isAdmin ? Colors.amber[700] : Colors.blue),
                            const SizedBox(width: 4),
                            Text(isAdmin ? 'Admin' : 'Teacher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAdmin ? Colors.amber[700] : Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                        onPressed: () {
                          final current = ref.read(themeProvider);
                          ref.read(themeProvider.notifier).state = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                        },
                      ),
                      PopupMenuButton<String>(
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        onSelected: (value) async {
                          if (value == 'logout') {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) context.go('/login');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'logout', child: Text('Logout')),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String route) {
    if (route.startsWith('/dashboard')) return 'Dashboard';
    if (route.startsWith('/class/')) return 'Class Details';
    if (route.startsWith('/attendance')) return 'Attendance';
    if (route.startsWith('/students')) return 'Students';
    if (route.startsWith('/homework')) return 'Homework';
    if (route.startsWith('/reports')) return 'Reports';
    if (route.startsWith('/admin')) return 'Admin Panel';
    if (route.startsWith('/exam-marks')) return 'Marks Entry';
    if (route.startsWith('/results')) return 'Results';
    if (route.startsWith('/analytics')) return 'Analytics';
    return 'NEMPS';
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final String route;
  const _NavItemData({required this.icon, required this.label, required this.route});
}

// Mobile Drawer
class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;
  final bool isAdmin;

  const _MobileDrawer({required this.selectedIndex, required this.onItemSelected, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // Role-based menu sections
    final List<_MenuSectionData> menuSections = isAdmin ? [
      _MenuSectionData('MAIN', [
        _MenuTileData(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSectionData('MANAGEMENT', [
        _MenuTileData(icon: Icons.people_rounded, title: 'Students', index: 1, route: '/dashboard'),
        _MenuTileData(icon: Icons.check_circle_rounded, title: 'Attendance', index: 2, route: '/dashboard'),
      ]),
      _MenuSectionData('ACADEMICS', [
        _MenuTileData(icon: Icons.analytics_rounded, title: 'Reports', index: 3, route: '/reports'),
        _MenuTileData(icon: Icons.print_rounded, title: 'Print Results', index: 4, route: '/reports'),
      ]),
      _MenuSectionData('ADMIN', [
        _MenuTileData(icon: Icons.admin_panel_settings_rounded, title: 'Admin Panel', index: 5, route: '/admin'),
        _MenuTileData(icon: Icons.school_rounded, title: 'Academic Sessions', index: 6, route: '/admin'),
        _MenuTileData(icon: Icons.class_rounded, title: 'Class Management', index: 7, route: '/admin'),
        _MenuTileData(icon: Icons.person_rounded, title: 'User Management', index: 8, route: '/admin'),
        _MenuTileData(icon: Icons.notifications_rounded, title: 'Notice Board', index: 9, route: '/admin'),
      ]),
    ] : [
      _MenuSectionData('MAIN', [
        _MenuTileData(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSectionData('MY TASKS', [
        _MenuTileData(icon: Icons.people_rounded, title: 'My Students', index: 1, route: '/dashboard'),
        _MenuTileData(icon: Icons.check_circle_rounded, title: 'Mark Attendance', index: 2, route: '/dashboard'),
        _MenuTileData(icon: Icons.assignment_rounded, title: 'Homework', index: 3, route: '/dashboard'),
      ]),
      _MenuSectionData('ACADEMICS', [
        _MenuTileData(icon: Icons.analytics_rounded, title: 'Results', index: 4, route: '/reports'),
        _MenuTileData(icon: Icons.print_rounded, title: 'Print Results', index: 5, route: '/reports'),
      ]),
    ];

    return Container(
      color: const Color(0xFF1E40AF),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('🏫', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NEMPS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.amber : Colors.lightBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isAdmin ? 'Admin' : 'Teacher', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: menuSections.expand((section) => [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(section.title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  ...section.items.map((tile) => ListTile(
                    leading: Icon(tile.icon, color: selectedIndex == tile.index ? Colors.white : Colors.white70),
                    title: Text(tile.title, style: TextStyle(color: selectedIndex == tile.index ? Colors.white : Colors.white70, fontWeight: selectedIndex == tile.index ? FontWeight.w600 : FontWeight.normal)),
                    selected: selectedIndex == tile.index,
                    selectedTileColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () => onItemSelected(tile.index, tile.route),
                  )),
                ]).toList(),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSectionData {
  final String title;
  final List<_MenuTileData> items;
  const _MenuSectionData(this.title, this.items);
}

class _MenuTileData {
  final IconData icon;
  final String title;
  final int index;
  final String route;
  const _MenuTileData({required this.icon, required this.title, required this.index, required this.route});
}

// Desktop Sidebar
class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;
  final bool isAdmin;

  const _DesktopSidebar({required this.selectedIndex, required this.onItemSelected, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // Role-based menu sections
    final List<_MenuSectionData> menuSections = isAdmin ? [
      _MenuSectionData('MAIN', [
        _MenuTileData(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSectionData('MANAGEMENT', [
        _MenuTileData(icon: Icons.people_rounded, title: 'Students', index: 1, route: '/dashboard'),
        _MenuTileData(icon: Icons.check_circle_rounded, title: 'Attendance', index: 2, route: '/dashboard'),
      ]),
      _MenuSectionData('ACADEMICS', [
        _MenuTileData(icon: Icons.analytics_rounded, title: 'Reports', index: 3, route: '/reports'),
        _MenuTileData(icon: Icons.print_rounded, title: 'Print Results', index: 4, route: '/reports'),
      ]),
      _MenuSectionData('ADMIN', [
        _MenuTileData(icon: Icons.admin_panel_settings_rounded, title: 'Admin Panel', index: 5, route: '/admin'),
        _MenuTileData(icon: Icons.school_rounded, title: 'Sessions', index: 6, route: '/admin'),
        _MenuTileData(icon: Icons.class_rounded, title: 'Classes', index: 7, route: '/admin'),
        _MenuTileData(icon: Icons.person_rounded, title: 'Users', index: 8, route: '/admin'),
        _MenuTileData(icon: Icons.notifications_rounded, title: 'Notices', index: 9, route: '/admin'),
      ]),
    ] : [
      _MenuSectionData('MAIN', [
        _MenuTileData(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSectionData('MY TASKS', [
        _MenuTileData(icon: Icons.people_rounded, title: 'My Students', index: 1, route: '/dashboard'),
        _MenuTileData(icon: Icons.check_circle_rounded, title: 'Mark Attendance', index: 2, route: '/dashboard'),
        _MenuTileData(icon: Icons.assignment_rounded, title: 'Homework', index: 3, route: '/dashboard'),
      ]),
      _MenuSectionData('ACADEMICS', [
        _MenuTileData(icon: Icons.analytics_rounded, title: 'Results', index: 4, route: '/reports'),
        _MenuTileData(icon: Icons.print_rounded, title: 'Print Results', index: 5, route: '/reports'),
      ]),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('🏫', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NEMPS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.amber : Colors.lightBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isAdmin ? 'Admin' : 'Teacher', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: menuSections.expand((section) => [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(section.title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                ...section.items.map((tile) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Material(
                    color: selectedIndex == tile.index ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onItemSelected(tile.index, tile.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(tile.icon, color: selectedIndex == tile.index ? Colors.white : Colors.white70, size: 22),
                            const SizedBox(width: 14),
                            Text(tile.title, style: TextStyle(color: selectedIndex == tile.index ? Colors.white : Colors.white70, fontWeight: selectedIndex == tile.index ? FontWeight.w600 : FontWeight.normal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ]).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
