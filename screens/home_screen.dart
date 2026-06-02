import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'my_company_screen.dart';
import 'settings_screen.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    SearchScreen(),
    MyCompanyScreen(),
    SettingsScreen(),
  ];

  final List<NavigationItem> _items = [
    NavigationItem(icon: Icons.search, activeIcon: Icons.search, label: 'Suche'),
    NavigationItem(icon: Icons.business_outlined, activeIcon: Icons.business, label: 'Mein Unternehmen'),
    NavigationItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Einstellungen'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
        animationDuration: const Duration(milliseconds: 400),
        elevation: 3,
        shadowColor: Colors.black26,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        destinations: _items.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon),
          label: item.label,
        )).toList(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: true,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onItemTapped,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  'ServicePlace',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          destinations: _items.map((item) => NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          )).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _screens[_currentIndex]),
      ]),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: true,
          minExtendedWidth: 220,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onItemTapped,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'ServicePlace',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          destinations: _items.map((item) => NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          )).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _screens[_currentIndex]),
      ]),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  NavigationItem({required this.icon, required this.activeIcon, required this.label});
}
