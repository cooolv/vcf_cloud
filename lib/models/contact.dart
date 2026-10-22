import 'package:cloud_firestore/cloud_firestore.dart';

/// آخر 9 أرقام عشان +20100... و0100... يتعاملوا كنفس الرقم
String phoneKey(String p) {
  final d = p.replaceAll(RegExp(r'[^\d]'), '');
  return d.length > 9 ? d.substring(d.length - 9) : d;
}

/// توحيد النص العربي للبحث (تشكيل، ألف، ياء، تاء مربوطة)
String normalizeText(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}

class Contact {
  Contact({
    this.id = '',
    required this.name,
    List<String>? phones,
    List<String>? emails,
    this.org = '',
    this.note = '',
  })  : phones = phones ?? [],
        emails = emails ?? [];

  String id;
  String name;
  List<String> phones;
  List<String> emails;
  String org;
  String note;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phones': phones,
        'emails': emails,
        'org': org,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Contact.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Contact(
      id: d.id,
      name: (m['name'] ?? '') as String,
      phones: List<String>.from(m['phones'] ?? const []),
      emails: List<String>.from(m['emails'] ?? const []),
      org: (m['org'] ?? '') as String,
      note: (m['note'] ?? '') as String,
    );
  }

  bool matches(String query) {
    final q = normalizeText(query);
    if (q.isEmpty) return true;
    if (normalizeText(name).contains(q)) return true;
    final qNum = query.replaceAll(RegExp(r'[^\d]'), '');
    if (qNum.isNotEmpty) {
      return phones.any((p) => p.replaceAll(RegExp(r'[^\d]'), '').contains(qNum));
    }
    return false;
  }
}
