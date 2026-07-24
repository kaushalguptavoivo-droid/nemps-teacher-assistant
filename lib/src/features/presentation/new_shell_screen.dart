import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/providers.dart';

// Navigation index provider - tracks which nav item is selected
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

// Route to index mapping
int _getIndexFromRoute(String route) {
  if (route.startsWith('/dashboard')) return 0;
  if (route.startsWith('/students')) return 1;
  if (route.startsWith('/attendance')) return 2;
  if (route.startsWith('/homework')) return 3;
  return 4; // More/Admin
}

class NewShellScreen extends ConsumerWidget {
  const NewShellScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Detect screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    // Get current route for navigation state
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final currentIndex = ref.watch(selectedNavIndexProvider);

    // Navigation items
    final navItems = [
      _NavItem(icon: Icons.home_rounded, label: 'Home', route: '/dashboard'),
      _NavItem(icon: Icons.people_rounded, label: 'Students', route: '/dashboard'),
      _NavItem(icon: Icons.check_circle_rounded, label: 'Attendance', route: '/dashboard'),
      _NavItem(icon: Icons.assignment_rounded, label: 'Homework', route: '/dashboard'),
      _NavItem(icon: Icons.more_horiz_rounded, label: 'More', route: '/admin'),
    ];

    void onNavTap(int index, String route) {
      ref.read(selectedNavIndexProvider.notifier).state = index;
      context.go(route);
    }

