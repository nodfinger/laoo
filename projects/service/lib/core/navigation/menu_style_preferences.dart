import 'package:flutter/foundation.dart';

const menuStyleSlide = 'SLIDE';
const menuStyleButton = 'BUTTON';

// Button navigation is the mobile-safe default when a user has not saved a
// menu preference yet. An explicit SLIDE preference still overrides this
// value when the profile is loaded.
final ValueNotifier<bool> workspaceButtonMenu = ValueNotifier<bool>(true);
