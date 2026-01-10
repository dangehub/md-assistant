import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/memos/memo.dart';
import 'package:obsi/src/widgets/memo_renderer.dart';

/// A card widget displaying a single memo entry.
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? vaultDirectory;

  const MemoCard({
    super.key,
    required this.memo,
    this.onDelete,
    this.onTap,
    this.onDoubleTap,
    this.vaultDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Date/Time + Actions
              Row(
                children: [
                  // Date and time in purple/primary color
                  Text(
                    _formatDateTime(memo.dateTime),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Action menu
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Content with Markdown rendering
              MemoRenderer(
                content: memo.content,
                vaultDirectory: vaultDirectory,
                baseStyle: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = DateFormat('HH:mm').format(dateTime);

    if (memoDate == today) {
      return 'Today $timeStr';
    } else if (memoDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeStr';
    } else {
      return '${DateFormat('yyyy/MM/dd').format(dateTime)} $timeStr';
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memo'),
        content: const Text('Are you sure you want to delete this memo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
