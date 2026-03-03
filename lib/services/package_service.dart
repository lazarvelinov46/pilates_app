import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/package_model.dart';

class PackageService {
  final CollectionReference _col =
      FirebaseFirestore.instance.collection('packages');

  // ---------------- STREAM ALL ----------------

  Stream<List<Package>> streamPackages() {
    return _col.orderBy('name').snapshots().map(
      (snap) => snap.docs.map((d) => Package.fromFirestore(d)).toList(),
    );
  }

  // ---------------- FETCH ONE-TIME ----------------

  Future<List<Package>> getPackages() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs.map((d) => Package.fromFirestore(d)).toList();
  }

  // ---------------- CREATE ----------------

  Future<void> createPackage({
    required String name,
    required int numberOfSessions,
  }) async {
    await _col.add({'name': name, 'numberOfSessions': numberOfSessions});
  }

  // ---------------- UPDATE ----------------

  Future<void> updatePackage({
    required String packageId,
    required String name,
    required int numberOfSessions,
  }) async {
    await _col.doc(packageId).update({'name': name, 'numberOfSessions': numberOfSessions});
  }

  // ---------------- DELETE ----------------

  Future<void> deletePackage(String packageId) async {
    await _col.doc(packageId).delete();
  }
}