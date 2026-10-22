import 'dart:convert';
import '../models/contact.dart';

/// فك الأسطر المطوية + أسطر Quoted-Printable المكسورة
List<String> _logicalLines(String text) {
  final raw = text.split(RegExp(r'\r\n|\r|\n'));
  final out = <String>[];
  for (var i = 0; i < raw.length; i++) {
    var line = raw[i];
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] += line.substring(1);
      continue;
    }
    while (line.toUpperCase().contains('QUOTED-PRINTABLE') &&
        line.endsWith('=') &&
        i + 1 < raw.length) {
      line = line.substring(0, line.length - 1) + raw[++i];
    }
    out.add(line);
  }
  return out;
}

String _decodeQP(String s) {
  final bytes = <int>[];
  final hex = RegExp(r'^[0-9A-Fa-f]{2}$');
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '=' && i + 3 <= s.length && hex.hasMatch(s.substring(i + 1, i + 3))) {
      bytes.add(int.parse(s.substring(i + 1, i + 3), radix: 16));
      i += 2;
    } else {
      bytes.addAll(utf8.encode(s[i]));
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _unescape(String v) => v
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');

String _escape(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll('\n', r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

String decodeFileBytes(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  return text;
}

List<Contact> parseVcf(String text) {
  final result = <Contact>[];
  var inCard = false;
  String fn = '', n = '', org = '', note = '';
  var phones = <String>[], emails = <String>[];

  for (final line in _logicalLines(text)) {
    final upper = line.trim().toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      inCard = true;
      fn = n = org = note = '';
      phones = [];
      emails = [];
      continue;
    }
    if (upper == 'END:VCARD') {
      if (inCard) {
        final name = fn.isNotEmpty ? fn : n;
        if (name.isNotEmpty || phones.isNotEmpty) {
          result.add(Contact(
              name: name.isNotEmpty ? name : phones.first,
              phones: phones,
              emails: emails,
              org: org,
              note: note));
        }
      }
      inCard = false;
      continue;
    }
    if (!inCard) continue;

    final i = line.indexOf(':');
    if (i < 0) continue;
    final keyFull = line.substring(0, i).toUpperCase();
    var value = line.substring(i + 1);
    var key = keyFull.split(';').first;
    if (key.contains('.')) key = key.split('.').last; // item1.TEL
    if (keyFull.contains('QUOTED-PRINTABLE')) {
      value = _decodeQP(value);
    } else {
      value = _unescape(value);
    }
    value = value.trim();

    switch (key) {
      case 'FN':
        fn = value;
        break;
      case 'N':
        final p = value.split(';');
        String at(int k) => k < p.length ? p[k].trim() : '';
        n = [at(3), at(1), at(2), at(0), at(4)].where((e) => e.isNotEmpty).join(' ');
        break;
      case 'TEL':
        if (value.isNotEmpty) phones.add(value);
        break;
      case 'EMAIL':
        if (value.isNotEmpty) emails.add(value);
        break;
      case 'ORG':
        org = value.split(';').where((e) => e.isNotEmpty).join(' ');
        break;
      case 'NOTE':
        note = value;
        break;
    }
  }
  return result;
}

String toVcf(List<Contact> list) {
  final b = StringBuffer();
  for (final c in list) {
    b.write('BEGIN:VCARD\r\nVERSION:3.0\r\n');
    b.write('FN:${_escape(c.name)}\r\n');
    b.write('N:;${_escape(c.name)};;;\r\n');
    for (final p in c.phones) {
      b.write('TEL;TYPE=CELL:$p\r\n');
    }
    for (final e in c.emails) {
      b.write('EMAIL:$e\r\n');
    }
    if (c.org.isNotEmpty) b.write('ORG:${_escape(c.org)}\r\n');
    if (c.note.isNotEmpty) b.write('NOTE:${_escape(c.note)}\r\n');
    b.write('END:VCARD\r\n');
  }
  return b.toString();
}
