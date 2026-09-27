import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _EnumWindowsProcNative = Int32 Function(IntPtr hWnd, IntPtr lParam);

typedef _EnumWindowsNative =
    Int32 Function(
      Pointer<NativeFunction<_EnumWindowsProcNative>> callback,
      IntPtr lParam,
    );
typedef _EnumWindowsDart =
    int Function(
      Pointer<NativeFunction<_EnumWindowsProcNative>> callback,
      int lParam,
    );

typedef _GetWindowThreadProcessIdNative =
    Uint32 Function(IntPtr hWnd, Pointer<Uint32> processId);
typedef _GetWindowThreadProcessIdDart =
    int Function(int hWnd, Pointer<Uint32> processId);

typedef _IsWindowVisibleNative = Int32 Function(IntPtr hWnd);
typedef _IsWindowVisibleDart = int Function(int hWnd);

typedef _GetWindowNative = IntPtr Function(IntPtr hWnd, Uint32 command);
typedef _GetWindowDart = int Function(int hWnd, int command);

typedef _GetCurrentProcessIdNative = Uint32 Function();
typedef _GetCurrentProcessIdDart = int Function();

typedef _SetWindowTextWNative =
    Int32 Function(IntPtr hWnd, Pointer<Utf16> text);
typedef _SetWindowTextWDart = int Function(int hWnd, Pointer<Utf16> text);

const int _gwOwner = 4;

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final _EnumWindowsDart _enumWindows = _user32
    .lookupFunction<_EnumWindowsNative, _EnumWindowsDart>('EnumWindows');

final _GetWindowThreadProcessIdDart _getWindowThreadProcessId = _user32
    .lookupFunction<
      _GetWindowThreadProcessIdNative,
      _GetWindowThreadProcessIdDart
    >('GetWindowThreadProcessId');

final _IsWindowVisibleDart _isWindowVisible = _user32
    .lookupFunction<_IsWindowVisibleNative, _IsWindowVisibleDart>(
      'IsWindowVisible',
    );

final _GetWindowDart _getWindow = _user32
    .lookupFunction<_GetWindowNative, _GetWindowDart>('GetWindow');

final _GetCurrentProcessIdDart _getCurrentProcessId = _kernel32
    .lookupFunction<_GetCurrentProcessIdNative, _GetCurrentProcessIdDart>(
      'GetCurrentProcessId',
    );

final _SetWindowTextWDart _setWindowText = _user32
    .lookupFunction<_SetWindowTextWNative, _SetWindowTextWDart>(
      'SetWindowTextW',
    );

int _targetProcessId = 0;
int _foundWindow = 0;

int _enumWindowCallback(int hWnd, int lParam) {
  final processIdPointer = calloc<Uint32>();

  try {
    _getWindowThreadProcessId(hWnd, processIdPointer);

    final belongsToCurrentProcess = processIdPointer.value == _targetProcessId;
    final isVisible = _isWindowVisible(hWnd) != 0;
    final hasNoOwner = _getWindow(hWnd, _gwOwner) == 0;

    if (belongsToCurrentProcess && isVisible && hasNoOwner) {
      _foundWindow = hWnd;

      // FALSE stops EnumWindows because the correct top-level window was found.
      return 0;
    }

    return 1;
  } finally {
    calloc.free(processIdPointer);
  }
}

final Pointer<NativeFunction<_EnumWindowsProcNative>> _enumWindowCallbackPtr =
    Pointer.fromFunction<_EnumWindowsProcNative>(_enumWindowCallback, 1);

void setWindowTitle(String title) {
  if (!Platform.isWindows) {
    return;
  }

  final normalizedTitle = title.trim();
  if (normalizedTitle.isEmpty) {
    return;
  }

  _targetProcessId = _getCurrentProcessId();
  _foundWindow = 0;

  _enumWindows(_enumWindowCallbackPtr, 0);

  if (_foundWindow == 0) {
    return;
  }

  final nativeTitle = normalizedTitle.toNativeUtf16();

  try {
    _setWindowText(_foundWindow, nativeTitle);
  } finally {
    calloc.free(nativeTitle);
  }
}
