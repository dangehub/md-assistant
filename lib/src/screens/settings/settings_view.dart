import 'dart:io';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:obsi/src/core/utils.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';

import 'settings_controller.dart';
import 'settings_service.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _dateTemplateController = TextEditingController();
  final _tasksFileNameController = TextEditingController();
  final _globalTaskFilterController = TextEditingController();
  final _aiBaseUrlController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelNameController = TextEditingController();
  final _memosPathController = TextEditingController();
  final _memosAttachmentDirController = TextEditingController();

  @override
  void initState() {
    _dateTemplateController.text = widget.controller.dateTemplate;
    _tasksFileNameController.text = widget.controller.tasksFile;
    _globalTaskFilterController.text = widget.controller.globalTaskFilter;
    _aiBaseUrlController.text = widget.controller.aiBaseUrl ?? "";
    _aiApiKeyController.text = widget.controller.chatGptKey ?? "";
    _aiModelNameController.text = widget.controller.aiModelName ?? "";
    _memosPathController.text = widget.controller.memosPath ?? "";
    _loadMemosAttachmentDir();

    _dateTemplateController.addListener(() {
      widget.controller.updateDateTemplate(_dateTemplateController.text);
    });

    // Listen to controller changes and rebuild UI when needed
    widget.controller.addListener(_onControllerChanged);

    super.initState();
  }

  void _onControllerChanged() {
    setState(() {
      // Trigger rebuild when controller notifies changes
    });
  }

  Future<void> _loadMemosAttachmentDir() async {
    final service = SettingsService();
    final dir = await service.memosAttachmentDirectory();
    _memosAttachmentDirController.text = dir ?? "";
  }

  Future<void> _saveMemosAttachmentDir(String value) async {
    final service = SettingsService();
    await service.updateMemosAttachmentDirectory(value);
  }

  @override
  void dispose() {
    _tasksFileNameController.dispose();
    _dateTemplateController.dispose();
    _globalTaskFilterController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelNameController.dispose();
    _memosPathController.dispose();
    _memosAttachmentDirController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(children: [
          // Padding(
          //   padding: const EdgeInsets.all(16),
          //   // Glue the SettingsController to the theme selection DropdownButton.
          //   //
          //   // When a user selects a theme from the dropdown list, the
          //   // SettingsController is updated, which rebuilds the MaterialApp.
          //   child: DropdownButton<ThemeMode>(
          //     // Read the selected themeMode from the controller
          //     value: widget.controller.themeMode,
          //     // Call the updateThemeMode method any time the user selects a theme.
          //     onChanged: widget.controller.updateThemeMode,
          //     items: const [
          //       DropdownMenuItem(
          //         value: ThemeMode.system,
          //         child: Text('System Theme'),
          //       ),
          //       DropdownMenuItem(
          //         value: ThemeMode.light,
          //         child: Text('Light Theme'),
          //       ),
          //       DropdownMenuItem(
          //         value: ThemeMode.dark,
          //         child: Text('Dark Theme'),
          //       )
          //     ],
          //   ),
          // ),

          // Padding(
          //     padding: const EdgeInsets.all(16),
          //     child: Column(children: [
          //       const Align(
          //           alignment: Alignment.centerLeft,
          //           child: Text("Date format used in Obsidian: ")),
          //       TextField(
          //         controller: _dateTemplateController,
          //       )
          //     ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        "File name for adding new tasks (located at the path below):")),
                TextField(
                  controller: _tasksFileNameController,
                  onSubmitted: (value) {
                    widget.controller.updateTasksFile(value);
                  },
                )
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Global Task Filter: ")),
                TextField(
                  controller: _globalTaskFilterController,
                  decoration: const InputDecoration(
                    hintText: "Enter a global task filter, e.g. #task",
                  ),
                  onSubmitted: (value) {
                    widget.controller.updateGlobalTaskFilter(value);
                  },
                )
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AI Assistant Settings",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text("Base URL (e.g. https://api.openai.com/v1):"),
                    TextField(
                      controller: _aiBaseUrlController,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: "Enter base URL (optional)",
                      ),
                      onSubmitted: (value) {
                        widget.controller.updateAiBaseUrl(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("API Key:"),
                    TextField(
                      controller: _aiApiKeyController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: "Enter API Key",
                      ),
                      onSubmitted: (value) {
                        widget.controller.updateChatGptKey(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Model Name (e.g. gpt-4o):"),
                    TextField(
                      controller: _aiModelNameController,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: "Enter model name",
                      ),
                      onSubmitted: (value) {
                        widget.controller.updateAiModelName(value);
                      },
                    )
                  ])),
          // Memos Settings Section
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Memos Settings",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text("Memos Path:"),
                    const SizedBox(height: 4),
                    Text(
                      "Static path (e.g., memos.md) or dynamic path with date variables (e.g., {{YYYY}}/{{YYYY-MM-DD}}.md)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _memosPathController,
                      decoration: const InputDecoration(
                        hintText: "Enter memos path or template",
                      ),
                      onSubmitted: (value) {
                        widget.controller.updateMemosPath(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Dynamic Path:"),
                              const SizedBox(height: 4),
                              Text(
                                "Enable if path contains date variables like {{YYYY-MM-DD}}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: widget.controller.memosPathIsDynamic,
                          onChanged: (value) {
                            widget.controller.updateMemosPathIsDynamic(value);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Widget Sort Order:"),
                              const SizedBox(height: 4),
                              Text(
                                "Ascending shows oldest memos first; Descending shows newest first",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text("Asc"),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text("Desc"),
                            ),
                          ],
                          selected: {
                            widget.controller.memosWidgetSortAscending
                          },
                          onSelectionChanged: (selected) {
                            widget.controller
                                .updateMemosWidgetSortAscending(selected.first);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("附件目录 (Attachment Directory):"),
                    const SizedBox(height: 4),
                    Text(
                      "相对于 Vault 的路径，支持日期变量。例如: assets 或 {{YYYY}}/assets",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _memosAttachmentDirController,
                      decoration: const InputDecoration(
                        hintText: "例如: assets 或 {{YYYY}}/assets",
                      ),
                      onSubmitted: (value) {
                        _saveMemosAttachmentDir(value);
                      },
                    ),
                  ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Include tasks with today due day:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Show tasks that are due today in the 'Today' view",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: widget.controller.includeDueTasksInToday,
                      onChanged: (value) {
                        widget.controller.updateIncludeDueTasksInToday(value);
                        setState(() {
                          // Trigger UI rebuild after setting update
                        });
                      },
                    ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Show on-boarding screen:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Enable to show the on-boarding screen when the app starts",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: !widget.controller.onboardingComplete,
                      onChanged: (value) {
                        widget.controller.updateOnboardingComplete(!value);
                        setState(() {
                          // Trigger UI rebuild after setting update
                        });
                      },
                    ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Daily reminder to review tasks:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Time: "),
                    addDateTimePicker(
                      widget.controller.reviewTasksReminderTime != null
                          ? Text(
                              DateFormat('HH:mm').format(
                                  widget.controller.reviewTasksReminderTime!),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(
                              'Not set',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                      widget.controller.reviewTasksReminderTime ??
                          DateTime.now(),
                      context,
                      (time) {
                        widget.controller.updateReviewTasksReminderTime(time);
                        setState(() {
                          // Trigger UI rebuild after time update
                        });
                      },
                      timePicker: true,
                    ),
                    if (widget.controller.reviewTasksReminderTime != null)
                      IconButton(
                        onPressed: () {
                          widget.controller.updateReviewTasksReminderTime(null);
                          setState(() {
                            // Trigger UI rebuild after clearing time
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear reminder',
                      ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Daily reminder to review completed tasks:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Time: "),
                    addDateTimePicker(
                      widget.controller.reviewCompletedReminderTime != null
                          ? Text(
                              DateFormat('HH:mm').format(widget
                                  .controller.reviewCompletedReminderTime!),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(
                              'Not set',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                      widget.controller.reviewCompletedReminderTime ??
                          DateTime.now(),
                      context,
                      (time) {
                        widget.controller
                            .updateReviewCompletedReminderTime(time);
                        setState(() {
                          // Trigger UI rebuild after time update
                        });
                      },
                      timePicker: true,
                    ),
                    if (widget.controller.reviewCompletedReminderTime != null)
                      IconButton(
                        onPressed: () {
                          widget.controller
                              .updateReviewCompletedReminderTime(null);
                          setState(() {
                            // Trigger UI rebuild after clearing time
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear reminder',
                      ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            "Folder in the Obsidian vault containing tasks:"))),
                Text(widget.controller.vaultDirectory ??
                    "<Please choose the folder>")
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                  child: const Text("Select"),
                  onPressed: () async {
                    var vaultDirectory =
                        await SettingsController.selectVaultDirectory(context);

                    if (vaultDirectory != null) {
                      widget.controller.updateVaultDirectory(vaultDirectory);
                    }
                  })),

          // Subscription Section
          Platform.isIOS
              ? SizedBox()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        widget.controller.hasActiveSubscription
                            ? Icons.star
                            : Icons.star_border,
                        color: widget.controller.hasActiveSubscription
                            ? Colors.amber
                            : Colors.grey,
                      ),
                      title: Text(
                        widget.controller.hasActiveSubscription
                            ? 'Premium Active'
                            : 'Upgrade to Premium',
                      ),
                      subtitle: Text(
                        widget.controller.hasActiveSubscription
                            ? 'Manage your subscription'
                            : 'Unlock all features',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          SubscriptionScreen.routeName,
                          arguments: widget.controller,
                        );
                      },
                    ),
                  ),
                ),

          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text("Contact the developer:"),
                GestureDetector(
                  onTap: () {
                    _launchEmail(context);
                  },
                  child: const Text("support@mdbro.app",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      )),
                )
              ])),

          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const SizedBox(height: 1),
                FutureBuilder<String>(
                  future: widget.controller.getAppVersion(),
                  builder: (context, snapshot) {
                    return Text(
                      'Version: ${snapshot.data ?? 'Loading...'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ])),
        ]),
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: "support@mdbro.app",
      query: 'subject=MD Bro', // Optional query parameters
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $emailUri')),
      );
    }
  }
}
