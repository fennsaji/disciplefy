import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/network/network_info.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';

import 'connectivity_bloc_test.mocks.dart';

@GenerateMocks([NetworkInfo])
void main() {
  late MockNetworkInfo mockNetworkInfo;

  setUp(() {
    mockNetworkInfo = MockNetworkInfo();
  });

  group('ConnectivityBloc', () {
    test('initial state is ConnectivityInitial', () {
      when(mockNetworkInfo.connectivityStream)
          .thenAnswer((_) => const Stream.empty());
      final bloc = ConnectivityBloc(networkInfo: mockNetworkInfo);
      expect(bloc.state, isA<ConnectivityInitial>());
      bloc.close();
    });

    blocTest<ConnectivityBloc, ConnectivityState>(
      'emits ConnectivityOffline when status changed to offline',
      build: () {
        when(mockNetworkInfo.connectivityStream)
            .thenAnswer((_) => const Stream.empty());
        return ConnectivityBloc(networkInfo: mockNetworkInfo);
      },
      act: (bloc) => bloc.add(ConnectivityStatusChanged(isOnline: false)),
      expect: () => [isA<ConnectivityOffline>()],
    );

    blocTest<ConnectivityBloc, ConnectivityState>(
      'emits ConnectivityOnline when status changed to online',
      build: () {
        when(mockNetworkInfo.connectivityStream)
            .thenAnswer((_) => const Stream.empty());
        return ConnectivityBloc(networkInfo: mockNetworkInfo);
      },
      act: (bloc) => bloc.add(ConnectivityStatusChanged(isOnline: true)),
      expect: () => [isA<ConnectivityOnline>()],
    );
  });
}
