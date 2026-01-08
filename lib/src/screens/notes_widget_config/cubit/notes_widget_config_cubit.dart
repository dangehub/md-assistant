import 'dart:convert';

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
      if (vaultDir == null || vaultDir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Vault is not configured. Please configure vault in settings first.'),
          ),
        );
        return;
      }

      // vaultName is optional for Memos widget (only needed for Obsidian URI)
      // Try to get it, but don't fail if it's not set
      String vaultName = '';
      try {
        vaultName = settings.vaultName;
      } catch (e) {
        // vaultName not set, use empty string
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
      // Also save vault info so Android can read it
      await NotesWidgetConfigCubit.updateWidgetWithVaultInfo();

      if (state is NotesWidgetConfigLoaded) {
        emit((state as NotesWidgetConfigLoaded).copyWith(
          vaultDirectory: vaultDir,
          vaultName: vaultName,
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
    final settings = SettingsController.getInstance();
    final vaultDir = settings.vaultDirectory;

    // Try to get vaultName, fallback to extracting from path
    String? vaultName;
    try {
      vaultName = settings.vaultName;
    } catch (e) {
      // If vaultName fails, extract from directory path
      if (vaultDir != null) {
        vaultName = vaultDir.split('/').last.split('\\').last;
      }
    }

    await HomeWidget.saveWidgetData<String>(_vaultKey, vaultName);
    await HomeWidget.saveWidgetData<String>(_vaultDirKey, vaultDir);

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
