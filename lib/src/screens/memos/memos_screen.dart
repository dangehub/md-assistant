import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/screens/memos/cubit/memos_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/widgets/memo_card.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// The main Memos screen displaying all memos in a microblog-style view.
class MemosScreen extends StatefulWidget {
  const MemosScreen({super.key});

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  List<DateTime> _sortedDates = [];

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
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: _sortedDates.length,
                itemBuilder: (context, index) {
                  final date = _sortedDates[index];
                  final memos = state.groupedMemos[date]!;

                  return Column(
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
                  );
                },
              ),
            ),
            // Custom draggable scrollbar
            _DraggableScrollbar(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
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

    DateTime initialFocusedDay = DateTime.now();

    // Sync calendar with current viewport
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      // Find the top-most visible item (smallest index)
      final minIndex = positions
          .where(
              (p) => p.itemTrailingEdge > 0) // Ensure item is somewhat visible
          .fold(999999, (prev, p) => p.index < prev ? p.index : prev);

      if (minIndex < _sortedDates.length && minIndex >= 0) {
        initialFocusedDay = _sortedDates[minIndex];
      } else {
        initialFocusedDay = _sortedDates.first;
      }
    } else {
      initialFocusedDay = _sortedDates.first;
    }

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
        return _MemosCalendarPicker(
          firstDate: firstDate.subtract(const Duration(days: 365)), // Buffer
          lastDate: lastDate.add(const Duration(days: 365)),
          initialFocusedDay: initialFocusedDay,
          memoDates: memoDates,
          onDateSelected: (selectedDay) {
            Navigator.pop(context);
            _scrollToDate(selectedDay);
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

    // Virtual jump (instant)
    _itemScrollController.jumpTo(index: targetIndex);
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

/// A stateful calendar picker that supports year/month jumping and "back to today".
class _MemosCalendarPicker extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialFocusedDay;
  final Set<DateTime> memoDates;
  final ValueChanged<DateTime> onDateSelected;

  const _MemosCalendarPicker({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.initialFocusedDay,
    required this.memoDates,
    required this.onDateSelected,
  });

  @override
  State<_MemosCalendarPicker> createState() => _MemosCalendarPickerState();
}

class _MemosCalendarPickerState extends State<_MemosCalendarPicker> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialFocusedDay;
  }

  void _jumpToToday() {
    setState(() {
      _focusedDay = DateTime.now();
    });
  }

  Future<void> _selectYearMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _YearMonthPicker(
        initialDate: _focusedDay,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _focusedDay = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Calendar Header Extras (Today Button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _jumpToToday,
                      icon: const Icon(Icons.today, size: 16),
                      label: const Text('Today'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: TableCalendar(
                    firstDay: widget.firstDate,
                    lastDay: widget.lastDate,
                    focusedDay: _focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    onHeaderTapped: (_) => _selectYearMonth(),
                    // Custom Header to include Dropdown Arrow
                    calendarBuilders: CalendarBuilders(
                      headerTitleBuilder: (context, day) {
                        return Center(
                          child: InkWell(
                            onTap: _selectYearMonth,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.yMMMM().format(day),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 18),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      markerBuilder: (context, day, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    // Mark days with memos
                    eventLoader: (day) {
                      final normalizeDay =
                          DateTime(day.year, day.month, day.day);
                      return widget.memoDates.contains(normalizeDay)
                          ? [true]
                          : [];
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      widget.onDateSelected(selectedDay);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A custom dialog for selecting Year and Month.
class _YearMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _YearMonthPicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
    final months = List.generate(12, (index) => index + 1);

    return AlertDialog(
      title: const Text('Select Month'),
      content: SizedBox(
        height: 200,
        child: Row(
          children: [
            // Year Column
            Expanded(
              child: Column(
                children: [
                  Text('Year', style: theme.textTheme.labelMedium),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      controller: FixedExtentScrollController(
                        initialItem: years.indexOf(_selectedYear),
                      ),
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedYear = years[index];
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) {
                          final year = years[index];
                          final isSelected = year == _selectedYear;
                          return Center(
                            child: Text(
                              year.toString(),
                              style: isSelected
                                  ? theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold)
                                  : theme.textTheme.bodyLarge,
                            ),
                          );
                        },
                        childCount: years.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Month Column
            Expanded(
              child: Column(
                children: [
                  Text('Month', style: theme.textTheme.labelMedium),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      controller: FixedExtentScrollController(
                        initialItem: _selectedMonth - 1,
                      ),
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedMonth = months[index];
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) {
                          final month = months[index];
                          final isSelected = month == _selectedMonth;
                          return Center(
                            child: Text(
                              DateFormat.MMM().format(DateTime(2024, month)),
                              style: isSelected
                                  ? theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold)
                                  : theme.textTheme.bodyLarge,
                            ),
                          );
                        },
                        childCount: months.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(_selectedYear, _selectedMonth),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Custom draggable scrollbar with date indicator
class _DraggableScrollbar extends StatefulWidget {
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final double listHeight;
  final List<DateTime> sortedDates;
  final String Function(DateTime) formatDate;

  const _DraggableScrollbar({
    required this.itemScrollController,
    required this.itemPositionsListener,
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
          min = mid + 1;
        } else {
          max = mid - 1;
        }
      } else {
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
  double _thumbOffset = 0.0;
  String _currentDate = '';
  double _dragPosition = 0.0; // Current user touch position

  // Animation for thumb expansion
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  // Constants
  static const double _thumbWidth = 6.0;
  static const double _thumbWidthDragging = 24.0;

  static const double _thumbMinHeight =
      40.0; // Fixed thumb height for virtual scrolling
  static const double _trackWidthActive = 24.0;
  static const double _scrollbarPadding = 2.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _expandAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    widget.itemPositionsListener.itemPositions.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    widget.itemPositionsListener.itemPositions.removeListener(_onScrollChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_isDragging && mounted && widget.sortedDates.isNotEmpty) {
      _updateThumbPosition();
    }
  }

  void _updateThumbPosition() {
    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Find the first visible item
    final minIndex = positions
        .where((p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0)
        .fold(999999, (prev, p) => p.index < prev ? p.index : prev);

    if (minIndex >= widget.sortedDates.length) return;

    // Map Index -> Date -> Time Ratio -> Thumb Pixel
    final currentDate = widget.sortedDates[minIndex];
    final minDate = widget.sortedDates.first;
    final maxDate = widget.sortedDates.last;

    final totalDuration = maxDate.difference(minDate).inMilliseconds.abs();
    if (totalDuration == 0) return;

    final currentDuration =
        currentDate.difference(minDate).inMilliseconds.abs();
    final timeRatio = currentDuration / totalDuration;

    final trackHeight =
        widget.listHeight - _thumbMinHeight - (_scrollbarPadding * 2);

    setState(() {
      _thumbOffset = (timeRatio * trackHeight).clamp(0.0, trackHeight);
    });
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

    final totalDuration = maxDate.difference(minDate).inMilliseconds;
    final targetTimeMs =
        minDate.millisecondsSinceEpoch + (totalDuration * ratio);
    final targetDate =
        DateTime.fromMillisecondsSinceEpoch(targetTimeMs.round());

    final index = widget._findClosestDateIndex(targetDate);
    final date = widget.sortedDates[index];

    setState(() {
      _currentDate = widget.formatDate(date);
      // Thumb follows finger
      _thumbOffset = position.clamp(0.0, widget.listHeight - _thumbMinHeight);
    });
  }

  void _performScrollJump() {
    if (widget.sortedDates.isEmpty) return;

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

      // Virtual jump (instant)
      widget.itemScrollController.jumpTo(index: index);
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
    // Fixed thumb height used for calculations
    const thumbHeight = _thumbMinHeight;
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
                    // Use thumbOffset directly or dragPosition
                    // dragPosition matches finger, thumbOffset is constrained
                    // Use dragPosition for label to be exactly at finger
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
                  width: 50, // Increase touch area width
                  child: GestureDetector(
                    behavior: HitTestBehavior
                        .translucent, // Capture drags even on transparent
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Stack(
                      children: [
                        // Thumb
                        Positioned(
                          right: 8,
                          top: _thumbOffset,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width:
                                _isDragging ? _thumbWidthDragging : _thumbWidth,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: _isDragging
                                  ? colorScheme.primary
                                  : colorScheme.primary.withOpacity(0.6),
                              borderRadius:
                                  BorderRadius.circular(thumbHeight / 2),
                            ),
                          ),
                        ),
                      ],
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
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(-2, 2),
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
