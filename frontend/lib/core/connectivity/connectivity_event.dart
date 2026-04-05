part of 'connectivity_bloc.dart';

abstract class ConnectivityEvent {}

class ConnectivityStatusChanged extends ConnectivityEvent {
  final bool isOnline;
  ConnectivityStatusChanged({required this.isOnline});
}
