import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'ansi_parser.dart';

ListQueue<OutputEvent> _outputEventBuffer = ListQueue();
bool _initialized = false;
String _titleText = "Log Console";
String _verboseText = "Verbose";
String _debugText = "Debug";
String _filterText = "Filter log message";
String _infoText = "Info";
String _warningText = "Warning";
String _errorText = "Error";
String _wtfText = "Fatal";
String _refreshText = "Refresh";
String _saveText = "Save";
String _shareText = "Share";

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;
  final bool showRefreshButton;
  final String? title;
  final String? subtitle;
  final Future<ListQueue<OutputEvent>> Function()? getLogOutputEvents;
  final void Function(void Function())? listenToUpdateTrigger;
  final void Function()? saveFile;
  final void Function()? shareFile;

  LogConsole({
    super.key,
    this.dark = false,
    this.title,
    this.subtitle,
    this.showCloseButton = false,
    this.showRefreshButton = false,
    this.getLogOutputEvents,
    this.listenToUpdateTrigger,
    this.saveFile,
    this.shareFile,
  }) : assert(_initialized, "Please call LogConsole.init() first.");

  static void init({int bufferSize = 20}) {
    if (_initialized) return;
    _initialized = true;
  }

  static void setLocalTexts({
    String? titleText,
    String? verboseText,
    String? debugText,
    String? filterText,
    String? infoText,
    String? warningText,
    String? errorText,
    String? wtfText,
    String? refreshText,
    String? saveText,
    String? shareText,
  }) {
    if (titleText != null) _titleText = titleText;
    if (filterText != null) _filterText = filterText;
    if (debugText != null) _debugText = debugText;
    if (verboseText != null) _verboseText = verboseText;
    if (infoText != null) _infoText = infoText;
    if (warningText != null) _warningText = warningText;
    if (errorText != null) _errorText = errorText;
    if (wtfText != null) _wtfText = wtfText;
    if (refreshText != null) _refreshText = refreshText;
    if (saveText != null) _saveText = saveText;
    if (shareText != null) _shareText = shareText;
  }

  static void setLogOutput(MemoryOutput logOutput) {
    _outputEventBuffer = logOutput.buffer;
  }

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;

  RenderedEvent(this.id, this.level, this.span, this.lowerCaseText);
}

