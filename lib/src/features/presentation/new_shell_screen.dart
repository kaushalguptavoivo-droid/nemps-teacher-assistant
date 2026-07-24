import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/providers.dart';

// Navigation index provider
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

// Menu item model
class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final String? badge;

  const MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.badge,
  });
}

class NewShellScreen extends ConsumerWidget {
  const NewShellScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      drawer: isWideScreen ? null : _AppDrawer(
        selectedIndex: selectedIndex,
        onItemSelected: (index, route) {
          ref.read(selectedNavIndexProvider.notifier).state = index;
          context.go(route);
          Navigator.pop(context);
        },
      ),
      body: Row(
        children: [
          // Sidebar for wide screens
          if (isWideScreen)
            _AppSidebar(
              selectedIndex: selectedIndex,
              onItemSelected: (index, route) {
                ref.read(selectedNavIndexProvider.notifier).state = index;
                context.go(route);
              },
            ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Custom App Bar
                _CustomAppBar(
                  showMenuButton: !isWideScreen,
                  onMenuPressed: () => Scaffold.of(context).openDrawer(),
                ),
                // Content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation for mobile
      bottomNavigationBar: isWideScreen
          ? null
          : _BottomNavBar(
              selectedIndex: selectedIndex,
              onItemSelected: (index, route) {
                ref.read(selectedNavIndexProvider.notifier).state = index;
                context.go(route);
              },
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
