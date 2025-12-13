import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

part 'notes_widget_config_state.dart';

class NotesWidgetConfigCubit extends Cubit<NotesWidgetConfigState> {
  static const String _notesKey = 'notes_widget_notes';
  static const String _vaultKey = 'notes_widget_vault_name';
  static const String _vaultDirKey = 'notes_widget_vault_directory';

  NotesWidgetConfigCubit() : super(NotesWidgetConfigLoading());

  Future<void> load() async {
    try {
      final existingNotesJson =
          await HomeWidget.getWidgetData<String>(_notesKey);

      List<String> notes = [];
      final bookmarkSet = <String>{};

      if (existingNotesJson != null && existingNotesJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(existingNotesJson);
          for (final element in list) {
            if (element is Map<String, dynamic>) {
              final file = element['file'] as String?;
              if (file == null || file.isEmpty) continue;
              final isBookmark =
                  (element['bookmark'] as bool?) ?? bookmarkSet.contains(file);
              if (!isBookmark) {
                notes.add(file);
              }
            }
          }
        } catch (e) {
          Logger().w('Failed to decode existing notes widget data: $e');
        }
      }

      emit(NotesWidgetConfigLoaded(
        notes: notes,
      ));
    } catch (e) {
      Logger().e('Failed to load notes widget config data: $e');
      emit(NotesWidgetConfigError('Failed to load configuration'));
    }
  }

  Future<void> save(
    BuildContext context,
    String notesRaw,
  ) async {
    try {
      final settings = SettingsController.getInstance();
      final vaultDir = settings.vaultDirectory;
      final vaultName = settings.vaultName;
      if (vaultDir == null || vaultDir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Vault is not configured. Please configure vault in settings first.'),
          ),
        );
        return;
      }

      final trimmedVaultName = (vaultName ?? '').trim();
      if (trimmedVaultName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Vault name is not configured. Please configure vault in settings first.'),
          ),
        );
        return;
      }

      final parts = notesRaw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Store as array of objects: {"file": <note>, "bookmark": false}
      final notesObjects =
          parts.map((file) => {'file': file, 'bookmark': false}).toList();
      final notesJson = jsonEncode(notesObjects);

      await NotesWidgetConfigCubit.updateWidgetData(notesJson);

      if (state is NotesWidgetConfigLoaded) {
        emit((state as NotesWidgetConfigLoaded).copyWith(
          vaultDirectory: vaultDir,
          vaultName: trimmedVaultName,
          notes: parts,
        ));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes widget configuration saved.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      Logger().e('Failed to save notes widget config: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save configuration.')),
      );
    }
  }

  static Future<void> updateWidgetWithVaultInfo() async {
    await HomeWidget.saveWidgetData<String>(
        _vaultKey, SettingsController.getInstance().vaultName);

    await HomeWidget.saveWidgetData<String>(
        _vaultDirKey, SettingsController.getInstance().vaultDirectory);

    await HomeWidget.updateWidget(
      name: 'NotesWidgetReceiver',
      iOSName: 'HomeWidget',
    );
  }

  static Future<void> updateWidgetData(String notesJson) async {
    await HomeWidget.saveWidgetData<String>(_notesKey, notesJson);
    await HomeWidget.updateWidget(
      name: 'NotesWidgetReceiver',
      iOSName: 'HomeWidget',
    );
  }
}
