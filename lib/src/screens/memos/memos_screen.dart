import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/screens/memos/cubit/memos_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/widgets/memo_card.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// The main Memos screen displaying all memos in a microblog-style view.
class MemosScreen extends StatefulWidget {
  const MemosScreen({super.key});

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  late AutoScrollController _scrollController;

  List<DateTime> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
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
              // Calendar navigation button
              IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _showCalendarPicker(context),
                tooltip: 'Jump to date',
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
    _sortedDates = state.groupedMemos.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    return LayoutBuilder(
      builder: (context, constraints) {
        final listHeight = constraints.maxHeight;

        return Stack(
          children: [
            // Main list
            RefreshIndicator(
              onRefresh: () => context.read<MemosCubit>().refresh(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: _sortedDates.length,
                // Use cacheExtent for better scroll performance
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  final date = _sortedDates[index];
                  final memos = state.groupedMemos[date]!;

                  return AutoScrollTag(
                    key: ValueKey(index),
                    controller: _scrollController,
                    index: index,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                              onDelete: () =>
                                  context.read<MemosCubit>().deleteMemo(memo),
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Custom draggable scrollbar
            _DraggableScrollbar(
              controller: _scrollController,
              listHeight: listHeight,
              sortedDates: _sortedDates,
              formatDate: (date) => DateFormat('yyyy/MM/dd').format(date),
            ),
          ],
        );
      },
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

  void _showCalendarPicker(BuildContext context) {
    if (_sortedDates.isEmpty) return;

    final firstDate = _sortedDates.last; // Descending order: last is oldest
    final lastDate = DateTime.now();

    // Create a Set for fast lookup of dates with memos
    final memoDates = _sortedDates.map((d) {
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: TableCalendar(
                        firstDay: firstDate
                            .subtract(const Duration(days: 365)), // Buffer
                        lastDay: lastDate.add(const Duration(days: 365)),
                        focusedDay: lastDate,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        headerStyle: const HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                        ),
                        // Mark days with memos
                        eventLoader: (day) {
                          final normalizeDay =
                              DateTime(day.year, day.month, day.day);
                          return memoDates.contains(normalizeDay) ? [true] : [];
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            if (events.isNotEmpty) {
                              return Positioned(
                                bottom: 1,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          Navigator.pop(context);
                          _scrollToDate(selectedDay);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToDate(DateTime date) {
    if (_sortedDates.isEmpty) return;

    // Find the closest date index
    // Since _sortedDates is DESCENDING (Newest first), we want the first date <= target
    // Actually, simple binary search or linear scan for closest match

    final target = DateTime(date.year, date.month, date.day);

    // Default to index 0 (Newest)
    int targetIndex = 0;

    // Find precise or closest match
    // Just linear scan is fine for user action
    // We look for the first date that is ON or AFTER the target (in time),
    // which means ON or BEFORE in index (since list is desc)?
    // List: [2025, 2024, 2023]. Target: 2024. Index 1.
    // Target 2024-06. List has 2024-05, 2024-07.
    // 2024-07 is index X.

    // Let's us the helper we wrote! Or rewriting it simple here.
    // We want the closest existing date.

    int closestIndex = 0;
    int minDiff = 999999999;

    for (int i = 0; i < _sortedDates.length; i++) {
      final d = _sortedDates[i];
      final normalizeD = DateTime(d.year, d.month, d.day);
      final diff = normalizeD.difference(target).inDays.abs();

      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    targetIndex = closestIndex;

    // Jump with precision using scroll_to_index
    _scrollController.scrollToIndex(
      targetIndex,
      preferPosition: AutoScrollPosition.begin,
      duration: const Duration(milliseconds: 500),
    );
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

/// Custom draggable scrollbar with date indicator
class _DraggableScrollbar extends StatefulWidget {
  final ScrollController controller;
  final double listHeight;
  final List<DateTime> sortedDates;
  final String Function(DateTime) formatDate;

  const _DraggableScrollbar({
    required this.controller,
    required this.listHeight,
    required this.sortedDates,
    required this.formatDate,
  });

  int _findClosestDateIndex(DateTime target) {
    if (sortedDates.isEmpty) return 0;

    // Binary search for closest date
    int min = 0;
    int max = sortedDates.length - 1;

    // Handle descending order detection
    bool isDescending = sortedDates.first.isAfter(sortedDates.last);

    while (min <= max) {
      int mid = min + ((max - min) >> 1);
      DateTime midDate = sortedDates[mid];

      if (midDate.isAtSameMomentAs(target)) return mid;

      bool midIsAfter = midDate.isAfter(target);

      if (isDescending) {
        if (midIsAfter) {
          min = mid +
              1; // Target is later (smaller index in desc) -> Go right? No.
          // Desc: [2025, 2024]. Target 2023.
          // 2025 is after 2023. True.
          // We want 2024 (index 1). So move min up. Correct.
        } else {
          max = mid - 1;
        }
      } else {
        // Ascending: [2023, 2024]. Target 2025.
        // 2023 is before 2025. midIsAfter = False.
        // We want 2024 (index 1). Move min up.
        if (midIsAfter) {
          max = mid - 1;
        } else {
          min = mid + 1;
        }
      }
    }

    // Min is insertion point. Check neighbors.
    if (min >= sortedDates.length) return sortedDates.length - 1;
    if (min <= 0) return 0;

    DateTime a = sortedDates[min - 1];
    DateTime b = sortedDates[min];

    if (target.difference(a).abs() < target.difference(b).abs()) return min - 1;
    return min;
  }

  @override
  State<_DraggableScrollbar> createState() => _DraggableScrollbarState();
}

class _DraggableScrollbarState extends State<_DraggableScrollbar>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _thumbOffset = 0;
  String _currentDate = '';
  double _dragPosition = 0;

  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  static const double _thumbWidth = 6;
  static const double _thumbWidthActive = 24;
  static const double _thumbMinHeight = 48;
  static const double _trackWidthActive = 36;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScrollChanged);

    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScrollChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_isDragging && mounted) {
      _updateThumbPosition();
    }
  }

  void _updateThumbPosition() {
    if (!widget.controller.hasClients) return;

    try {
      final maxScroll = widget.controller.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final scrollRatio = widget.controller.offset / maxScroll;
      final thumbHeight = _calculateThumbHeight();
      final maxThumbOffset = widget.listHeight - thumbHeight;

      setState(() {
        _thumbOffset =
            (scrollRatio * maxThumbOffset).clamp(0.0, maxThumbOffset);
      });
    } catch (e) {
      // Ignore
    }
  }

  double _calculateThumbHeight() {
    if (!widget.controller.hasClients) return _thumbMinHeight;

    try {
      final viewportHeight = widget.controller.position.viewportDimension;
      final contentHeight =
          widget.controller.position.maxScrollExtent + viewportHeight;

      if (contentHeight <= 0) return _thumbMinHeight;

      final ratio = viewportHeight / contentHeight;
      return (ratio * widget.listHeight)
          .clamp(_thumbMinHeight, widget.listHeight / 3);
    } catch (e) {
      return _thumbMinHeight;
    }
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragPosition = details.localPosition.dy.clamp(0.0, widget.listHeight);
    });
    _animController.forward();
    _updateDatePreview(_dragPosition);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition = details.localPosition.dy.clamp(0.0, widget.listHeight);
    });
    // Only update date preview, don't scroll yet
    _updateDatePreview(_dragPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    // Now perform the actual scroll jump
    _performScrollJump();

    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }

  void _updateDatePreview(double position) {
    if (widget.sortedDates.isEmpty) return;

    final ratio = (position / widget.listHeight).clamp(0.0, 1.0);
    final minDate = widget.sortedDates.first;
    final maxDate = widget.sortedDates.last;

    // Linearly interpolate time between min and max date
    final totalDuration = maxDate.difference(minDate).inMilliseconds;
    // Note: if totalDuration is negative (descending), this still works correctly
    final targetTimeMs =
        minDate.millisecondsSinceEpoch + (totalDuration * ratio);
    final targetDate =
        DateTime.fromMillisecondsSinceEpoch(targetTimeMs.round());

    // Find closest existing date
    final index = widget._findClosestDateIndex(targetDate);
    final date = widget.sortedDates[index];

    setState(() {
      // Show the closest ACTUAL date
      _currentDate = widget.formatDate(date);
      // Thumb follows finger
      _thumbOffset =
          position.clamp(0.0, widget.listHeight - _calculateThumbHeight());
    });
  }

  void _performScrollJump() {
    if (widget.sortedDates.isEmpty || !widget.controller.hasClients) return;

    try {
      final ratio = (_dragPosition / widget.listHeight).clamp(0.0, 1.0);
      final minDate = widget.sortedDates.first;
      final maxDate = widget.sortedDates.last;

      final totalDuration = maxDate.difference(minDate).inMilliseconds;
      final targetTimeMs =
          minDate.millisecondsSinceEpoch + (totalDuration * ratio);
      final targetDate =
          DateTime.fromMillisecondsSinceEpoch(targetTimeMs.round());

      final index = widget._findClosestDateIndex(targetDate);

      // Use precision scroll with AutoScrollController
      if (widget.controller is AutoScrollController) {
        (widget.controller as AutoScrollController).scrollToIndex(
          index,
          preferPosition: AutoScrollPosition.begin,
          duration: const Duration(milliseconds: 500),
        );
      } else {
        // Fallback (should not happen in current implementation)
        final scrollRatio = index / (widget.sortedDates.length - 1);
        final maxScroll = widget.controller.position.maxScrollExtent;
        widget.controller.jumpTo(scrollRatio * maxScroll);
      }
    } catch (e) {
      // Ignore
    }
  }

  String get _newestDate => widget.sortedDates.isEmpty
      ? ''
      : widget.formatDate(widget.sortedDates.first);

  String get _oldestDate => widget.sortedDates.isEmpty
      ? ''
      : widget.formatDate(widget.sortedDates.last);

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _calculateThumbHeight();
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          final animValue = _expandAnimation.value;
          final trackWidth =
              _thumbWidth + ((_trackWidthActive - _thumbWidth) * animValue);

          return SizedBox(
            width: trackWidth + 120,
            child: Stack(
              children: [
                // Timeline track background
                if (_isDragging)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: trackWidth,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(trackWidth / 2),
                      ),
                    ),
                  ),

                // Newest date (top)
                if (_isDragging)
                  Positioned(
                    right: trackWidth + 16,
                    top: 4,
                    child:
                        _buildDateLabel(_newestDate, colorScheme, small: true),
                  ),

                // Oldest date (bottom)
                if (_isDragging)
                  Positioned(
                    right: trackWidth + 16,
                    bottom: 4,
                    child:
                        _buildDateLabel(_oldestDate, colorScheme, small: true),
                  ),

                // Current date label (follows finger)
                if (_isDragging && _currentDate.isNotEmpty)
                  Positioned(
                    right: trackWidth + 16,
                    top: (_dragPosition - 16)
                        .clamp(20.0, widget.listHeight - 40),
                    child: _buildDateLabel(_currentDate, colorScheme,
                        small: false),
                  ),

                // Draggable area + thumb
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Container(
                      width: _isDragging ? trackWidth + 16 : 28,
                      color: Colors.transparent,
                      child: Stack(
                        children: [
                          // Normal track
                          if (!_isDragging)
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: _thumbWidth,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                          // Thumb
                          Positioned(
                            right: 8,
                            top:
                                _isDragging ? _dragPosition - 12 : _thumbOffset,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width:
                                  _isDragging ? _thumbWidthActive : _thumbWidth,
                              height:
                                  _isDragging ? _thumbWidthActive : thumbHeight,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(
                                  _isDragging ? _thumbWidthActive / 2 : 3,
                                ),
                                boxShadow: _isDragging
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateLabel(String date, ColorScheme colorScheme,
      {required bool small}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: small
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(-1, 1),
          ),
        ],
      ),
      child: Text(
        date,
        style: TextStyle(
          color: small
              ? colorScheme.onSurfaceVariant
              : colorScheme.onPrimaryContainer,
          fontWeight: small ? FontWeight.normal : FontWeight.bold,
          fontSize: small ? 10 : 12,
        ),
      ),
    );
  }
}
