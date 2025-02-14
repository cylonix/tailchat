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
String _wtfText = "Fault";
String _refreshText = "Refresh";
String _saveText = "Save";
String _shareText = "Share";

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;
  final bool showRefreshButton;
  final String? title;
  final Future<ListQueue<OutputEvent>> Function()? getLogOutputEvents;
  final void Function(void Function())? listenToUpdateTrigger;
  final void Function()? saveFile;
  final void Function()? shareFile;

  LogConsole({
    super.key,
    this.dark = false,
    this.title,
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

  final _scrollController = ScrollController();
  final _filterController = TextEditingController();

  Level _filterLevel = Level.trace;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
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
    late ListQueue<OutputEvent> events;
    final getEventsF = widget.getLogOutputEvents;

    _renderedBuffer.clear();
    if (getEventsF != null) {
      setState(() {
        _isLoading = true;
      });
      events = await getEventsF();
      setState(() {
        _isLoading = false;
      });
    } else {
      events = _outputEventBuffer;
    }
    for (var event in events) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
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
        opacity: _followBottom ? 0 : 1,
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

  Widget _buildLogContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.only(left: 10),
        controller: _scrollController,
        itemBuilder: (context, index) {
          var logEntry = _filteredBuffer[index];
          return GestureDetector(
            child: SelectableText.rich(
              logEntry.span,
              key: Key(logEntry.id.toString()),
              style: TextStyle(
                fontSize: _logFontSize,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            onTapDown: (tapDownDetails) {
              _savedPosition = tapDownDetails.globalPosition;
            },
          );
        },
        itemCount: _filteredBuffer.length,
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
    final isMobile = (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) {
      return null;
    }
    return widget.dark ? Colors.white : Colors.grey;
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
      if (widget.showRefreshButton)
        PopupMenuItem<String>(
          value: "refresh",
          child: Row(children: [_refresh, Text(_refreshText)]),
          onTap: () {
            _followBottom = true;
            didChangeDependencies();
          },
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
          child: _close,
          onTap: () => Navigator.pop(context),
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

  PreferredSizeWidget _buildTopBar() {
    final title = widget.title ?? _titleText;
    final isMobile = (Platform.isAndroid || Platform.isIOS);
    return AppBar(
      title: Text(title),
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
            icon: Icon(Icons.arrow_upward),
            onPressed: _scrollUp,
          ),
        if (!isMobile)
          IconButton(
            icon: Icon(Icons.arrow_downward),
            onPressed: _scrollDown,
          ),
        if (isMobile) _popupMenu,
        if (!isMobile && widget.showRefreshButton) _refresh,
        if (!isMobile && widget.saveFile != null) _saveAsFile,
        if (!isMobile && widget.shareFile != null) _shareAsFile,
        if (!isMobile && widget.showCloseButton) _close,
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
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark);
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
