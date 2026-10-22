import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact.dart';

/// كل البيانات تحت users/{uid}/contacts وقواعد Firestore بتمنع أي حد غيرك.
class ContactsRepo {
  ContactsRepo(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('contacts');

  Stream<List<Contact>> watch() => _col
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Contact.fromDoc).toList());

  Future<List<Contact>> fetchAll() async =>
      (await _col.get()).docs.map(Contact.fromDoc).toList();

  Future<void> save(Contact c) async {
    if (c.id.isEmpty) {
      await _col.add(c.toMap());
    } else {
      await _col.doc(c.id).update(c.toMap());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> deleteMany(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in list.skip(i).take(400)) {
        batch.delete(_col.doc(id));
      }
      await batch.commit();
    }
  }

  Future<void> addMany(List<Contact> items) async {
    for (var i = 0; i < items.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final c in items.skip(i).take(400)) {
        batch.set(_col.doc(), c.toMap());
      }
      await batch.commit();
    }
  }
}
