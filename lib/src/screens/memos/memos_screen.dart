import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:obsi/src/screens/memos/cubit/memos_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:obsi/src/widgets/memo_card.dart';
import 'package:obsi/src/core/vault_cache_service.dart';
import 'package:obsi/src/core/variable_resolver.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:path/path.dart' as p;
import 'package:obsi/src/core/memos/memo.dart';

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

  // Autocomplete state
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  String _autocompleteType = ''; // 'tag' or 'wiki'
  final GlobalKey _inputFieldKey = GlobalKey();

  List<DateTime> _sortedDates = [];

  // Editing State
  Memo? _editingMemo;
  List<String> _editingImages = [];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
    _inputController.addListener(_extractImagesFromInput);
    _initVaultCache();
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.removeListener(_extractImagesFromInput);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _extractImagesFromInput() {
    if (_editingMemo == null) return;

    final text = _inputController.text;
    final matches = RegExp(r'!\[\[(.*?)\]\]').allMatches(text);
    final images = matches.map((m) {
      final content = m.group(1)!;
      // Handle resizing syntax |size
      final pipeIndex = content.indexOf('|');
      return pipeIndex == -1 ? content : content.substring(0, pipeIndex);
    }).toList();

    if (_editingImages.length != images.length ||
        !_listEquals(_editingImages, images)) {
      setState(() {
        _editingImages = images;
      });
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _enterEditMode(Memo memo) {
    setState(() {
      _editingMemo = memo;
      _inputController.text = memo.content;
      _editingImages = [];
    });
    // Run extraction once immediately
    _extractImagesFromInput();
    _inputFocusNode.requestFocus();
    // Move cursor to end
    _inputController.selection =
        TextSelection.collapsed(offset: memo.content.length);
  }

  void _exitEditMode() {
    setState(() {
      _editingMemo = null;
      _editingImages = [];
      _inputController.clear();
    });
    _inputFocusNode.unfocus();
  }

  Future<void> _deleteImageFile(String imagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
            'Are you sure you want to delete this image? This will permanently delete the file from your vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final settings = SettingsController.getInstance();
      final vaultDir = settings.vaultDirectory;
      if (vaultDir == null) return;

      final file = File(p.join(vaultDir, imagePath));
      if (await file.exists()) {
        try {
          await file.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image deleted')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        }
      }
    }
  }

  void _insertImageLink(String imagePath) {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final insertText = '![[$imagePath]]';

    final newText =
        text.substring(0, cursorPos) + insertText + text.substring(cursorPos);

    _inputController.text = newText;
    _inputController.selection =
        TextSelection.collapsed(offset: cursorPos + insertText.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _initVaultCache() async {
    final settingsController = SettingsController.getInstance();
    final vaultDir = settingsController.vaultDirectory;
    debugPrint('VaultCache: vaultDir = $vaultDir');
    if (vaultDir != null && vaultDir.isNotEmpty) {
      // Force rescan for now to debug
      debugPrint('VaultCache: Scanning vault...');
      await VaultCacheService.instance.scanVault(vaultDir);
      debugPrint(
          'VaultCache: Found ${VaultCacheService.instance.wikiLinks.length} wiki links, ${VaultCacheService.instance.tags.length} tags');
    } else {
      debugPrint('VaultCache: No vault directory configured');
    }
  }

  /// Listen for input changes to update autocomplete suggestions
  void _onInputChanged() {
    final text = _inputController.text;
    final selection = _inputController.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _removeOverlay();
      return;
    }

    final cursorPos = selection.baseOffset;

    // Check if we're inside a tag
    final tagMatch = _findTagAtCursor(text, cursorPos);
    if (tagMatch != null) {
      _showSuggestions(tagMatch, 'tag');
      return;
    }

    // Check if we're inside a wiki link
    final wikiMatch = _findWikiLinkAtCursor(text, cursorPos);
    if (wikiMatch != null) {
      _showSuggestions(wikiMatch, 'wiki');
      return;
    }

    _removeOverlay();
  }

  /// Find tag pattern at cursor position
  String? _findTagAtCursor(String text, int cursorPos) {
    // Look backwards for #
    int start = cursorPos - 1;
    while (start >= 0 &&
        text[start] != '#' &&
        text[start] != ' ' &&
        text[start] != '\n') {
      start--;
    }
    if (start >= 0 && text[start] == '#') {
      return text.substring(start + 1, cursorPos);
    }
    return null;
  }

  /// Find wiki link pattern at cursor position
  String? _findWikiLinkAtCursor(String text, int cursorPos) {
    // Look for [[ before cursor
    int start = cursorPos - 1;
    while (start >= 1) {
      if (text[start] == '[' && text[start - 1] == '[') {
        // Check there's no ]] between start and cursor
        final substr = text.substring(start + 1, cursorPos);
        if (!substr.contains(']]')) {
          return substr;
        }
        break;
      }
      if (text[start] == ']') break; // Found closing bracket, not inside link
      start--;
    }
    return null;
  }

  /// Show autocomplete suggestions overlay
  void _showSuggestions(String query, String type) {
    _autocompleteType = type;

    if (type == 'tag') {
      _suggestions = VaultCacheService.instance.searchTags(query, limit: 5);
    } else {
      _suggestions =
          VaultCacheService.instance.searchWikiLinks(query, limit: 5);
    }

    if (_suggestions.isEmpty) {
      _removeOverlay();
      return;
    }

    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Remove the overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Create the overlay entry for suggestions
  OverlayEntry _createOverlayEntry() {
    final renderBox =
        _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 12,
        top: offset.dy + size.height + 4,
        width: size.width - 24,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    _autocompleteType == 'tag'
                        ? '#$suggestion'
                        : '[[$suggestion]]',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onTap: () => _applySuggestion(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Apply the selected suggestion
  void _applySuggestion(String suggestion) {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final cursorPos = selection.baseOffset;

    String newText;
    int newCursorPos;

    if (_autocompleteType == 'tag') {
      // Find start of tag
      int start = cursorPos - 1;
      while (start >= 0 && text[start] != '#') {
        start--;
      }
      newText =
          text.substring(0, start + 1) + suggestion + text.substring(cursorPos);
      newCursorPos = start + 1 + suggestion.length;

      // Record usage
      VaultCacheService.instance.recordTagUsage(suggestion);
    } else {
      // Find start of wiki link
      int start = cursorPos - 1;
      while (start >= 1 && !(text[start] == '[' && text[start - 1] == '[')) {
        start--;
      }
      // Check if there's already a closing ]]
      int end = cursorPos;
      if (end + 1 < text.length && text[end] == ']' && text[end + 1] == ']') {
        newText =
            text.substring(0, start + 1) + suggestion + text.substring(end);
      } else {
        newText = text.substring(0, start + 1) +
            suggestion +
            ']]' +
            text.substring(cursorPos);
      }
      newCursorPos = start + 1 + suggestion.length + 2;

      // Record usage
      VaultCacheService.instance.recordWikiLinkUsage(suggestion);
    }

    _inputController.text = newText;
    _inputController.selection = TextSelection.collapsed(offset: newCursorPos);
    _removeOverlay();
  }

  /// Insert # at cursor and show tag suggestions
  void _insertTagSymbol() {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final newText =
        text.substring(0, cursorPos) + '#' + text.substring(cursorPos);
    _inputController.text = newText;
    _inputController.selection = TextSelection.collapsed(offset: cursorPos + 1);
    _inputFocusNode.requestFocus();

    // Show recent tags immediately
    _showSuggestions('', 'tag');
  }

  /// Insert [[]] at cursor and show wiki link suggestions
  void _insertWikiLink() {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final cursorPos = selection.isValid ? selection.baseOffset : text.length;

    final newText =
        text.substring(0, cursorPos) + '[[]]' + text.substring(cursorPos);
    _inputController.text = newText;
    _inputController.selection =
        TextSelection.collapsed(offset: cursorPos + 2); // Cursor inside [[|]]
    _inputFocusNode.requestFocus();

    // Show recent wiki links immediately
    _showSuggestions('', 'wiki');
  }

  /// Pick an image and insert it as attachment
  Future<void> _pickAndInsertAttachment(BuildContext context) async {
    final settingsService = SettingsService();
    final attachmentDir = await settingsService.memosAttachmentDirectory();

    // Check if attachment directory is configured
    if (attachmentDir == null || attachmentDir.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先在设置中配置 Memos 附件目录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Get vault directory
    final settingsController = SettingsController.getInstance();
    final vaultDir = settingsController.vaultDirectory;
    if (vaultDir == null || vaultDir.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先配置 Vault 目录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Pick image
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    try {
      // Resolve attachment directory with variables
      final resolvedDir = VariableResolver.resolve(attachmentDir);
      final targetDirPath = p.join(vaultDir, resolvedDir);

      // Create directory if it doesn't exist
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Check compression settings
      final compressEnabled = await settingsService.imageCompressionEnabled();
      final compressQuality = await settingsService.imageCompressionQuality();
      final compressFormatStr = await settingsService.imageCompressionFormat();

      // Generate unique filename and determine format
      final originalName = p.basename(pickedFile.path);
      var extension = p.extension(originalName);

      CompressFormat? targetFormat;
      if (compressEnabled) {
        if (compressFormatStr == 'webp') {
          targetFormat = CompressFormat.webp;
          extension = '.webp';
        } else if (compressFormatStr == 'jpeg') {
          targetFormat = CompressFormat.jpeg;
          extension = '.jpg';
        } else if (compressFormatStr == 'png') {
          targetFormat = CompressFormat.png;
          extension = '.png';
        }
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final newFileName = 'attachment_$timestamp$extension';
      final targetPath = p.join(targetDirPath, newFileName);

      // Compress or Copy file
      if (compressEnabled && targetFormat != null) {
        final result = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          quality: compressQuality,
          format: targetFormat,
        );
        if (result == null) throw Exception("Image compression failed");
      } else {
        final File sourceFile = File(pickedFile.path);
        await sourceFile.copy(targetPath);
      }

      // Insert markdown at cursor
      final text = _inputController.text;
      final selection = _inputController.selection;
      final cursorPos = selection.isValid ? selection.baseOffset : text.length;

      final insertText = '![[${p.join(resolvedDir, newFileName)}]]';
      final newText =
          text.substring(0, cursorPos) + insertText + text.substring(cursorPos);
      _inputController.text = newText;
      _inputController.selection =
          TextSelection.collapsed(offset: cursorPos + insertText.length);
      _inputFocusNode.requestFocus();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('附件已保存到: $resolvedDir'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存附件失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      key: _inputFieldKey,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editing Indicator
          if (_editingMemo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit,
                      size: 14, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Text(
                    '正在编辑 ${_formatDateTime(_editingMemo!.dateTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _exitEditMode,
                    child: Icon(Icons.close,
                        size: 16, color: colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),

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
                hintText: _editingMemo != null ? '修改内容...' : '你现在在想什么？',
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

          // Thumbnails Panel (Only in Edit Mode)
          if (_editingMemo != null && _editingImages.isNotEmpty)
            Container(
              height: 60,
              margin: const EdgeInsets.only(top: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _editingImages.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (ctx, index) {
                  final path = _editingImages[index];
                  final vaultDir =
                      SettingsController.getInstance().vaultDirectory;
                  return Stack(
                    children: [
                      InkWell(
                        onTap: () => _insertImageLink(path),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: vaultDir != null
                              ? Image.file(
                                  File(p.join(vaultDir, path)),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.image),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _deleteImageFile(path),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Action bar
          Row(
            children: [
              // Tag button (#)
              IconButton(
                icon: Icon(
                  Icons.tag,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: _insertTagSymbol,
                tooltip: '插入标签 #',
              ),
              // Wiki link button ([[]])
              IconButton(
                icon: Icon(
                  Icons.link,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: _insertWikiLink,
                tooltip: '插入链接 [[]]',
              ),
              // Attachment button
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _pickAndInsertAttachment(context),
                tooltip: '添加附件',
              ),
              // Calendar navigation button
              IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _showCalendarPicker(context),
                tooltip: '跳转到日期',
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
                      backgroundColor: _editingMemo != null
                          ? colorScheme.tertiary
                          : colorScheme.primary,
                    ),
                    child: Text(_editingMemo != null ? 'UPDATE' : 'NOTE'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
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
                            onDoubleTap: () => _enterEditMode(memo),
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

    if (_editingMemo != null) {
      // Update existing
      final success = await cubit.updateMemo(_editingMemo!, content);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memo updated'),
            duration: Duration(seconds: 1),
          ),
        );
        _exitEditMode();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update memo'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      // Add new
      final success = await cubit.addMemo(content);

      if (success && mounted) {
        _inputController.clear();
        _inputFocusNode.unfocus();

        // Scroll to top
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

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
} // End of _MemosScreenState

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
