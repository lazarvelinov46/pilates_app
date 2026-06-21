import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/package_model.dart';
import '../../services/auth_service.dart';
import '../../services/package_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});
  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  final UserService _userService = UserService();
  final PackageService _packageService = PackageService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String _assignerUid = '';
  String _assignerName = '';

  @override
  void initState() {
    super.initState();
    _loadAssignerInfo();
  }

  Future<void> _loadAssignerInfo() async {
    final appUser = await AuthService().getCurrentAppUser();
    if (appUser == null) return;
    setState(() {
      _assignerUid = appUser.uid;
      _assignerName = '${appUser.name} ${appUser.surname}'.trim();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _userService.searchUsersByEmail(query);
    setState(() { _searchResults = results; _searching = false; });
  }

  void _showAssignDialog(BuildContext ctx, Map<String, dynamic> user) async {
    final l10n = AppLocalizations.of(ctx);
    final packages = await _packageService.getPackages();
    if (!ctx.mounted) return;
    if (packages.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(l10n.noPackagesAvailable)));
      return;
    }
    Package? selectedPkg;
    DateTime? expiresAt;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setSt) {
          final dl10n = AppLocalizations.of(dCtx);
          return AlertDialog(
            title: Text(dl10n.assignPromotionTitle(
                '${user['name']} ${user['surname']}')),
            content: Form(
              key: formKey,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email'],
                        style: TextStyle(
                            color: AppTheme.textColor.withValues(alpha: 0.5),
                            fontSize: 12)),
                    const SizedBox(height: 16),
                    Text(dl10n.packageLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Package>(
                      value: selectedPkg,
                      hint: Text(dl10n.choosePackageHint),
                      isExpanded: true,
                      items: packages
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(dl10n.packageOption(
                                  p.name, p.numberOfSessions))))
                          .toList(),
                      onChanged: (p) => setSt(() => selectedPkg = p),
                      validator: (_) =>
                          selectedPkg == null ? dl10n.selectPackageError : null,
                    ),
                    const SizedBox(height: 16),
                    Text(dl10n.expiryDateLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(expiresAt == null
                          ? dl10n.pickExpiryDate
                          : DateFormat('dd MMM yyyy').format(expiresAt!)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dCtx,
                          initialDate:
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) setSt(() => expiresAt = picked);
                      },
                    ),
                    if (expiresAt == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(dl10n.expiryDateRequired,
                            style: TextStyle(
                                color: AppTheme.errorRed, fontSize: 12)),
                      ),
                  ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(dl10n.cancelButton)),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() ||
                      expiresAt == null) return;
                  await _userService.assignPromotionFromPackage(
                    userId: user['uid'],
                    package: selectedPkg!,
                    expiresAt: expiresAt!,
                    assignedByUid: _assignerUid,
                    assignedByName: _assignerName,
                    targetUserName: '${user['name']} ${user['surname']}',
                    targetUserEmail: user['email'],
                  );
                  if (dCtx.mounted) {
                    Navigator.pop(dCtx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                            l10n.promotionAssigned(user['email']))));
                  }
                },
                child: Text(dl10n.assignButton),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchByEmailHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      })
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _search,
          ),
        ),
        if (_searching)
          const Padding(
              padding: EdgeInsets.all(16), child: CircularProgressIndicator())
        else if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noUsersFound,
                style: TextStyle(
                    color: AppTheme.textColor.withValues(alpha: 0.45))),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              separatorBuilder: (context, i) => const Divider(),
              itemBuilder: (context, i) {
                final user = _searchResults[i];
                return ListTile(
                  leading: CircleAvatar(
                      child: Text((user['name'] as String).isNotEmpty
                          ? (user['name'] as String)[0].toUpperCase()
                          : '?')),
                  title: Text('${user['name']} ${user['surname']}'),
                  subtitle: Text(user['email']),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.assignButton),
                    onPressed: () => _showAssignDialog(context, user),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}
