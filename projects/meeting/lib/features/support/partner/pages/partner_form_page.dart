import 'package:flutter/material.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../models/partner.dart';

class PartnerFormPage extends StatefulWidget {
  const PartnerFormPage({super.key, this.partner, required this.onSave});

  final Partner? partner;
  final Future<void> Function(PartnerUpsertInput input) onSave;

  bool get isCreate => partner == null;

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
  String? _message;
  bool _messageIsError = false;

  List<TextEditingController> get _controllers => [
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
  ];

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
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _message = null;
    });

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

      if (!mounted) return;

      if (widget.isCreate) {
        _clearForNextCreate();
        setState(() {
          _message = 'เพิ่มข้อมูล Partner สำเร็จ';
          _messageIsError = false;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'ไม่สามารถบันทึกข้อมูลได้ กรุณาตรวจสอบข้อมูลแล้วลองอีกครั้ง';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForNextCreate() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _startContactDate = null;
    _formKey.currentState?.reset();
  }

  String? _nullIfEmpty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LaooColors.background,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceSectionCard(
                    child: WorkspaceActionHeader(
                      title: widget.isCreate
                          ? 'Partner > เพิ่ม'
                          : 'Partner > แก้ไข',
                      favoriteKey: 'Partner',
                      actions: [_actionButtons()],
                    ),
                  ),
                  const Divider(height: 1, color: LaooColors.border),
                  if (_message != null) ...[
                    AutoDismissMessage(
                      message: _message!,
                      error: _messageIsError,
                      onClose: () => setState(() => _message = null),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _Section(
                    title: 'ข้อมูล Partner',
                    children: [
                      _responsiveFields([
                        TextFormField(
                          controller: _nameTh,
                          decoration: const InputDecoration(
                            label: _RequiredLabel('ชื่อ Partner'),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'กรุณาระบุชื่อ Partner'
                              : null,
                        ),
                        TextFormField(
                          controller: _nameEn,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อภาษาอังกฤษ',
                          ),
                        ),
                        TextFormField(
                          controller: _shortName,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อย่อ',
                          ),
                        ),
                        TextFormField(
                          controller: _province,
                          decoration: const InputDecoration(
                            labelText: 'จังหวัด',
                          ),
                        ),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email กลาง',
                          ),
                        ),
                        TextFormField(
                          controller: _telephone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'โทรศัพท์กลาง',
                          ),
                        ),
                      ]),
                      TextFormField(
                        controller: _addressText,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'ที่อยู่'),
                      ),
                      const SizedBox(height: 14),
                      _DateField(
                        value: _startContactDate,
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
                      _responsiveFields([
                        TextFormField(
                          controller: _contactName1,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อผู้ติดต่อ',
                          ),
                        ),
                        TextFormField(
                          controller: _position1,
                          decoration: const InputDecoration(
                            labelText: 'ตำแหน่ง',
                          ),
                        ),
                        TextFormField(
                          controller: _phone1,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'เบอร์โทร',
                          ),
                        ),
                        TextFormField(
                          controller: _email1,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ]),
                    ],
                  ),
                  _Section(
                    title: 'ผู้ติดต่อคนที่ 2',
                    children: [
                      _responsiveFields([
                        TextFormField(
                          controller: _contactName2,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อผู้ติดต่อ',
                          ),
                        ),
                        TextFormField(
                          controller: _position2,
                          decoration: const InputDecoration(
                            labelText: 'ตำแหน่ง',
                          ),
                        ),
                        TextFormField(
                          controller: _phone2,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'เบอร์โทร',
                          ),
                        ),
                        TextFormField(
                          controller: _email2,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ]),
                    ],
                  ),
                  _Section(
                    title: 'หมายเหตุ',
                    children: [
                      TextFormField(
                        controller: _remark,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'หมายเหตุ',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i < fields.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        const gap = 14.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final field in fields) SizedBox(width: width, child: field),
          ],
        );
      },
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).inputDecorationTheme.labelStyle ??
        Theme.of(context).textTheme.bodyLarge;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
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
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: LaooTypography.sectionTitle,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'ยังไม่ได้ระบุ'
        : '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'วันที่เริ่มติดต่อ',
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: LaooTypography.inputText),
        ),
      ),
    );
  }
}
