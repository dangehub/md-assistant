part of 'init_cubit.dart';

@immutable
sealed class InitState {}

final class InitInitial extends InitState {}

final class InitScanning extends InitState {}

final class InitScanResults extends InitState {
  final List<String> vaultPaths;
  InitScanResults(this.vaultPaths);
}

final class InitNoVaultsFound extends InitState {}

final class InitError extends InitState {
  final String message;
  InitError(this.message);
}

final class ChosenDirectory extends InitState {
  final String vaultDirectory;
  ChosenDirectory(this.vaultDirectory);
}
