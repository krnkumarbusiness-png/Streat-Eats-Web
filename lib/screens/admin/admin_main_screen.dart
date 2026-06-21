// lib/screens/admin/admin_main_screen.dart
// v4.0 — Analytics Hub button added in AppBar
// ✅ Orders, Vendors, Menu, Customers in bottom nav
// ✅ More sheet: Riders, Categories, Sweets, Day Off
// ✅ Analytics Hub → AppBar icon button (bar_chart)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import 'admin_orders_screen.dart';
import 'admin_vendors_screen.dart';
import 'admin_menu_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_riders_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_banner_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_offers_screen.dart';
import '../login_screen.dart';
import 'admin_affiliate_ledger_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_day_off_screen.dart';
import 'admin_analytics_hub_screen.dart'; // ✅ NAYA
import 'admin_combos_screen.dart';
import 'admin_creators_screen.dart'; // ✅ NAYA

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  bool _isLoggingOut = false;

  final List<Widget> _pages = const [
    AdminOrdersScreen(),
    AdminVendorsScreen(),
    AdminMenuScreen(),
    AdminCustomersScreen(),
    AdminRidersScreen(),
    AdminCategoriesScreen(),
    AdminDayOffScreen(),
  ];

  final List<String> _titles = const [
    'Orders',
    'Vendors',
    'Menu',
    'Customers',
    'Riders',
    'Categories',
    'Day Off',
  ];

  static const _kBottomItems = [
    _NavDef(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
      idx: 0,
    ),
    _NavDef(
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      label: 'Vendors',
      idx: 1,
    ),
    _NavDef(
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu,
      label: 'Menu',
      idx: 2,
    ),
    _NavDef(
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      label: 'Customers',
      idx: 3,
    ),
  ];

  static const _kMoreItems = [
    _NavDef(
      icon: Icons.two_wheeler_outlined,
      activeIcon: Icons.two_wheeler,
      label: 'Riders',
      idx: 4,
    ),
    _NavDef(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Categories',
      idx: 5,
    ),
    _NavDef(
      icon: Icons.event_busy_outlined,
      activeIcon: Icons.event_busy_rounded,
      label: 'Day Off',
      idx: 6,
    ),
  ];

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Analytics Hub → push (not IndexedStack) ───────────
  void _openAnalyticsHub() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAnalyticsHubScreen()),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'More',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: _kMoreItems.map((item) {
                    final isActive = _currentIndex == item.idx;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = item.idx);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary.withOpacity(0.35)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 26,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to logout from the admin panel?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Logout failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Widget _appBarBtn({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final c = color ?? AppColors.primary;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.withOpacity(0.15)),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isMoreActive = _currentIndex > 3;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              // 4 main tabs
              ..._kBottomItems.map((item) {
                final isSelected = _currentIndex == item.idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = item.idx),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Poppins',
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // "More" — 5th button
              Expanded(
                child: GestureDetector(
                  onTap: _showMoreSheet,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isMoreActive
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMoreActive
                              ? _kMoreItems
                                    .firstWhere(
                                      (m) => m.idx == _currentIndex,
                                      orElse: () => _kMoreItems[0],
                                    )
                                    .activeIcon
                              : Icons.more_horiz_rounded,
                          color: isMoreActive
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMoreActive ? _titles[_currentIndex] : 'More',
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'Poppins',
                            fontWeight: isMoreActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isMoreActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Admin — ${_titles[_currentIndex]}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          _appBarBtn(
            icon: Icons.notifications_rounded,
            tooltip: 'Notifications',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminNotificationsScreen(),
              ),
            ),
          ),
          _appBarBtn(
            icon: Icons.local_offer_rounded,
            tooltip: 'Offers',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminOffersScreen()),
            ),
          ),
          _appBarBtn(
            icon: Icons.people_alt_rounded,
            tooltip: 'Affiliates',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAffiliateLedgerScreen(),
              ),
            ),
          ),
          _appBarBtn(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
            ),
          ),
          _appBarBtn(
            icon: Icons.campaign_rounded,
            tooltip: 'Banners',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminBannerScreen()),
            ),
          ),

          // ✅ NAYA — Analytics Hub button
          _appBarBtn(
            icon: Icons.bar_chart_rounded,
            tooltip: 'Analytics Hub',
            onTap: _openAnalyticsHub,
          ),
          _appBarBtn(
            icon: Icons.people_alt_rounded,
            tooltip: 'Creators',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCreatorsScreen()),
            ),
          ),
          _appBarBtn(
            icon: Icons.card_giftcard_rounded,
            tooltip: 'Combos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCombosScreen()),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _appBarBtn(
                    icon: Icons.logout_rounded,
                    color: AppColors.error,
                    tooltip: 'Logout',
                    onTap: _confirmLogout,
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class _NavDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int idx;
  const _NavDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
  });
}
