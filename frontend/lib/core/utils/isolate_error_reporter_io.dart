import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Forwards uncaught errors from background isolates to Crashlytics.
///
/// The isolate error port delivers a two-element list: the error and the stack
/// trace, both already converted to strings by the isolate boundary.
void listenForIsolateErrors() {
  Isolate.current.addErrorListener(RawReceivePort((dynamic pair) async {
    final errorAndStacktrace = pair as List<dynamic>;
    await FirebaseCrashlytics.instance.recordError(
      errorAndStacktrace.first,
      errorAndStacktrace.last == null
          ? null
          : StackTrace.fromString(errorAndStacktrace.last as String),
      reason: 'Uncaught error on a background isolate',
      fatal: true,
    );
  }).sendPort);
}
