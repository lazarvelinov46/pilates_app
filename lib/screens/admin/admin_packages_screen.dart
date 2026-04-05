import 'package:flutter/material.dart';
import '../../models/package_model.dart';
import '../../services/package_service.dart';
import '../../theme.dart';

class AdminPackagesScreen extends StatelessWidget {
  const AdminPackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PackageService();
    return StreamBuilder<List<Package>>(
      stream: service.streamPackages(),
      builder: (context, snapshot) {
        final packages = snapshot.data ?? [];
        return Scaffold(
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : packages.isEmpty
                  ? const Center(child: Text('No packages yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: packages.length,
                      separatorBuilder: (context, i) => const Divider(),
                      itemBuilder: (context, i) {
                        final pkg = packages[i];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                          title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${pkg.numberOfSessions} sessions'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showDialog(context, service, pkg)),
                              IconButton(icon: Icon(Icons.delete_outline, color: AppTheme.errorRed), onPressed: () => _confirmDelete(context, service, pkg)),
                            ],
                          ),
                        );
                      }),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showDialog(context, service, null),
            icon: const Icon(Icons.add),
            label: const Text('New Package'),
          ),
        );
      },
    );
  }

  void _showDialog(BuildContext context, PackageService service, Package? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sessCtrl = TextEditingController(text: existing != null ? '${existing.numberOfSessions}' : '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New Package' : 'Edit Package'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Package Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: sessCtrl, decoration: const InputDecoration(labelText: 'Number of Sessions'), keyboardType: TextInputType.number, validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid number' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (existing == null) {
                await service.createPackage(name: nameCtrl.text.trim(), numberOfSessions: int.parse(sessCtrl.text.trim()));
              } else {
                await service.updatePackage(packageId: existing.id, name: nameCtrl.text.trim(), numberOfSessions: int.parse(sessCtrl.text.trim()));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PackageService service, Package pkg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Delete "${pkg.name}"? Existing promotions using this package are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              await service.deletePackage(pkg.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}