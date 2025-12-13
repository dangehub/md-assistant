import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/main_navigator.dart' as main_screen;
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
part 'init_state.dart';

class InitCubit extends Cubit<InitState> {
  final SettingsController _settings;
  final TaskManager _taskManager;
  String? vaultDirectory;

  InitCubit(SettingsController settings, this._taskManager)
      : _settings = settings,
        vaultDirectory = settings.vaultDirectory,
        super(InitInitial());

  Future<void> startScanning(BuildContext context) async {
    // Only auto-scan on Android; other platforms fall back to manual selection
    if (!Platform.isAndroid) {
      emit(InitNoVaultsFound());
      return;
    }

    emit(InitScanning());

    try {
      var granted = await SettingsController.storagePermissionsGranted();
      if (!granted) {
        final status =
            await SettingsController.requestAndroidPermission(context);
        granted = status == PermissionStatus.granted;
      }

      if (!granted) {
        emit(InitNoVaultsFound());
        return;
      }

      final vaults = await _scanForVaults();
      if (vaults.isEmpty) {
        emit(InitNoVaultsFound());
      } else {
        emit(InitScanResults(vaults));
      }
    } catch (e) {
      emit(InitError(e.toString()));
    }
  }

  Future<List<String>> _scanForVaults() async {
    final Set<String> vaultPaths = {};

    Future<void> scanRecursive(String basePath) async {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) return;

      await for (final entity
          in baseDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory && p.basename(entity.path) == '.obsidian') {
          final parent = p.dirname(entity.path);
          vaultPaths.add(parent);
        }
      }
    }

    Future<void> scanRootLevel(String rootPath) async {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) return;

      await for (final entity
          in rootDir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          final obsidianDir = Directory(p.join(entity.path, '.obsidian'));
          if (await obsidianDir.exists()) {
            vaultPaths.add(entity.path);
          }
        }
      }
    }

    // Scan specific directories and their subfolders
    await scanRecursive('/storage/emulated/0/Documents/');
    await scanRecursive('/storage/emulated/0/Download/');
    await scanRecursive('/storage/emulated/0/Obsidian/');

    // Scan root level folders only
    await scanRootLevel('/storage/emulated/0/');

    return vaultPaths.toList()..sort();
  }

  Future<void> selectDirectory(BuildContext context) async {
    try {
      vaultDirectory = await SettingsController.selectVaultDirectory(context);
      if (vaultDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No folder selected.')),
        );
        return;
      }

      emit(ChosenDirectory(vaultDirectory!));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void continuePressed(BuildContext context) {
    if (vaultDirectory == null) return;

    _taskManager.loadTasks(vaultDirectory!);
    _settings.updateVaultDirectory(vaultDirectory!);

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => main_screen.MainNavigator(0, _taskManager)),
        (Route<dynamic> route) => false);
  }

  void selectScannedVault(BuildContext context, String path) {
    vaultDirectory = path;
    emit(ChosenDirectory(path));
    continuePressed(context);
  }
}
