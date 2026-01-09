import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/screens/memos/cubit/memos_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/widgets/memo_card.dart';

/// The main Memos screen displaying all memos in a microblog-style view.
class MemosScreen extends StatefulWidget {
  const MemosScreen({super.key});

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MemosCubit(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Input area at top
              _buildInputArea(context),
              // Memos list
              Expanded(
                child: BlocBuilder<MemosCubit, MemosState>(
                  builder: (context, state) {
                    if (state is MemosLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is MemosNotConfigured) {
                      return _buildNotConfigured(context);
                    }

                    if (state is MemosError) {
                      return _buildError(context, state.message);
                    }

                    if (state is MemosLoaded) {
                      if (state.memos.isEmpty) {
                        return _buildEmpty(context);
                      }
                      return _buildMemosList(context, state);
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Input field
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              maxLines: null,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '你现在在想什么？',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Action bar
          Row(
            children: [
              // Tag button
              IconButton(
                icon: Icon(
                  Icons.tag,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  // TODO: Tag insertion
                },
                tooltip: 'Add tag',
              ),
              // Attachment button
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  // TODO: Attachment
                },
                tooltip: 'Attach file',
              ),
              const Spacer(),
              // Note button (submit)
              BlocBuilder<MemosCubit, MemosState>(
                builder: (context, state) {
                  return FilledButton(
                    onPressed: () => _submitMemo(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('NOTE'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemosList(BuildContext context, MemosLoaded state) {
    final vaultDir = SettingsController.getInstance().vaultDirectory;
    final sortedDates = state.groupedMemos.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    return RefreshIndicator(
      onRefresh: () => context.read<MemosCubit>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final memos = state.groupedMemos[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Memos for this date
              ...memos.map((memo) => MemoCard(
                    memo: memo,
                    vaultDirectory: vaultDir,
                    onDelete: () => context.read<MemosCubit>().deleteMemo(memo),
                  )),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoDate = DateTime(date.year, date.month, date.day);

    if (memoDate == today) {
      return 'Today';
    } else if (memoDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('yyyy/MM/dd (EEE)').format(date);
    }
  }

  Widget _buildNotConfigured(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Memos not configured',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please configure a memos path in Settings to start using memos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No memos yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start by writing your first memo above!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading memos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.read<MemosCubit>().refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMemo(BuildContext context) async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final cubit = context.read<MemosCubit>();
    final success = await cubit.addMemo(content);

    if (success && mounted) {
      _inputController.clear();
      _inputFocusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memo added'),
          duration: Duration(seconds: 1),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to add memo'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
