/*
 * Copyright (c) 2021 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import 'dart:math';

import 'package:flutter/material.dart';

class GetPosition {
  GetPosition({
    required this.key,
    required this.screenWidth,
    required this.screenHeight,
    this.padding = EdgeInsets.zero,
    this.rootRenderObject,
  }) {
    getRenderBox();
  }

  final GlobalKey key;
  final EdgeInsets padding;
  final double screenWidth;
  final double screenHeight;
  final RenderObject? rootRenderObject;

  RenderBox? _box;
  Offset? _boxOffset;

  void getRenderBox() {
    final renderObject = key.currentContext?.findRenderObject();

    // A target that is detached or sits under a render box that has not been
    // laid out yet (e.g. a page re-wrapped by a route transition this frame)
    // cannot be measured: `localToGlobal` would throw "RenderBox was not laid
    // out". It is treated like a missing target until the next rebuild.
    if (renderObject is! RenderBox ||
        !isMeasurable(renderObject, ancestor: rootRenderObject)) {
      return;
    }

    _box = renderObject;
    _boxOffset = renderObject.localToGlobal(
      Offset.zero,
      ancestor: rootRenderObject,
    );
  }

  /// Whether [box] can be measured relative to [ancestor] (the render tree's
  /// root when null) without throwing.
  ///
  /// `localToGlobal` asks every render ancestor for its paint transform and
  /// some of those (e.g. the [RenderFractionalTranslation] of a
  /// [SlideTransition]) read their own size, so [box] and each [RenderBox]
  /// above it must have been laid out, and both must be attached.
  static bool isMeasurable(RenderBox box, {RenderObject? ancestor}) {
    if (!box.attached || !box.hasSize) return false;
    if (ancestor != null && !ancestor.attached) return false;
    for (RenderObject? node = box.parent; node != null; node = node.parent) {
      if (node is RenderBox && !node.hasSize) return false;
      if (identical(node, ancestor)) break;
    }
    return true;
  }

  bool _checkBoxOrOffsetIsNull({bool checkDy = false, bool checkDx = false}) {
    return _box == null ||
        _boxOffset == null ||
        (checkDx && (_boxOffset?.dx.isNaN ?? true)) ||
        (checkDy && (_boxOffset?.dy.isNaN ?? true));
  }

  Rect getRect() {
    if (_checkBoxOrOffsetIsNull(checkDy: true, checkDx: true)) {
      return Rect.zero;
    }
    final topLeft = _box!.size.topLeft(_boxOffset!);
    final bottomRight = _box!.size.bottomRight(_boxOffset!);
    final leftDx = topLeft.dx - padding.left;
    final leftDy = topLeft.dy - padding.top;
    final rect = Rect.fromLTRB(
      leftDx.clamp(0, leftDx),
      leftDy.clamp(0, leftDy),
      min(bottomRight.dx + padding.right, screenWidth),
      min(bottomRight.dy + padding.bottom, screenHeight),
    );
    return rect;
  }

  ///Get the bottom position of the widget
  double getBottom() {
    if (_checkBoxOrOffsetIsNull(checkDy: true)) {
      return padding.bottom;
    }
    final bottomRight = _box!.size.bottomRight(_boxOffset!);
    return bottomRight.dy + padding.bottom;
  }

  ///Get the top position of the widget
  double getTop() {
    if (_checkBoxOrOffsetIsNull(checkDy: true)) {
      return -padding.top;
    }
    final topLeft = _box!.size.topLeft(_boxOffset!);
    return topLeft.dy - padding.top;
  }

  ///Get the left position of the widget
  double getLeft() {
    if (_checkBoxOrOffsetIsNull(checkDx: true)) {
      return -padding.left;
    }
    final topLeft = _box!.size.topLeft(_boxOffset!);
    return topLeft.dx - padding.left;
  }

  ///Get the right position of the widget
  double getRight() {
    if (_checkBoxOrOffsetIsNull(checkDx: true)) {
      return padding.right;
    }
    final bottomRight = _box!.size.bottomRight(_boxOffset!);
    return bottomRight.dx + padding.right;
  }

  double getHeight() => getBottom() - getTop();

  double getWidth() => getRight() - getLeft();

  double getCenter() => (getLeft() + getRight()) * 0.5;
}
