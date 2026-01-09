import 'package:bloc/bloc.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/memos/memo.dart';
import 'package:obsi/src/core/memos/memo_parser.dart';
import 'package:obsi/src/core/memos/memo_writer.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

part 'memos_state.dart';

/// Cubit for managing the Memos screen state.
class MemosCubit extends Cubit<MemosState> {
  final _logger = Logger();

  MemosCubit() : super(MemosLoading()) {
    loadMemos();
  }

  /// Load all memos from the configured path.
  Future<void> loadMemos() async {
    emit(MemosLoading());

    try {
      final settings = SettingsController.getInstance();
      final vaultDir = settings.vaultDirectory;
      final memosPath = settings.memosPath;

      if (vaultDir == null || vaultDir.isEmpty) {
        emit(MemosNotConfigured());
        return;
      }

      if (memosPath == null || memosPath.isEmpty) {
        emit(MemosNotConfigured());
        return;
      }

      final isDynamic = settings.memosPathIsDynamic;

      _logger.d('=== MEMOS DEBUG ===');
      _logger.d('Vault Directory: $vaultDir');
      _logger.d('Memos Path: $memosPath');
      _logger.d('Is Dynamic: $isDynamic');

      final memos = await MemoParser.parseAll(
        vaultDir: vaultDir,
        memosPath: memosPath,
        isDynamic: isDynamic,
      );

      _logger.d('Parsed ${memos.length} memos');
      if (memos.isNotEmpty) {
        _logger.d('First memo: ${memos.first}');
      }
      _logger.i('Loaded ${memos.length} memos');

      // Group by date (already sorted descending from parser)
      final groupedMemos = <DateTime, List<Memo>>{};
      for (final memo in memos) {
        final dateKey = memo.date;
        groupedMemos.putIfAbsent(dateKey, () => []).add(memo);
      }

      emit(MemosLoaded(memos: memos, groupedMemos: groupedMemos));
    } catch (e) {
      _logger.e('Error loading memos: $e');
      emit(MemosError('Failed to load memos: $e'));
    }
  }

  /// Add a new memo with the current timestamp.
  Future<bool> addMemo(String content) async {
    if (content.trim().isEmpty) return false;

    try {
      final settings = SettingsController.getInstance();
      final vaultDir = settings.vaultDirectory;
      final memosPath = settings.memosPath;

      if (vaultDir == null || memosPath == null) {
        _logger.w('Cannot add memo: vault or memos path not configured');
        return false;
      }

      final isDynamic = settings.memosPathIsDynamic;

      final success = await MemoWriter.writeMemo(
        vaultDir: vaultDir,
        memosPath: memosPath,
        isDynamic: isDynamic,
        content: content.trim(),
      );

      if (success) {
        // Reload memos to reflect the new addition
        await loadMemos();
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error adding memo: $e');
      return false;
    }
  }

  /// Delete a memo by its source location.
  Future<bool> deleteMemo(Memo memo) async {
    if (memo.sourcePath == null || memo.lineNumber == null) {
      _logger.w('Cannot delete memo: missing source info');
      return false;
    }

    try {
      final success = await MemoWriter.deleteMemo(
        memo.sourcePath!,
        memo.lineNumber!,
      );

      if (success) {
        // Reload memos to reflect the deletion
        await loadMemos();
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error deleting memo: $e');
      return false;
    }
  }

  /// Refresh memos from disk.
  Future<void> refresh() async {
    await loadMemos();
  }
}
