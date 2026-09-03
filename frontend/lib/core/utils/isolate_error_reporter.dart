// Reports uncaught errors raised on background isolates to Crashlytics.
//
// Errors thrown on an isolate other than the main one reach neither
// FlutterError.onError nor PlatformDispatcher.onError, so without this listener
// they are never reported at all.
//
// Split by platform because dart:isolate does not exist on web — importing it
// unconditionally breaks the web build.
export 'isolate_error_reporter_stub.dart'
    if (dart.library.io) 'isolate_error_reporter_io.dart';
