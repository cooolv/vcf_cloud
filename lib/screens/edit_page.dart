import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contacts_repo.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.repo, this.contact});
  final ContactsRepo repo;
  final Contact? contact;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final TextEditingController _name, _org, _note;
  late final List<TextEditingController> _phones, _emails;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _name = TextEditingController(text: c?.name ?? '');
    _org = TextEditingController(text: c?.org ?? '');
    _note = TextEditingController(text: c?.note ?? '');
    _phones = (c?.phones.isNotEmpty ?? false ? c!.phones : ['']).map((e) => TextEditingController(text: e)).toList();
    _emails = (c?.emails.isNotEmpty ?? false ? c!.emails : ['']).map((e) => TextEditingController(text: e)).toList();
  }

  List<String> _clean(List<TextEditingController> l) =>
      l.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    final phones = _clean(_phones);
    if (_name.text.trim().isEmpty && phones.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب اسم أو رقم على الأقل')));
      return;
    }
    setState(() => _saving = true);
    final c = widget.contact ?? Contact(name: '');
    c.name = _name.text.trim().isNotEmpty ? _name.text.trim() : phones.first;
    c.phones = phones;
    c.emails = _clean(_emails);
    c.org = _org.text.trim();
    c.note = _note.text.trim();
    try {
      await widget.repo.save(c);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف جهة الاتصال؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.delete(widget.contact!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _multi(String label, IconData icon, List<TextEditingController> ctrls,
      TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ctrls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: ctrls[i],
              keyboardType: type,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                border: const OutlineInputBorder(),
                suffixIcon: ctrls.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() => ctrls.removeAt(i)))
                    : null,
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => ctrls.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: Text('إضافة $label'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.contact == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'جهة اتصال جديدة' : 'تعديل'),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _save),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'الاسم', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 12),
              _multi('رقم', Icons.phone, _phones, TextInputType.phone),
              _multi('إيميل', Icons.email, _emails, TextInputType.emailAddress),
              const SizedBox(height: 4),
              TextField(
                  controller: _org,
                  decoration: const InputDecoration(
                      labelText: 'الشركة', prefixIcon: Icon(Icons.business), border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes), border: OutlineInputBorder())),
            ],
          ),
        ),
      ),
    );
  }
}
