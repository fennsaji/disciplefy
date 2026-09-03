import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android App Links only verify when the host serves an assetlinks.json
/// listing the certificate the installed build was signed with.
///
/// Three places describe this and had drifted apart: the serverless route that
/// actually serves app.disciplefy.in listed only the Play app-signing key, the
/// static copy under web/ mirrored it, and marketing/ advertised a fingerprint
/// matching no key in the repo.
void main() {
  final fingerprintPattern = RegExp(r'(?:[0-9A-F]{2}:){31}[0-9A-F]{2}');

  Set<String> fingerprintsFromJson(String path) {
    final doc = jsonDecode(File(path).readAsStringSync()) as List;
    return doc
        .expand(
            (entry) => (entry['target']['sha256_cert_fingerprints'] as List))
        .cast<String>()
        .toSet();
  }

  test('every assetlinks source lists the same certificates', () {
    // The route behind the /.well-known/assetlinks.json rewrite is the one
    // Android actually fetches, so it is the reference.
    final route = File('api/assetlinks.js').readAsStringSync();
    final served =
        fingerprintPattern.allMatches(route).map((m) => m.group(0)!).toSet();

    expect(served.length, greaterThanOrEqualTo(2),
        reason: 'expected both the Play app-signing key and the upload key');

    expect(fingerprintsFromJson('web/.well-known/assetlinks.json'), served);
    expect(
      fingerprintsFromJson('../marketing/public/.well-known/assetlinks.json'),
      served,
    );
  });

  test('the upload keystore certificate is one of the listed fingerprints', () {
    final route = File('api/assetlinks.js').readAsStringSync();
    // Produced by:
    //   keytool -list -v -keystore android/app/upload-keystore.jks \
    //     -alias disciplefy-upload-key
    const uploadKey =
        '24:74:AC:DD:4F:B4:1D:2C:E1:A4:0E:2C:63:DE:00:0D:49:77:83:57:BF:A8:CE:E7:CE:78:2D:C9:24:DF:03:2F';
    expect(route.contains(uploadKey), isTrue);
  });
}
