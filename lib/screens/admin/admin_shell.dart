import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'admin_packages_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_ratings_screen.dart';
import 'admin_session_screen.dart';
import 'owner_assignments_screen.dart';

class AdminShell extends StatefulWidget {
  final UserRole role;
  const AdminShell({super.key, required this.role});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      AdminPackagesScreen(canEdit: widget.role == UserRole.owner),
      const AdminPromotionsScreen(),
      const AdminSessionsScreen(),
      const AdminRatingsScreen(),
      if (widget.role == UserRole.owner) const OwnerAssignmentsScreen(),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    MyApp.localeNotifier.value = const Locale('en');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(authService: AuthService())),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOwner = widget.role == UserRole.owner;

    final navItems = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.inventory_2_outlined),
        activeIcon: const Icon(Icons.inventory_2),
        label: l10n.navPackages,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.card_giftcard_outlined),
        activeIcon: const Icon(Icons.card_giftcard),
        label: l10n.navPromotions,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_month_outlined),
        activeIcon: const Icon(Icons.calendar_month),
        label: l10n.navSessions,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.star_outline),
        activeIcon: const Icon(Icons.star),
        label: l10n.navRatings,
      ),
      if (isOwner)
        BottomNavigationBarItem(
          icon: const Icon(Icons.assignment_outlined),
          activeIcon: const Icon(Icons.assignment),
          label: l10n.navAssignments,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? l10n.ownerPanelTitle : l10n.adminPanelTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutButton,
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: navItems,
      ),
    );
  }
}
