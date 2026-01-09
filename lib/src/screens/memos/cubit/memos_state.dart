part of 'memos_cubit.dart';

abstract class MemosState {}

class MemosLoading extends MemosState {}

class MemosLoaded extends MemosState {
  final List<Memo> memos;
  final Map<DateTime, List<Memo>> groupedMemos;

  MemosLoaded({required this.memos, required this.groupedMemos});

  MemosLoaded copyWith({
    List<Memo>? memos,
    Map<DateTime, List<Memo>>? groupedMemos,
  }) {
    return MemosLoaded(
      memos: memos ?? this.memos,
      groupedMemos: groupedMemos ?? this.groupedMemos,
    );
  }
}

class MemosError extends MemosState {
  final String message;

  MemosError(this.message);
}

class MemosNotConfigured extends MemosState {}