    // Mobile Layout: Bottom Nav + AppBar
    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('NEMPS',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                ref.watch(themeProvider) == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                final current = ref.read(themeProvider);
                ref.read(themeProvider.notifier).state =
                    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
              onSelected: (value) async {
                if (value == 'logout') {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/login');
                } else if (value == 'settings') {
                  context.go('/admin');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'profile', child: Text('Profile')),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        drawer: Drawer(
          child: _MobileDrawer(
            selectedIndex: currentIndex,
            onItemSelected: (index, route) {
              onNavTap(index, route);
              Navigator.pop(context);
            },
          ),
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => onNavTap(index, navItems[index].route),
          destinations: navItems.map((item) => NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          )).toList(),
        ),
      );
    }

    // Desktop Layout: Sidebar + Main Content
    return Scaffold(
      body: Row(
        children: [
          // Fixed Sidebar
          SizedBox(
            width: 260,
            child: _DesktopSidebar(
              selectedIndex: currentIndex,
              onItemSelected: onNavTap,
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Breadcrumb or title
                      Text(
                        _getPageTitle(currentLocation),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Actions
                      IconButton(
                        icon: Icon(
                          ref.watch(themeProvider) == ThemeMode.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                        onPressed: () {
                          final current = ref.read(themeProvider);
                          ref.read(themeProvider.notifier).state =
                              current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
                // Content
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

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({required this.icon, required this.label, required this.route});
}

// Mobile Drawer
class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const _MobileDrawer({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final menuSections = [
      _MenuSection('MAIN', [
        _MenuTile(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSection('MANAGEMENT', [
        _MenuTile(icon: Icons.people_rounded, title: 'Students', index: 1, route: '/dashboard'),
        _MenuTile(icon: Icons.check_circle_rounded, title: 'Attendance', index: 2, route: '/dashboard'),
        _MenuTile(icon: Icons.assignment_rounded, title: 'Homework', index: 3, route: '/dashboard'),
      ]),
      _MenuSection('ACADEMICS', [
        _MenuTile(icon: Icons.analytics_rounded, title: 'Results', index: 4, route: '/reports'),
        _MenuTile(icon: Icons.payments_rounded, title: 'Fees', index: 5, route: '/admin'),
      ]),
      _MenuSection('SYSTEM', [
        _MenuTile(icon: Icons.admin_panel_settings_rounded, title: 'Admin Panel', index: 6, route: '/admin'),
        _MenuTile(icon: Icons.settings_rounded, title: 'Settings', index: 7, route: '/admin'),
      ]),
    ];

    return Container(
      color: const Color(0xFF1E40AF),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('🏫', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEMPS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Teacher Assistant', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            // Menu
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
            // Logout
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

class _MenuSection {
  final String title;
  final List<_MenuTile> items;
  const _MenuSection(this.title, this.items);
}

class _MenuTile {
  final IconData icon;
  final String title;
  final int index;
  final String route;
  const _MenuTile({required this.icon, required this.title, required this.index, required this.route});
}

// Desktop Sidebar
class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final menuSections = [
      _MenuSection('MAIN', [
        _MenuTile(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, route: '/dashboard'),
      ]),
      _MenuSection('MANAGEMENT', [
        _MenuTile(icon: Icons.people_rounded, title: 'Students', index: 1, route: '/dashboard'),
        _MenuTile(icon: Icons.check_circle_rounded, title: 'Attendance', index: 2, route: '/dashboard'),
        _MenuTile(icon: Icons.assignment_rounded, title: 'Homework', index: 3, route: '/dashboard'),
      ]),
      _MenuSection('ACADEMICS', [
        _MenuTile(icon: Icons.analytics_rounded, title: 'Results', index: 4, route: '/reports'),
        _MenuTile(icon: Icons.payments_rounded, title: 'Fees', index: 5, route: '/admin'),
      ]),
      _MenuSection('SYSTEM', [
        _MenuTile(icon: Icons.admin_panel_settings_rounded, title: 'Admin Panel', index: 6, route: '/admin'),
        _MenuTile(icon: Icons.settings_rounded, title: 'Settings', index: 7, route: '/admin'),
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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('🏫', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEMPS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Teacher Assistant', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Menu
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

// Custom App Bar
class _CustomAppBar extends ConsumerWidget {
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  const _CustomAppBar({
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed,
            ),
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'NEMPS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              final current = ref.read(themeProvider);
              ref.read(themeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          // Profile
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              } else if (value == 'settings') {
                context.go('/admin');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// App Sidebar for desktop
class _AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const _AppSidebar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      const MenuItem(title: 'Dashboard', icon: Icons.dashboard_rounded, route: '/dashboard'),
      const MenuItem(title: 'Students', icon: Icons.people_rounded, route: '/dashboard'),
      const MenuItem(title: 'Attendance', icon: Icons.check_circle_rounded, route: '/dashboard'),
      const MenuItem(title: 'Homework', icon: Icons.assignment_rounded, route: '/dashboard'),
      const MenuItem(title: 'Results', icon: Icons.analytics_rounded, route: '/reports'),
      const MenuItem(title: 'Fees', icon: Icons.payments_rounded, route: '/admin'),
      const MenuItem(title: 'Admin', icon: Icons.admin_panel_settings_rounded, route: '/admin'),
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E40AF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      '🏫',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEMPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Teacher Assistant',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Menu Section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _SidebarSection(title: 'MAIN MENU'),
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0, '/dashboard'),
                ),
                _SidebarSection(title: 'MANAGEMENT'),
                _SidebarItem(
                  icon: Icons.people_rounded,
                  title: 'Students',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1, '/dashboard'),
                ),
                _SidebarItem(
                  icon: Icons.check_circle_rounded,
                  title: 'Attendance',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2, '/dashboard'),
                ),
                _SidebarItem(
                  icon: Icons.assignment_rounded,
                  title: 'Homework',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3, '/dashboard'),
                ),
                _SidebarSection(title: 'ACADEMICS'),
                _SidebarItem(
                  icon: Icons.analytics_rounded,
                  title: 'Results & Reports',
                  isSelected: selectedIndex == 4,
                  onTap: () => onItemSelected(4, '/reports'),
                ),
                _SidebarItem(
                  icon: Icons.payments_rounded,
                  title: 'Fees',
                  isSelected: selectedIndex == 5,
                  onTap: () => onItemSelected(5, '/admin'),
                ),
                _SidebarSection(title: 'SYSTEM'),
                _SidebarItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin Panel',
                  isSelected: selectedIndex == 6,
                  onTap: () => onItemSelected(6, '/admin'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Sidebar Section Header
class _SidebarSection extends StatelessWidget {
  final String title;

  const _SidebarSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// Sidebar Item
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.white.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Drawer for mobile
class _AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const _AppDrawer({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('🏫', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEMPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Teacher Assistant',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _SidebarSection(title: 'MAIN MENU'),
                    _DrawerItem(
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      isSelected: selectedIndex == 0,
                      onTap: () => onItemSelected(0, '/dashboard'),
                    ),
                    _SidebarSection(title: 'MANAGEMENT'),
                    _DrawerItem(
                      icon: Icons.people_rounded,
                      title: 'Students',
                      isSelected: selectedIndex == 1,
                      onTap: () => onItemSelected(1, '/dashboard'),
                    ),
                    _DrawerItem(
                      icon: Icons.check_circle_rounded,
                      title: 'Attendance',
                      isSelected: selectedIndex == 2,
                      onTap: () => onItemSelected(2, '/dashboard'),
                    ),
                    _DrawerItem(
                      icon: Icons.assignment_rounded,
                      title: 'Homework',
                      isSelected: selectedIndex == 3,
                      onTap: () => onItemSelected(3, '/dashboard'),
                    ),
                    _SidebarSection(title: 'ACADEMICS'),
                    _DrawerItem(
                      icon: Icons.analytics_rounded,
                      title: 'Results & Reports',
                      isSelected: selectedIndex == 4,
                      onTap: () => onItemSelected(4, '/reports'),
                    ),
                    _DrawerItem(
                      icon: Icons.payments_rounded,
                      title: 'Fees',
                      isSelected: selectedIndex == 5,
                      onTap: () => onItemSelected(5, '/admin'),
                    ),
                    _SidebarSection(title: 'SYSTEM'),
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Panel',
                      isSelected: selectedIndex == 6,
                      onTap: () => onItemSelected(6, '/admin'),
                    ),
                  ],
                ),
              ),
              // Logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Drawer Item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// Bottom Navigation Bar
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home', route: '/dashboard'),
      _NavItem(icon: Icons.people_rounded, label: 'Students', route: '/dashboard'),
      _NavItem(icon: Icons.check_circle_rounded, label: 'Attendance', route: '/dashboard'),
      _NavItem(icon: Icons.assignment_rounded, label: 'Homework', route: '/dashboard'),
      _NavItem(icon: Icons.more_horiz_rounded, label: 'More', route: '/admin'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onItemSelected(index, item.route),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
