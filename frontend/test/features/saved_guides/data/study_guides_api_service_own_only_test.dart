import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/saved_guides/data/services/study_guides_api_service.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';

class _MockHttpService extends Mock implements HttpService {}

void main() {
  late _MockHttpService httpService;
  late StudyGuidesApiService service;
  String? requestedUrl;

  setUp(() {
    httpService = _MockHttpService();
    requestedUrl = null;
    when(() => httpService.createHeaders()).thenAnswer((_) async => {});
    when(() => httpService.get(any(), headers: any(named: 'headers')))
        .thenAnswer((inv) async {
      requestedUrl = inv.positionalArguments.first as String;
      return http.Response('{"success":true,"data":{"guides":[]}}', 200);
    });
    service = StudyGuidesApiService(httpService: httpService);
  });

  test('ownOnly adds own_only=true', () async {
    await service.getStudyGuides(limit: 5, ownOnly: true);
    expect(Uri.parse(requestedUrl!).queryParameters['own_only'], 'true');
  });

  test('default request omits own_only', () async {
    await service.getStudyGuides(limit: 5);
    expect(Uri.parse(requestedUrl!).queryParameters.containsKey('own_only'),
        isFalse);
  });

  test('LoadRecentGuidesFromApi carries ownOnly and defaults to false', () {
    expect(const LoadRecentGuidesFromApi().ownOnly, isFalse);
    expect(
      const LoadRecentGuidesFromApi(ownOnly: true),
      isNot(const LoadRecentGuidesFromApi()),
    );
  });
}
