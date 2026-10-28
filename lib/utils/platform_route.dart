import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Retourne CupertinoPageRoute sur iOS (swipe-back natif), MaterialPageRoute ailleurs.
PageRoute<T> platformRoute<T>({required WidgetBuilder builder, bool fullscreenDialog = false}) {
  if (Platform.isIOS) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}

/// showCupertinoDialog sur iOS (animation + barrière natifs), showDialog ailleurs.
Future<T?> showPlatformDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  if (Platform.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
