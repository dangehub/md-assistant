part of 'notes_widget_config_cubit.dart';

abstract class NotesWidgetConfigState {}

class NotesWidgetConfigLoading extends NotesWidgetConfigState {}

class NotesWidgetConfigLoaded extends NotesWidgetConfigState {
  final List<String> notes;

  NotesWidgetConfigLoaded({
    required this.notes,
  });

  NotesWidgetConfigLoaded copyWith({
    String? vaultDirectory,
    String? vaultName,
    List<String>? notes,
  }) {
    return NotesWidgetConfigLoaded(
      notes: notes ?? this.notes,
    );
  }
}

class NotesWidgetConfigError extends NotesWidgetConfigState {
  final String message;

  NotesWidgetConfigError(this.message);
}
