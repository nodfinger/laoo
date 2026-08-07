import 'package:flutter/material.dart';

import '../models/partner.dart';

class PartnerFormPage extends StatefulWidget {
  const PartnerFormPage({super.key, this.partner, required this.onSave});

  final Partner? partner;
  final Future<void> Function(PartnerUpsertInput input) onSave;

  @override
  State<PartnerFormPage> createState() => _PartnerFormPageState();
}

class _PartnerFormPageState extends State<PartnerFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameTh;
  late final TextEditingController _nameEn;
  late final TextEditingController _email;
  late final TextEditingController _telephone;
  late final TextEditingController _addressText;
  late final TextEditingController _shortName;
  late final TextEditingController _province;

  late final TextEditingController _contactName1;
  late final TextEditingController _position1;
  late final TextEditingController _phone1;
  late final TextEditingController _email1;

  late final TextEditingController _contactName2;
  late final TextEditingController _position2;
  late final TextEditingController _phone2;
  late final TextEditingController _email2;

  late final TextEditingController _remark;

  DateTime? _startContactDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final p = widget.partner;

    _nameTh = TextEditingController(text: p?.partnerNameTh ?? '');
    _nameEn = TextEditingController(text: p?.partnerNameEn ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _telephone = TextEditingController(text: p?.telephone ?? '');
    _addressText = TextEditingController(text: p?.addressText ?? '');
    _shortName = TextEditingController(text: p?.shortName ?? '');
    _province = TextEditingController(text: p?.province ?? '');

    _contactName1 = TextEditingController(text: p?.contactName1 ?? '');
    _position1 = TextEditingController(text: p?.contactPosition1 ?? '');
    _phone1 = TextEditingController(text: p?.contactPhone1 ?? '');
    _email1 = TextEditingController(text: p?.contactEmail1 ?? '');

    _contactName2 = TextEditingController(text: p?.contactName2 ?? '');
    _position2 = TextEditingController(text: p?.contactPosition2 ?? '');
    _phone2 = TextEditingController(text: p?.contactPhone2 ?? '');
    _email2 = TextEditingController(text: p?.contactEmail2 ?? '');

    _remark = TextEditingController(text: p?.remark ?? '');

    _startContactDate = p?.startContactDate;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameTh,
      _nameEn,
      _email,
      _telephone,
      _addressText,
      _shortName,
      _province,
      _contactName1,
      _position1,
      _phone1,
      _email1,
      _contactName2,
      _position2,
      _phone2,
      _email2,
      _remark,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.onSave(
        PartnerUpsertInput(
          partnerNameTh: _nameTh.text.trim(),
          partnerNameEn: _nullIfEmpty(_nameEn.text),
          email: _nullIfEmpty(_email.text),
          telephone: _nullIfEmpty(_telephone.text),
          addressText: _nullIfEmpty(_addressText.text),
          shortName: _nullIfEmpty(_shortName.text),
          province: _nullIfEmpty(_province.text),
          startContactDate: _startContactDate,
          contactName1: _nullIfEmpty(_contactName1.text),
          contactPosition1: _nullIfEmpty(_position1.text),
          contactPhone1: _nullIfEmpty(_phone1.text),
          contactEmail1: _nullIfEmpty(_email1.text),
          contactName2: _nullIfEmpty(_contactName2.text),
          contactPosition2: _nullIfEmpty(_position2.text),
          contactPhone2: _nullIfEmpty(_phone2.text),
          contactEmail2: _nullIfEmpty(_email2.text),
          remark: _nullIfEmpty(_remark.text),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _nullIfEmpty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partner == null ? 'เพิ่ม Partner' : 'แก้ไข Partner'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Section(
              title: 'ข้อมูล Partner',
              children: [
                TextFormField(
                  controller: _nameTh,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ Partner *',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณาระบุชื่อ Partner';
                    }

                    return null;
                  },
                ),
                TextFormField(
                  controller: _nameEn,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อภาษาอังกฤษ',
                  ),
                ),
                TextFormField(
                  controller: _shortName,
                  decoration: const InputDecoration(labelText: 'ชื่อย่อ'),
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email กลาง'),
                ),
                TextFormField(
                  controller: _telephone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'โทรศัพท์กลาง'),
                ),
                TextFormField(
                  controller: _province,
                  decoration: const InputDecoration(labelText: 'จังหวัด'),
                ),
                TextFormField(
                  controller: _addressText,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ที่อยู่'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('วันที่เริ่มติดต่อ'),
                  subtitle: Text(
                    _startContactDate == null
                        ? 'ยังไม่ได้ระบุ'
                        : '${_startContactDate!.day.toString().padLeft(2, '0')}/'
                              '${_startContactDate!.month.toString().padLeft(2, '0')}/'
                              '${_startContactDate!.year}',
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _startContactDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (selected != null) {
                      setState(() => _startContactDate = selected);
                    }
                  },
                ),
              ],
            ),
            _Section(
              title: 'ผู้ติดต่อคนที่ 1',
              children: [
                TextFormField(
                  controller: _contactName1,
                  decoration: const InputDecoration(labelText: 'ชื่อผู้ติดต่อ'),
                ),
                TextFormField(
                  controller: _position1,
                  decoration: const InputDecoration(labelText: 'ตำแหน่ง'),
                ),
                TextFormField(
                  controller: _phone1,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                ),
                TextFormField(
                  controller: _email1,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ],
            ),
            _Section(
              title: 'ผู้ติดต่อคนที่ 2',
              children: [
                TextFormField(
                  controller: _contactName2,
                  decoration: const InputDecoration(labelText: 'ชื่อผู้ติดต่อ'),
                ),
                TextFormField(
                  controller: _position2,
                  decoration: const InputDecoration(labelText: 'ตำแหน่ง'),
                ),
                TextFormField(
                  controller: _phone2,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                ),
                TextFormField(
                  controller: _email2,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ],
            ),
            _Section(
              title: 'หมายเหตุ',
              children: [
                TextFormField(
                  controller: _remark,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
