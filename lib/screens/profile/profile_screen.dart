import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../models/promotion_model.dart';
import '../../models/user_preferences_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart' show AuthService, ReauthCancelledException;
import '../../theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
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
    final l10n = AppLocalizations.of(context);
    try {
      await _authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.passwordResetEmailSent(email)),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorMsg(e.toString().replaceFirst('Exception: ', ''))),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(String email) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changePasswordTitle),
        content: Text(l10n.changePasswordEmailPrompt(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendPasswordReset(email);
            },
            child: Text(l10n.sendLinkButton),
          ),
        ],
      ),
    );
  }

  // ── Preferences ────────────────────────────────────────────────────────────
  void _showPreferencesSheet(UserPreferences current) {
    bool notifications = current.notifications;
    String language = current.language;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final l10n = AppLocalizations.of(ctx);
          return Padding(
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
                      l10n.preferencesTitle,
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
                  title: Text(l10n.pushNotificationsLabel),
                  subtitle: Text(l10n.pushNotificationsSubtitle),
                  value: notifications,
                  onChanged: (val) => setSt(() => notifications = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                // Language selector
                Row(
                  children: [
                    Icon(Icons.language,
                        color: Theme.of(ctx).colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.languageLabel,
                            style: Theme.of(ctx).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'en',
                                label: Text(l10n.languageEnglish),
                              ),
                              ButtonSegment(
                                value: 'sr',
                                label: Text(l10n.languageSerbian),
                              ),
                            ],
                            selected: {language},
                            onSelectionChanged: (val) =>
                                setSt(() => language = val.first),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updated = UserPreferences(
                        language: language,
                        notifications: notifications,
                      );
                      await _userService.updatePreferences(userId, updated);
                      // Apply new locale immediately.
                      MyApp.localeNotifier.value = Locale(language);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context).preferencesSaved)),
                        );
                      }
                    },
                    child: Text(l10n.saveButton),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Promotion History ──────────────────────────────────────────────────────
  void _showPromotionHistory(List<Promotion> history) {
    final l10n = AppLocalizations.of(context);
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
                    l10n.promotionHistoryTitle,
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
                              color: AppTheme.textColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(l10n.noPastPromotions,
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

  // ── Delete Account ─────────────────────────────────────────────────────────

  bool _isGoogleUser() {
    return FirebaseAuth.instance.currentUser?.providerData
            .any((p) => p.providerId == 'google.com') ??
        false;
  }

  Future<void> _performDeleteAccount({String? password}) async {
    try {
      await _authService.deleteAccount(password: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: _authService),
        ),
        (_) => false,
      );
    } on ReauthCancelledException {
      // User cancelled Google sign-in — do nothing.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context).errorMsg(e.toString().replaceFirst('Exception: ', ''))),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final l10n = AppLocalizations.of(context);
    final isGoogle = _isGoogleUser();

    if (isGoogle) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteAccountTitle),
          content: Text(l10n.deleteAccountGoogleBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
              child: Text(l10n.deleteAccountTitle),
            ),
          ],
        ),
      );
      if (confirmed == true) await _performDeleteAccount();
      return;
    }

    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(l10n.deleteAccountTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteAccountPasswordBody),
              const SizedBox(height: 16),
              Text(l10n.enterPasswordToConfirm,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.passwordHint,
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setSt(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
              child: Text(l10n.deleteAccountTitle),
            ),
          ],
        ),
      ),
    );

    final password = passwordController.text;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => passwordController.dispose());

    if (confirmed == true) {
      await _performDeleteAccount(password: password);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutButton),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: Text(l10n.logoutButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      // Reset locale to default on logout.
      MyApp.localeNotifier.value = const Locale('en');
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutButton,
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
            return Center(child: Text(l10n.unableToLoadProfile));
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
              _SectionHeader(title: l10n.accountSection),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.lock_outline,
                title: l10n.changePasswordTitle,
                subtitle: l10n.changePasswordSubtitle,
                onTap: () => _showChangePasswordDialog(user.email),
              ),

              _ProfileTile(
                icon: Icons.tune_outlined,
                title: l10n.preferencesTitle,
                subtitle: user.preferences.notifications
                    ? l10n.notificationsOn
                    : l10n.notificationsOff,
                onTap: () => _showPreferencesSheet(user.preferences),
              ),

              _ProfileTile(
                icon: Icons.delete_forever_outlined,
                title: l10n.deleteAccountTitle,
                subtitle: l10n.deleteAccountSubtitle,
                onTap: _showDeleteAccountDialog,
                isDestructive: true,
              ),

              const SizedBox(height: 24),

              // ── History Section ────────────────────────────────────────
              _SectionHeader(title: l10n.promotionsSection),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.history,
                title: l10n.promotionHistoryTitle,
                subtitle: user.promotionHistory.isEmpty
                    ? l10n.noPastPromotions
                    : l10n.pastPromotionsCount(user.promotionHistory.length),
                onTap: () => _showPromotionHistory(user.promotionHistory),
              ),

              const SizedBox(height: 24),

              // ── Legal Section ──────────────────────────────────────────
              _SectionHeader(title: l10n.legalSection),
              const SizedBox(height: 8),

              _ProfileTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                subtitle: l10n.privacyPolicySubtitle,
                onTap: () => launchUrl(
                  Uri.parse('https://pilates-studio-da2a9.web.app/privacy-policy.html'),
                  mode: LaunchMode.externalApplication,
                ),
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
  final bool isDestructive;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.errorRed : AppTheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDestructive ? AppTheme.errorRed : null)),
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
    final l10n = AppLocalizations.of(context);
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
                '${l10n.expiredOn} ${DateFormat('dd MMM yy').format(promotion.expiresAt)}',
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
            l10n.promotionStats(
                promotion.attended,
                promotion.booked,
                promotion.remaining,
                used,
                promotion.totalSessions),
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.textColor.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
