import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';

/// Camera and keyboard-wedge scanning share the same guarded submission path.
/// QR contents stay in memory; they are never interpreted as URLs or logged.
class MeetingQrScanner extends StatefulWidget {
  const MeetingQrScanner({
    super.key,
    required this.onToken,
    required this.onError,
    this.enabled = true,
  });

  final Future<bool> Function(String token) onToken;
  final ValueChanged<String> onError;
  final bool enabled;

  @override
  State<MeetingQrScanner> createState() => _MeetingQrScannerState();
}

class _MeetingQrScannerState extends State<MeetingQrScanner> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _camera = false;
  bool _busy = false;
  bool _reportedCameraError = false;
  String? _lastAccepted;
  String? _validation;

  bool get _cameraSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    if (_busy || !widget.enabled) return;
    final token = raw.trim();
    if (token.isEmpty || token.length > 8192 || token == _lastAccepted) {
      setState(
        () => _validation = token == _lastAccepted
            ? 'QR นี้เช็กอินแล้ว กรุณาสแกนรายการถัดไป'
            : 'กรุณาสแกนหรือวางรหัส QR ที่ถูกต้อง (ไม่เกิน 8192 ตัวอักษร)',
      );
      return;
    }
    setState(() {
      _busy = true;
      _camera = false;
      _validation = null;
    });
    try {
      final accepted = await widget.onToken(token);
      if (!mounted) return;
      if (accepted) {
        _lastAccepted = token;
        _text.clear();
      }
    } catch (_) {
      if (mounted) {
        widget.onError(
          'เช็กอินด้วย QR ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาโหลดสถานะล่าสุดก่อนลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _focus.requestFocus();
      }
    }
  }

  void _cameraError() {
    if (_reportedCameraError) return;
    _reportedCameraError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onError(
        'เปิดกล้องสแกน QR ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ตรวจสิทธิ์กล้องและการเชื่อมต่อ หากใช้เว็บให้เปิดผ่าน HTTPS หรือ localhost หรือใช้เครื่องสแกนแทน',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'เข้าสู่ระบบด้วยบัญชีของตนเอง แล้วสแกน QR ห้องเพื่อเช็กอิน หรือให้ผู้ดูแลสแกน QR คำเชิญของผู้เข้าร่วม',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('meeting-qr-input'),
          controller: _text,
          focusNode: _focus,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 8192,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'สแกนด้วยเครื่องอ่าน QR หรือวางรหัส',
            helperText: 'คลิกช่องนี้ แล้วสแกนด้วยเครื่องอ่านที่ส่งปุ่ม Enter',
            helperMaxLines: 3,
            errorText: _validation,
            errorMaxLines: 3,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          onChanged: (_) {
            if (_validation != null) setState(() => _validation = null);
          },
          onSubmitted: _submit,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: enabled ? () => _submit(_text.text) : null,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: Text(_busy ? 'กำลังเช็กอิน...' : 'เช็กอินจาก QR'),
            ),
            if (_cameraSupported)
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => setState(() {
                        _camera = !_camera;
                        _reportedCameraError = false;
                      })
                    : null,
                icon: Icon(
                  _camera ? Icons.videocam_off_outlined : Icons.qr_code_scanner,
                ),
                label: Text(_camera ? 'ปิดกล้อง' : 'เปิดกล้องสแกน QR'),
              ),
          ],
        ),
        if (!_cameraSupported) ...[
          const SizedBox(height: 8),
          const Text(
            'บน Windows/Linux ใช้เครื่องสแกน USB หรือวางรหัส QR; หากต้องการใช้กล้อง ให้เปิดผ่านเว็บ HTTPS ที่รองรับกล้อง',
            style: TextStyle(fontSize: LaooTypography.inputHint),
          ),
        ],
        if (_camera && enabled) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AspectRatio(
                aspectRatio: 1,
                // The scanner owns its controller and handles app lifecycle and
                // disposal. Unmounting after detection releases the camera.
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.format == BarcodeFormat.qrCode &&
                          barcode.rawValue?.isNotEmpty == true) {
                        _submit(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                  onDetectError: (_, _) => _cameraError(),
                  errorBuilder: (_, _) {
                    _cameraError();
                    return const ColoredBox(
                      color: LaooColors.background,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(LaooLayout.cardPadding),
                          child: Text(
                            'ไม่สามารถเปิดกล้องได้\nตรวจสิทธิ์กล้อง หรือใช้เครื่องสแกน/วางรหัสด้านบน',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