class _LogConsoleState extends State<LogConsole> {
  final ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];
  final _logContentFocusNode = FocusNode();
  var _savedPosition = Offset(100, 100);
  static const int _pageSize = 1000;
  List<OutputEvent> _allEvents = [];
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _isLoadingPrevious = false;
  bool _hasMorePrevious = true;
  bool _hasMoreNext = true;
  bool _isSelectionMode = false;
  final Set<int> _selectedLogIds = {};

  final _scrollController = ScrollController();
  final _filterController = TextEditingController();

  Level _filterLevel = Level.trace;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _followBottom = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      // Handle scroll position changes
      if (_scrollController.offset <= 0 &&
          !_isLoadingPrevious &&
          _hasMorePrevious) {
        _loadPreviousLogs();
      }

      if (_scrollController.offset >=
              _scrollController.position.maxScrollExtent &&
          !_isLoadingMore &&
          _hasMoreNext) {
        _loadNextLogs();
      }

      // Handle follow bottom
      var scrolledToBottom = _scrollController.offset >=
          (_scrollController.position.maxScrollExtent - 20);
      setState(() {
        _followBottom = !scrolledToBottom;
      });
    });

    final listen = widget.listenToUpdateTrigger;
    if (listen != null) {
      listen(() {
        didChangeDependencies();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterController.dispose();
    _logContentFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    setState(() {
      _isLoading = true;
    });

    try {
      final getEventsF = widget.getLogOutputEvents;
      if (getEventsF != null) {
        final events = await getEventsF();
        _allEvents = events.toList();
      } else {
        _allEvents = _outputEventBuffer.toList();
      }
      _loadCurrentPage();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCurrentPage() {
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex >= _allEvents.length) {
      _hasMoreNext = false;
      return;
    }

    final pageEvents = _allEvents.sublist(startIndex,
        endIndex > _allEvents.length ? _allEvents.length : endIndex);

    _renderedBuffer.clear();
    for (var event in pageEvents) {
      _renderedBuffer.add(_renderEvent(event));
    }

    _hasMorePrevious = startIndex > 0;
    _hasMoreNext = endIndex < _allEvents.length;

    _refreshFilter();
  }

  Future<void> _loadNextLogs() async {
    if (_isLoadingMore || !_hasMoreNext) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final currentOffset = _scrollController.offset;
      _loadCurrentPage();

      // Maintain scroll position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(currentOffset);
      });
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPreviousLogs() async {
    if (_isLoadingPrevious || !_hasMorePrevious) return;

    setState(() {
      _isLoadingPrevious = true;
    });

    try {
      _currentPage--;
      final currentOffset = _scrollController.offset;
      _loadCurrentPage();

      // Maintain relative scroll position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(currentOffset + 200.0);
      });
    } finally {
      setState(() {
        _isLoadingPrevious = false;
      });
    }
  }

  // Update the NotificationListener in _buildLogContent
  Widget _buildLogContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: ListView.builder(
        shrinkWrap: false,
        padding: const EdgeInsets.only(left: 10),
        controller: _scrollController,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index >= _filteredBuffer.length) return null;

          // Show loading indicators at top and bottom
          if (index == 0 && _isLoadingPrevious) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (index == _filteredBuffer.length - 1 && _isLoadingMore) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          var logEntry = _filteredBuffer[index];
          bool isSelected = _selectedLogIds.contains(logEntry.id);
          return RepaintBoundary(
            child: GestureDetector(
              onTapDown: (tapDownDetails) {
                _savedPosition = tapDownDetails.globalPosition;
              },
              onLongPress: () {
                setState(() {
                  if (isSelected) {
                    _selectedLogIds.remove(logEntry.id);
                  } else {
                    _selectedLogIds.add(logEntry.id);
                  }
                  _isSelectionMode = _selectedLogIds.isNotEmpty;
                });
              },
              onDoubleTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedLogIds.remove(logEntry.id);
                  } else {
                    _selectedLogIds.add(logEntry.id);
                  }
                  _isSelectionMode = _selectedLogIds.isNotEmpty;
                });
              },
              child: Container(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.transparent,
                child: SelectableText.rich(
                  logEntry.span,
                  key: Key(logEntry.id.toString()),
                  style: TextStyle(
                    fontSize: _logFontSize,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.2,
                  ),
                  maxLines: null,
                ),
              ),
            ),
          );
        },
        itemCount: _filteredBuffer.length,
      ),
    );
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _logContentWithKeyShortcuts),
            _buildBottomBar(),
          ],
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _followBottom ? 1 : 0,
        duration: Duration(milliseconds: 150),
        child: Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: FloatingActionButton(
            mini: true,
            clipBehavior: Clip.antiAlias,
            onPressed: _scrollToBottom,
            child: Icon(
              Icons.arrow_downward,
              color: widget.dark ? Colors.white : Colors.lightBlue[900],
            ),
          ),
        ),
      ),
    );
  }

  double get _scrollRange {
    return MediaQuery.of(context).size.height / 4;
  }

  void _scrollUp() {
    var offset = _scrollController.offset - _scrollRange;
    if (offset < 0) {
      offset = 0;
    }
    _scrollController.jumpTo(offset);
  }

  void _scrollDown() {
    var offset = _scrollController.offset + _scrollRange;
    if (offset > _scrollController.position.maxScrollExtent) {
      offset = _scrollController.position.maxScrollExtent;
    }
    _scrollController.jumpTo(offset);
  }

  Widget get _logContentWithKeyShortcuts {
    return Focus(
      focusNode: _logContentFocusNode,
      child: _buildLogContent(),
      onKeyEvent: (node, event) {
        if (node != _logContentFocusNode) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _scrollUp();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _scrollDown();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.f1) {
          _showPopUpMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  Color? get _buttonColor {
    return null;
  }

  Widget get _refresh {
    return IconButton(
      icon: Icon(Icons.refresh_rounded, color: _buttonColor),
      onPressed: () {
        _followBottom = true;
        didChangeDependencies();
      },
    );
  }

  Widget get _saveAsFile {
    return IconButton(
      icon: Icon(Icons.save_rounded, color: _buttonColor),
      onPressed: () {
        widget.saveFile?.call();
      },
    );
  }

  Widget get _shareAsFile {
    return IconButton(
      icon: Icon(Icons.ios_share_rounded, color: _buttonColor),
      onPressed: () {
        widget.shareFile?.call();
      },
    );
  }

  Widget get _close {
    return IconButton(
      icon: Icon(Icons.close, color: _buttonColor),
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }

  Widget get _popupMenu {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      child: const Icon(Icons.more_vert_rounded),
      itemBuilder: (context) => _popupMenuEntries,
    );
  }

  List<PopupMenuEntry<String>> get _popupMenuEntries {
    return [
      if (_isSelectionMode) ...[
        PopupMenuItem<String>(
          value: "copy selection",
          onTap: _copySelection,
          child: Row(
            children: [
              _copySelectionButton,
              const Text("Copy selection"),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: "clear selection",
          onTap: _clearSelection,
          child: Row(children: [
            _clearSelectionButton,
            const Text("Clear selection"),
          ]),
        ),
      ],
      if (widget.showRefreshButton)
        PopupMenuItem<String>(
          value: "refresh",
          onTap: () {
            _followBottom = true;
            didChangeDependencies();
          },
          child: Row(children: [_refresh, Text(_refreshText)]),
        ),
      if (widget.saveFile != null)
        PopupMenuItem<String>(
          value: "save as file",
          onTap: widget.saveFile,
          child: Row(children: [_saveAsFile, Text(_saveText)]),
        ),
      if (widget.shareFile != null)
        PopupMenuItem<String>(
          value: "share as file",
          onTap: widget.shareFile,
          child: Row(children: [_shareAsFile, Text(_shareText)]),
        ),
      if (widget.showCloseButton)
        PopupMenuItem<String>(
          value: "close log view",
          onTap: () => Navigator.pop(context),
          child: _close,
        ),
    ];
  }

  void _showPopUpMenu() async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay == null) {
      return;
    }
    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        _savedPosition & const Size(40, 40),
        Offset.zero & overlay.semanticBounds.size,
      ),
      items: _popupMenuEntries,
    );
  }

  String _getSelectedLogsText() {
    final selectedLogs = _filteredBuffer
        .where((log) => _selectedLogIds.contains(log.id))
        .map((log) => log.lowerCaseText)
        .join('\n');
    return selectedLogs;
  }

  void _copySelection() {
    final text = _getSelectedLogsText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedLogIds.clear();
      _isSelectionMode = false;
    });
  }

  Widget get _copySelectionButton {
    return IconButton(
      icon: const Icon(Icons.copy),
      onPressed: _copySelection,
    );
  }

  Widget get _clearSelectionButton {
    return IconButton(
      icon: const Icon(Icons.clear_all),
      onPressed: _clearSelection,
    );
  }

  List<Widget> get _selectionButtons {
    return [
      _copySelectionButton,
      _clearSelectionButton,
    ];
  }

  PreferredSizeWidget _buildTopBar() {
    final title = widget.title ?? _titleText;
    final isMobile = (Platform.isAndroid || Platform.isIOS);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return AppBar(
      title: ListTile(
        title: Text(title),
        subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      ),
      centerTitle: true,
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              _logFontSize++;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            setState(() {
              _logFontSize--;
            });
          },
        ),
        if (!isMobile)
          IconButton(
            icon: Icon(Icons.keyboard_arrow_up),
            onPressed: _scrollUp,
          ),
        if (!isMobile)
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down),
            onPressed: _scrollDown,
          ),
        if (isSmallScreen) _popupMenu,
        if (!isSmallScreen && _isSelectionMode) ..._selectionButtons,
        if (!isSmallScreen && widget.showRefreshButton) _refresh,
        if (!isSmallScreen && widget.saveFile != null) _saveAsFile,
        if (!isSmallScreen && widget.shareFile != null) _shareAsFile,
        if (!isSmallScreen && widget.showCloseButton) _close,
        const SizedBox(width: 8),
      ],
    );
  }

  Widget get _clearButton {
    return IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () => _filterController.clear(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _filterController,
              onChanged: (s) => _refreshFilter(),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                prefixIcon: const Icon(Icons.filter_list),
                suffixIcon: _clearButton,
                labelText: _filterText,
              ),
            ),
          ),
          SizedBox(width: 20),
          DropdownButton(
            underline: Container(),
            elevation: 0,
            padding: const EdgeInsets.all(8),
            value: _filterLevel,
            items: [
              DropdownMenuItem(value: Level.trace, child: Text(_verboseText)),
              DropdownMenuItem(value: Level.debug, child: Text(_debugText)),
              DropdownMenuItem(value: Level.info, child: Text(_infoText)),
              DropdownMenuItem(value: Level.warning, child: Text(_warningText)),
              DropdownMenuItem(value: Level.error, child: Text(_errorText)),
              DropdownMenuItem(value: Level.fatal, child: Text(_wtfText))
            ],
            onChanged: (value) {
              if (value != null) {
                _filterLevel = value;
                _refreshFilter();
              }
            },
          )
        ],
      ),
    );
  }

  void _scrollToBottom() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent - 2,
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark, level: event.level);
    var text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
    );
  }
}

class LogBar extends StatelessWidget {
  final bool dark;
  final Widget child;

  const LogBar({super.key, required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.grey[400]!,
                blurRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: dark ? Colors.blueGrey[900] : Colors.white,
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 8, 15, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
