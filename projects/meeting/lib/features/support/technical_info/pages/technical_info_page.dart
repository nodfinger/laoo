import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/technical_info_repository.dart';

class TechnicalInfoPage extends StatefulWidget {
  const TechnicalInfoPage({super.key});
  @override
  State<TechnicalInfoPage> createState() => _TechnicalInfoPageState();
}

class _TechnicalInfoPageState extends State<TechnicalInfoPage> {
  final _query = TextEditingController();
  final _repository = TechnicalInfoRepository();
  TechnicalInfoResult? _result;
  bool _loading = false;
  String? _error;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final version = ++_searchVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.search(_query.text.trim());
      if (mounted && version == _searchVersion) {
        setState(() => _result = value);
      }
    } catch (e) {
      if (mounted && version == _searchVersion) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _loading = false);
      }
    }
  }

  void _dismissError() {
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'ข้อมูลด้านเทคนิค',
    activeMenu: 'technicalInfo',
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: WorkspacePageTitle(
              title: 'ข้อมูลด้านเทคนิค',
              favoriteKey: 'technicalInfo',
            ),
          ),
          const Divider(height: 1, color: LaooColors.border),
          WorkspaceSectionCard(
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : 260,
                    child: TextField(
                      controller: _query,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'ค้นหา',
                          onPressed: _loading ? null : _search,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        labelText: 'ค้นหาชื่อเมนู หรือข้อกำหนด',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton(
                    onPressed: _result == null ? null : _copyAll,
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: LaooColors.border),
          if (_error != null) ...[
            AutoDismissMessage(
              key: ValueKey(_error),
              message: _error!,
              error: true,
              onClose: _dismissError,
            ),
            const SizedBox(height: 8),
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_result != null && !_loading) ...[
            Expanded(
              child: SelectionArea(
                child: ListView(
                  children: [
                    _section(
                      'ข้อมูลเมนู',
                      'รายละเอียดเมนูที่ใช้งาน',
                      _result!.menus
                          .map((x) => '${x['menuName']} (${x['menuCode']})')
                          .toList(),
                    ),
                    _dartFileSection(),
                    _mdSection(),
                    _tableSection(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _section(String title, String meaning, List<String> values) => Card(
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (values.isNotEmpty)
                OutlinedButton(
                  onPressed: () => _copyText(values.join('\n')),
                  child: const Text('Copy'),
                ),
            ],
          ),
          Text(
            meaning,
            style: const TextStyle(fontSize: LaooTypography.inputHint),
          ),
          const SizedBox(height: 10),
          if (values.isEmpty)
            const Text('ไม่พบข้อมูล')
          else
            ...values.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(v),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _tableSection() {
    final tables = _result!.tables;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Table ที่ใช้จัดเก็บข้อมูล',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (tables.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _copyText(
                      tables
                          .map(
                            (t) => '${t['tableName']} — ${t['tableMeaning']}',
                          )
                          .join('\n'),
                    ),
                    child: const Text('Copy'),
                  ),
              ],
            ),
            const Text('แสดงชื่อ Table และกดขยายเพื่อดู Fields'),
            if (tables.isEmpty)
              const Text('ไม่พบข้อมูล')
            else
              ...tables.map(
                (table) => ExpansionTile(
                  title: Text(
                    '${table['tableName']} — ${table['tableMeaning']}',
                  ),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ชื่อคอลัมน์')),
                          DataColumn(label: Text('ประเภทข้อมูล')),
                          DataColumn(label: Text('ความหมาย')),
                        ],
                        rows: ((table['fields'] as List?) ?? const [])
                            .map(
                              (field) => DataRow(
                                cells: [
                                  DataCell(Text('${field['colName']}')),
                                  DataCell(Text('${field['dataType']}')),
                                  DataCell(Text('${field['remark']}')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mdSection() {
    final mds = _result!.mds;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MD ที่เกี่ยวข้อง',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (mds.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _copyText(
                      mds
                          .map(
                            (md) =>
                                '${md['mdName']} (${md['mdCode']})\n${md['mdPath']}\\${md['mdFileName']}',
                          )
                          .join('\n'),
                    ),
                    child: const Text('Copy'),
                  ),
              ],
            ),
            const Text(
              'เอกสารและส่วนของไฟล์ที่พบคำค้น — กด Path หรือชื่อไฟล์เพื่อเปิด และลากเมาส์เพื่อเลือกข้อความ',
            ),
            const SizedBox(height: 10),
            if (mds.isEmpty)
              const Text('ไม่พบข้อมูล')
            else
              ...mds.map((md) {
                final relativePath = '${md['mdPath']}\\${md['mdFileName']}';
                final fullPath = '${md['mdFullPath'] ?? relativePath}';
                final parts = (md['parts'] as List?) ?? const [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${md['mdName']} (${md['mdCode']})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () => _openFile(fullPath),
                        icon: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: scheme.primary,
                        ),
                        label: SelectableText(
                          relativePath,
                          onTap: () => _openFile(fullPath),
                        ),
                      ),
                      ...parts
                          .take(5)
                          .map(
                            (part) => _linkedFileText(
                              'บรรทัด ${part['line']}: ${part['text']}',
                              fullPath,
                            ),
                          ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _linkedFileText(String value, String basePath) {
    final contentStyle = TextStyle(
      fontFamily: LaooTypography.fontFamily,
      fontFamilyFallback: LaooTypography.fontFallback,
      fontSize: LaooTypography.tableBody,
      height: LaooTypography.bodyLineHeight,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'[A-Za-z0-9_./\\-]+\.[A-Za-z][A-Za-z0-9]{1,11}',
      caseSensitive: false,
    );
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final reference = match.group(0)!;
      spans.add(
        TextSpan(
          text: reference,
          style: contentStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openReferencedFile(reference, basePath),
        ),
      );
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return SelectableText.rich(TextSpan(style: contentStyle, children: spans));
  }

  void _openReferencedFile(String reference, String basePath) {
    final normalizedReference = reference.replaceAll('\\', '/');
    if (RegExp(r'^[A-Za-z]:/').hasMatch(normalizedReference)) {
      _openFile(normalizedReference);
      return;
    }
    final normalizedBase = basePath.replaceAll('\\', '/');
    final marker = normalizedBase.indexOf('/docs/');
    final root = marker >= 0
        ? normalizedBase.substring(0, marker)
        : normalizedBase.substring(0, normalizedBase.lastIndexOf('/'));
    final resolved =
        normalizedReference.startsWith('lib/') ||
            normalizedReference.startsWith('docs/')
        ? '$root/$normalizedReference'
        : '${normalizedBase.substring(0, normalizedBase.lastIndexOf('/'))}/$normalizedReference';
    _openFile(resolved);
  }

  Widget _dartFileSection() {
    final files = _result!.dartFiles;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ไฟล์ Dart ของแต่ละ MenuCode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (files.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _copyText(
                      files
                          .map(
                            (x) =>
                                '${x['menuCode']} | ${x['menuName']} | ${x['relativePath']} | ${x['fullPath']}',
                          )
                          .join('\n'),
                    ),
                    child: const Text('Copy'),
                  ),
              ],
            ),
            const Text('กดปุ่มเปิดไฟล์เพื่อเปิดไฟล์ Dart ที่ใช้กับเมนูนั้น'),
            const SizedBox(height: 10),
            if (files.isEmpty)
              const Text('ไม่พบข้อมูล')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(Color(0x12000000)),
                  columns: const [
                    DataColumn(label: Text('เปิดไฟล์')),
                    DataColumn(label: Text('MenuCode')),
                    DataColumn(label: Text('ชื่อเมนู')),
                    DataColumn(label: Text('ไฟล์ Dart')),
                    DataColumn(label: Text('Path')),
                  ],
                  rows: files
                      .map(
                        (file) => DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                tooltip: 'เปิดไฟล์',
                                onPressed: () =>
                                    _openFile('${file['fullPath']}'),
                                icon: Icon(
                                  Icons.open_in_new,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            DataCell(Text('${file['menuCode']}')),
                            DataCell(Text('${file['menuName']}')),
                            DataCell(Text('${file['fileName']}')),
                            DataCell(
                              SelectableText(
                                '${file['relativePath']}',
                                onTap: () => _openFile('${file['fullPath']}'),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _allText() {
    final menus = _result!.menus
        .map((x) => '${x['menuName']} (${x['menuCode']})')
        .join('\n');
    final dartFiles = _result!.dartFiles
        .map(
          (x) =>
              '${x['menuCode']} | ${x['menuName']} | ${x['relativePath']} | ${x['fullPath']}',
        )
        .join('\n');
    final mds = _result!.mds
        .map(
          (md) =>
              '${md['mdName']} (${md['mdCode']})\n${md['mdPath']}\\${md['mdFileName']}',
        )
        .join('\n');
    final tables = _result!.tables
        .map((x) => '${x['tableName']} — ${x['tableMeaning']}')
        .join('\n');
    return 'ข้อมูลเมนู\n$menus\n\nไฟล์ Dart ของแต่ละ MenuCode\n$dartFiles\n\nMD ที่เกี่ยวข้อง\n$mds\n\nTable ที่ใช้จัดเก็บข้อมูล\n$tables';
  }

  Future<void> _copyAll() => _copyText(_allText());

  Future<void> _copyText(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      showTimedSnackBar(context, message: 'คัดลอกข้อมูลแล้ว');
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final file = await _repository.readFile(path);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TechnicalFileViewerPage(file: file),
        ),
      );
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: 'เปิดไฟล์ไม่ได้: $e', error: true);
      }
    }
  }
}

class TechnicalFileViewerPage extends StatelessWidget {
  const TechnicalFileViewerPage({required this.file, super.key});
  final TechnicalFileContent file;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(file.path.split(RegExp(r'[\\/]')).last),
      actions: [
        IconButton(
          tooltip: 'คัดลอกทั้งหมด',
          onPressed: () => Clipboard.setData(ClipboardData(text: file.content)),
          icon: const Icon(Icons.copy),
        ),
      ],
    ),
    body: SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(file.content),
      ),
    ),
  );
}
