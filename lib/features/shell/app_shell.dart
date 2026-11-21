import 'package:flutter/material.dart';

import '../authentication/session_controller.dart';
import '../collection/collect_page.dart';
import '../home/home_page.dart';
import '../market/listings_page.dart';
import '../market/market_page.dart';
import '../market/orders_page.dart';
import '../profile/profile_page.dart';
import '../rewards/rewards_page.dart';
import '../vendor/vendor_dashboard_page.dart';
import '../vendor/vendor_requests_page.dart';

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.title,
  });

  final String label;
  final String? title; // app bar title, defaults to label
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() page;
}

/// The signed-in app: an app bar, the current tab, and a bottom navigation
/// bar. A vendor can flip between the customer tabs and the vendor tabs
/// from the Profile screen.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool? _lastVendorMode;

  void _go(int index) => setState(() => _index = index);

  List<_TabSpec> _userTabs() => [
        _TabSpec(
          label: 'Home',
          title: 'GreenSync',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: () => HomePage(onOpenTab: _go),
        ),
        _TabSpec(
          label: 'Collect',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          page: () => const CollectPage(),
        ),
        _TabSpec(
          label: 'Market',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          page: () => const MarketPage(),
        ),
        _TabSpec(
          label: 'Rewards',
          icon: Icons.card_giftcard_outlined,
          selectedIcon: Icons.card_giftcard,
          page: () => const RewardsPage(),
        ),
        _TabSpec(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          page: () => const ProfilePage(),
        ),
      ];

  List<_TabSpec> _vendorTabs() => [
        _TabSpec(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          page: () => const VendorDashboardPage(),
        ),
        _TabSpec(
          label: 'Requests',
          icon: Icons.inbox_outlined,
          selectedIcon: Icons.inbox,
          page: () => const VendorRequestsPage(),
        ),
        _TabSpec(
          label: 'Orders',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          page: () => const OrdersPage(asSeller: true, embedded: true),
        ),
        _TabSpec(
          label: 'Listings',
          icon: Icons.sell_outlined,
          selectedIcon: Icons.sell,
          page: () => const ListingsPage(embedded: true),
        ),
        _TabSpec(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          page: () => const ProfilePage(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final vendorMode = SessionScope.of(context).viewAsVendor;

    // Switching between customer and vendor view starts on the first tab.
    if (_lastVendorMode != vendorMode) {
      _lastVendorMode = vendorMode;
      _index = 0;
    }

    final tabs = vendorMode ? _vendorTabs() : _userTabs();
    final current = tabs[_index];

    return Scaffold(
      appBar: AppBar(title: Text(current.title ?? current.label)),
      body: current.page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
