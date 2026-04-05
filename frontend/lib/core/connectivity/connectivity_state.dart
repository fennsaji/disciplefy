part of 'connectivity_bloc.dart';

abstract class ConnectivityState {}

class ConnectivityInitial extends ConnectivityState {}

class ConnectivityOnline extends ConnectivityState {}

class ConnectivityOffline extends ConnectivityState {}
