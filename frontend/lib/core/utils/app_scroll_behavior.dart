import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Lets a mouse (and a stylus or trackpad) drag-scroll lists like a finger
/// does. Flutter's default only scrolls with touch, so on desktop web a
/// click-and-drag on a list did nothing.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
