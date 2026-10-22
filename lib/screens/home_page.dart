import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts_repo.dart';
import '../services/incoming_file.dart';
import '../services/vcf.dart';
import 'edit_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ContactsRepo _repo;
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo = ContactsRepo(FirebaseAuth.instance.currentUser!.uid);
    IncomingFile.path.addListener(_checkIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIncoming());
  }

  @override
  void dispose() {
    IncomingFile.path.removeListener(_checkIncoming);
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _checkIncoming() async {
    final p = IncomingFile.path.value;
    if (p == null) return;
    IncomingFile.path.value = null;
    try {
      final text = decodeFileBytes(await File(p).readAsBytes());
      await _importText(text);
    } catch (e) {
      _snack('مقدرتش أقرأ الملف: $e');
    }
  }

  Future<void> _pickAndImport() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.any, allowMultiple: true, withData: true);
    if (res == null) return;
    final sb = StringBuffer();
    for (final f in res.files) {
      final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes != null) sb.writeln(decodeFileBytes(bytes));
    }
    await _importText(sb.toString());
  }

  Future<void> _importText(String text) async {
    final parsed = parseVcf(text);
    if (parsed.isEmpty) {
      _snack('الملف مفيهوش جهات اتصال VCF صالحة');
      return;
    }
    final existing = await _repo.fetchAll();
    final known = existing
        .expand((c) => c.phones.map(phoneKey))
        .where((k) => k.isNotEmpty)
        .toSet();
    final fresh = <Contact>[];
    for (final c in parsed) {
      final keys = c.phones.map(phoneKey).where((k) => k.isNotEmpty).toList();
      if (keys.isNotEmpty && keys.every(known.contains)) continue; // مكرر
      known.addAll(keys);
      fresh.add(c);
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استيراد جهات الاتصال'),
        content: Text(
            'لقيت ${parsed.length} جهة في الملف.\n'
            'الجديدة: ${fresh.length}\n'
            'المكررة (هتتخطى): ${parsed.length - fresh.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: fresh.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('استيراد')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.addMany(fresh);
      _snack('اتضاف ${fresh.length} جهة اتصال');
    } catch (e) {
      _snack('فشل الاستيراد: $e');
    }
  }

  Future<void> _export(List<Contact> list) async {
    if (list.isEmpty) {
      _snack('مفيش جهات للتصدير');
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(toVcf(list)));
    try {
      var path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف VCF',
        fileName: 'contacts.vcf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['vcf'],
      );
      if (path == null) return;
      if (!Platform.isAndroid) {
        if (!path.toLowerCase().endsWith('.vcf')) path = '$path.vcf';
        await File(path).writeAsBytes(bytes);
      }
      _snack('اتصدّر ${list.length} جهة اتصال');
    } catch (e) {
      _snack('فشل التصدير: $e');
    }
  }

  Future<void> _deleteSelected() async {
    final ok = await _confirm(
        'حذف ${_selected.length} جهة؟', 'الحذف نهائي. يفضل تصدّر نسخة احتياطية الأول.');
    if (ok != true) return;
    await _repo.deleteMany(_selected);
    setState(_selected.clear);
  }

  Future<void> _deleteAll(List<Contact> all) async {
    final ok = await _confirm('حذف كل جهات الاتصال (${all.length})؟',
        'العملية دي نهائية ومش هينفع ترجّعها. صدّر نسخة احتياطية الأول.');
    if (ok != true) return;
    await _repo.deleteMany(all.map((c) => c.id));
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: _repo.watch(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final shown = all.where((c) => c.matches(_query)).toList();
        final selecting = _selected.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            leading: selecting
                ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_selected.clear))
                : null,
            title: Text(selecting ? '${_selected.length} محدد' : 'جهات الاتصال (${all.length})'),
            actions: selecting
                ? [
                    IconButton(
                        tooltip: 'تحديد الكل',
                        icon: const Icon(Icons.select_all),
                        onPressed: () => setState(() => _selected.addAll(shown.map((c) => c.id)))),
                    IconButton(
                        tooltip: 'تصدير المحدد',
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => _export(all.where((c) => _selected.contains(c.id)).toList())),
                    IconButton(
                        tooltip: 'حذف المحدد',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _deleteSelected),
                  ]
                : [
                    IconButton(
                        tooltip: 'استيراد VCF',
                        icon: const Icon(Icons.download),
                        onPressed: _pickAndImport),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'export') _export(all);
                        if (v == 'deleteAll') _deleteAll(all);
                        if (v == 'logout') await FirebaseAuth.instance.signOut();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'export', child: Text('تصدير الكل VCF')),
                        PopupMenuItem(value: 'deleteAll', child: Text('حذف الكل')),
                        PopupMenuItem(value: 'logout', child: Text('تسجيل خروج')),
                      ],
                    ),
                  ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => EditPage(repo: _repo))),
            child: const Icon(Icons.person_add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الرقم',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _query = '';
                                })),
                  ),
                ),
              ),
              if (snap.hasError)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('خطأ: ${snap.error}', style: const TextStyle(color: Colors.redAccent))),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting && all.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : shown.isEmpty
                        ? Center(child: Text(all.isEmpty ? 'مفيش جهات اتصال. استورد ملف VCF أو أضف جهة.' : 'مفيش نتائج'))
                        : ListView.builder(
                            itemCount: shown.length,
                            itemBuilder: (_, i) {
                              final c = shown[i];
                              final sel = _selected.contains(c.id);
                              return ListTile(
                                selected: sel,
                                leading: CircleAvatar(
                                  child: sel
                                      ? const Icon(Icons.check)
                                      : Text(c.name.isEmpty ? '?' : c.name.characters.first),
                                ),
                                title: Text(c.name),
                                subtitle: c.phones.isEmpty ? null : Text(c.phones.join('  •  ')),
                                onLongPress: () => setState(() => sel ? _selected.remove(c.id) : _selected.add(c.id)),
                                onTap: () {
                                  if (selecting) {
                                    setState(() => sel ? _selected.remove(c.id) : _selected.add(c.id));
                                  } else {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => EditPage(repo: _repo, contact: c)));
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
