import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
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
  late final List<BottomNavigationBarItem> _navItems;

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
    _navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined),
        activeIcon: Icon(Icons.inventory_2),
        label: 'Packages',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.card_giftcard_outlined),
        activeIcon: Icon(Icons.card_giftcard),
        label: 'Promotions',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        activeIcon: Icon(Icons.calendar_month),
        label: 'Sessions',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.star_outline),
        activeIcon: Icon(Icons.star),
        label: 'Ratings',
      ),
      if (widget.role == UserRole.owner)
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'Assignments',
        ),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(authService: AuthService())),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == UserRole.owner ? 'Owner Panel' : 'Admin Panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems,
      ),
    );
  }
}
