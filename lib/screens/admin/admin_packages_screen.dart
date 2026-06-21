import 'package:flutter/material.dart';
import '../../models/package_model.dart';
import '../../services/package_service.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

class AdminPackagesScreen extends StatelessWidget {
  final bool canEdit;
  const AdminPackagesScreen({super.key, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = PackageService();
    return StreamBuilder<List<Package>>(
      stream: service.streamPackages(),
      builder: (context, snapshot) {
        final packages = snapshot.data ?? [];
        return Scaffold(
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : packages.isEmpty
                  ? Center(child: Text(l10n.noPackagesYet))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: packages.length,
                      separatorBuilder: (context, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final pkg = packages[i];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                          title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(l10n.nSessions(pkg.numberOfSessions)),
                          trailing: canEdit
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _showDialog(context, service, pkg),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppTheme.errorRed),
                                      onPressed: () => _confirmDelete(context, service, pkg),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      }),
          floatingActionButton: canEdit
              ? FloatingActionButton.extended(
                  onPressed: () => _showDialog(context, service, null),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newPackageButton),
                )
              : null,
        );
      },
    );
  }

  void _showDialog(BuildContext context, PackageService service, Package? existing) {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sessCtrl = TextEditingController(
        text: existing != null ? '${existing.numberOfSessions}' : '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? l10n.newPackageTitle : l10n.editPackageTitle),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.packageNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: sessCtrl,
              decoration: InputDecoration(labelText: l10n.numberOfSessionsLabel),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) <= 0 ? l10n.enterValidNumber : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (existing == null) {
                await service.createPackage(
                    name: nameCtrl.text.trim(),
                    numberOfSessions: int.parse(sessCtrl.text.trim()));
              } else {
                await service.updatePackage(
                    packageId: existing.id,
                    name: nameCtrl.text.trim(),
                    numberOfSessions: int.parse(sessCtrl.text.trim()));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(existing == null ? l10n.createButton : l10n.saveButton),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PackageService service, Package pkg) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deletePackageTitle),
        content: Text(l10n.deletePackageBody(pkg.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              await service.deletePackage(pkg.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.deleteButton,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
