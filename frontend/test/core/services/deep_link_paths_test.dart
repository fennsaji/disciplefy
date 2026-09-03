import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every path advertised as an App Link (AndroidManifest.xml `pathPrefix`
/// entries with autoVerify, and DEEP_LINK_PATHS in the iOS association file)
/// must have a matching branch in DeepLinkService._handleUri.
///
/// `/learning-path` was advertised on both platforms with no handler: the link
/// verified, opened the app, and dropped the user on Home.
void main() {
  final service =
      File('lib/core/services/deep_link_service.dart').readAsStringSync();

  test('AndroidManifest App Link prefixes are all handled', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // Only the autoVerify intent-filter advertises our own App Links; the
    // Supabase OAuth filter deliberately has no autoVerify.
    final verified = manifest.split('android:autoVerify="true"')[1];
    final block = verified.split('</intent-filter>').first;

    final prefixes = RegExp(r'android:pathPrefix="([^"]+)"')
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toList();

    expect(prefixes, isNotEmpty, reason: 'no verified pathPrefix found');

    for (final prefix in prefixes) {
      final firstSegment = prefix.split('/').where((s) => s.isNotEmpty).first;
      expect(
        service.contains("'$firstSegment'"),
        isTrue,
        reason: 'DeepLinkService has no branch for advertised path "$prefix"',
      );
    }
  });

  test('iOS association paths are all handled', () {
    final aasa = File('api/apple-app-site-association.js').readAsStringSync();
    final paths = RegExp(r"'(/[^']+)'")
        .allMatches(aasa.split('DEEP_LINK_PATHS')[1].split(']').first)
        .map((m) => m.group(1)!)
        .toList();

    expect(paths, isNotEmpty);

    for (final path in paths) {
      final firstSegment = path.split('/').where((s) => s.isNotEmpty).first;
      expect(
        service.contains("'$firstSegment'"),
        isTrue,
        reason: 'DeepLinkService has no branch for advertised path "$path"',
      );
    }
  });
}
