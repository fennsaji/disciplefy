@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two files that decide whether a shared link opens the app.
///
/// Both were broken in production at once: `assetlinks.json` served a
/// fingerprint no longer in the repo, so Android never verified the domain,
/// and the Apple file was answered by the SPA's catch-all with `index.html` —
/// iOS silently disables Universal Links when the response is not JSON. Every
/// shared link fell back to the browser.
///
/// They are static files under `web/`, which the build copies into the deploy
/// output where they take precedence over the catch-all rewrite.
void main() {
  final assetlinksFile = File('web/.well-known/assetlinks.json');
  final aasaFile = File('web/.well-known/apple-app-site-association');

  test('both verification files exist in the web output', () {
    expect(assetlinksFile.existsSync(), true,
        reason:
            '${assetlinksFile.path} is what Android fetches to verify the domain');
    expect(aasaFile.existsSync(), true,
        reason: '${aasaFile.path} is what iOS fetches to verify the domain');
  });

  test('assetlinks lists the Play app signing certificate', () {
    final json = jsonDecode(assetlinksFile.readAsStringSync()) as List<dynamic>;
    final target =
        (json.first as Map<String, dynamic>)['target'] as Map<String, dynamic>;
    final fingerprints =
        (target['sha256_cert_fingerprints'] as List<dynamic>).cast<String>();

    expect(target['package_name'], 'com.disciplefy.bible_study');
    // Play App Signing re-signs the upload, so the installed app presents this
    // certificate. Without it Android reports the domain unverified and the
    // link opens in the browser.
    expect(
      fingerprints,
      contains(
        '24:DE:DC:91:28:77:35:DB:6F:54:FF:B0:83:FA:43:3B:AC:6E:C3:51:EA:51:56:06:72:8A:E8:86:81:FC:BE:69',
      ),
    );
  });

  test('the Apple file is JSON, not the SPA fallback', () {
    final raw = aasaFile.readAsStringSync();
    expect(raw.trimLeft().startsWith('<'), false,
        reason: 'HTML here disables Universal Links silently');

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final details = ((json['applinks'] as Map<String, dynamic>)['details']
        as List<dynamic>);
    expect(details, isNotEmpty);
  });

  test('the shared-post path opens the app on both platforms', () {
    final aasa =
        jsonDecode(aasaFile.readAsStringSync()) as Map<String, dynamic>;
    final details =
        ((aasa['applinks'] as Map<String, dynamic>)['details'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final components = (details.first['components'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((c) => c['/'] as String)
        .toList();

    expect(components, contains('/fellowship/*/post/*'));
    expect(components, contains('/fellowship/join/*'));

    // The Android side declares the same paths as intent-filter prefixes.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android:pathPrefix="/fellowship"'), true);
    expect(manifest.contains('android:host="app.disciplefy.in"'), true);
  });

  test('the static Apple file matches the serverless function', () {
    // Both exist; the static file wins on Vercel. If only the function were
    // updated, the served file would quietly go stale — which is how the
    // production copy drifted in the first place.
    final fn = File('api/apple-app-site-association.js').readAsStringSync();
    final declared = RegExp(r"'(/[^']+)'")
        .allMatches(fn.split('DEEP_LINK_PATHS')[1].split('];')[0])
        .map((m) => m.group(1)!)
        .toList();

    final aasa =
        jsonDecode(aasaFile.readAsStringSync()) as Map<String, dynamic>;
    final details =
        ((aasa['applinks'] as Map<String, dynamic>)['details'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final components = (details.first['components'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((c) => c['/'] as String)
        .toList();

    expect(components, equals(declared));
  });
}
