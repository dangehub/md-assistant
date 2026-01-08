import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/notes_widget_config_cubit.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:obsi/src/screens/settings/settings_controller.dart';

class NotesWidgetConfig extends StatefulWidget {
  const NotesWidgetConfig({super.key});

  @override
  State<NotesWidgetConfig> createState() => _NotesWidgetConfigState();
}

class _NotesWidgetConfigState extends State<NotesWidgetConfig> {
  final List<TextEditingController> _noteControllers = [];
  bool _initializedFromState = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes widget'),
      ),
      body: SafeArea(
        bottom: true,
        child: BlocConsumer<NotesWidgetConfigCubit, NotesWidgetConfigState>(
          listener: (context, state) {
            if (state is NotesWidgetConfigLoaded) {
              if (!_initializedFromState) {
                _noteControllers.clear();
                if (state.notes.isNotEmpty) {
                  for (final n in state.notes) {
                    _noteControllers.add(TextEditingController(text: n));
                  }
                } else {
                  _noteControllers.add(TextEditingController());
                }
                _initializedFromState = true;
              }
            }
          },
          builder: (context, state) {
            if (state is NotesWidgetConfigLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is NotesWidgetConfigError) {
              return Center(child: Text(state.message));
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Notes to show on widget:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter note paths or use variables like {{YYYY-MM-DD}} for dynamic dates.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持的变量: {{YYYY}}, {{MM}}, {{DD}}, {{YYYY-MM-DD}} 等',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ..._noteControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: '{{YYYY-MM-DD}} or daily-note',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.folder_open),
                                  tooltip: '选择文件',
                                  onPressed: () {
                                    _selectNoteFile(context, index);
                                  },
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() {
                                      _noteControllers.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(height: 1),
                            const SizedBox(height: 4),
                          ],
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() {
                              _noteControllers.add(TextEditingController());
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                        onPressed: () {
                          final notesRaw = _noteControllers
                              .map((c) => c.text)
                              .where((t) => t.trim().isNotEmpty)
                              .join(',');
                          context.read<NotesWidgetConfigCubit>().save(
                                context,
                                notesRaw,
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectNoteFile(BuildContext context, int index) async {
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

    final rootDir = Directory(vaultDir);
    if (!rootDir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault directory does not exist.')),
      );
      return;
    }

    final selectedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => SafeArea(
          bottom: true,
          child: FilesystemPicker(
            title: 'Select note file',
            rootDirectory: rootDir,
            fsType: FilesystemType.file,
            pickText: 'Choose note file',
            onSelect: (path) => Navigator.of(ctx).pop(path),
          ),
        ),
      ),
    );

    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }

    final relative = selectedPath.startsWith(vaultDir)
        ? selectedPath
            .substring(vaultDir.length)
            .replaceFirst(RegExp(r'^[/\\]'), '')
        : selectedPath;
    final nameWithoutExt = p.basenameWithoutExtension(relative);

    setState(() {
      if (index >= 0 && index < _noteControllers.length) {
        _noteControllers[index].text = nameWithoutExt;
      }
    });
  }
}
