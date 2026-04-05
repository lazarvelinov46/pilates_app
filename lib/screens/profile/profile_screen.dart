import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/promotion_model.dart';
import '../../models/user_preferences_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  // ── Change Password ────────────────────────────────────────────────────────
  Future<void> _sendPasswordReset(String email) async {
    try {
      await _authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Text(
          'A password reset link will be sent to:\n\n$email',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendPasswordReset(email);
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
  }

  // ── Preferences ────────────────────────────────────────────────────────────
  void _showPreferencesSheet(UserPreferences current) {
    bool notifications = current.notifications;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Preferences',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Push notifications'),
                subtitle: const Text(
                    'Receive reminders before your sessions'),
                value: notifications,
                onChanged: (val) => setSt(() => notifications = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final updated = UserPreferences(
                      language: current.language,
                      notifications: notifications,
                    );
                    await _userService.updatePreferences(userId, updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preferences saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Promotion History ──────────────────────────────────────────────────────
  void _showPromotionHistory(List<Promotion> history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Promotion History',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history,
                              size: 48,
                              color: AppTheme.textColor
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('No past promotions',
                              style: TextStyle(
                                  color: AppTheme.textColor
                                      .withValues(alpha: 0.45))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: history.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = history[history.length - 1 - i];
                        return _PromotionHistoryTile(promotion: p);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: _authService),
        ),
        (_) => false,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<AppUser>(
        stream: _userService.getUserStream(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snap.data;
          if (user == null) {
            return const Center(child: Text('Unable to load profile'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Avatar + Name ──────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '${user.name.isNotEmpty ? user.name[0] : ''}${user.surname.isNotEmpty ? user.surname[0] : ''}'
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${user.name} ${user.surname}',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: AppTheme.textColor
                                  .withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Account Section ────────────────────────────────────────
              _SectionHeader(title: 'Account'),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Send a reset link to your email',
                onTap: () => _showChangePasswordDialog(user.email),
              ),

              _ProfileTile(
                icon: Icons.tune_outlined,
                title: 'Preferences',
                subtitle: user.preferences.notifications
                    ? 'Notifications: on'
                    : 'Notifications: off',
                onTap: () => _showPreferencesSheet(user.preferences),
              ),

              const SizedBox(height: 24),

              // ── History Section ────────────────────────────────────────
              _SectionHeader(title: 'Promotions'),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.history,
                title: 'Promotion History',
                subtitle: user.promotionHistory.isEmpty
                    ? 'No past promotions'
                    : '${user.promotionHistory.length} past promotion${user.promotionHistory.length == 1 ? '' : 's'}',
                onTap: () => _showPromotionHistory(user.promotionHistory),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textColor.withValues(alpha: 0.45),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: TextStyle(
                    color: AppTheme.textColor.withValues(alpha: 0.55),
                    fontSize: 13))
            : null,
        trailing: Icon(Icons.chevron_right,
            color: AppTheme.textColor.withValues(alpha: 0.35)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PromotionHistoryTile extends StatelessWidget {
  final Promotion promotion;
  const _PromotionHistoryTile({required this.promotion});

  @override
  Widget build(BuildContext context) {
    final used = promotion.attended + promotion.booked;
    final fillPercent =
        promotion.totalSessions > 0 ? used / promotion.totalSessions : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.packageName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Expired ${DateFormat('dd MMM yy').format(promotion.expiresAt)}',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColor.withValues(alpha: 0.45)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPercent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.outlineVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.historySlate),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${promotion.attended} attended · ${promotion.booked} booked · ${promotion.remaining} unused  |  $used / ${promotion.totalSessions} total',
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.textColor.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
