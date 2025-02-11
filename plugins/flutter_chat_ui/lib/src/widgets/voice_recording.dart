import 'package:flutter/material.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';

class VoiceRecording extends StatefulWidget {
  final void Function()? onStart;
  final void Function()? onStop;
  final bool onTapStartStop;
  final FocusNode? focusNode;
  const VoiceRecording({
    Key? key,
    this.focusNode,
    this.onStart,
    this.onStop,
    this.onTapStartStop = false,
  }) : super(key: key);

  @override
  _VoiceRecordingState createState() => _VoiceRecordingState();
}

class _VoiceRecordingState extends State<VoiceRecording>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTapStartStop) {
      return Material(
        child: InkWell(
          autofocus: true,
          focusNode: widget.focusNode,
          focusColor: Colors.pinkAccent.withValues(alpha: 0.5),
          child: _started
              ? _bottomSheet
              : SizedBox(height: 100, child: _recording),
          onTap: () {
            if (_started) {
              _stopRecording();
            } else {
              setState(() {
                _started = true;
              });
              widget.onStart?.call();
            }
          },
        ),
      );
    }
    return GestureDetector(
      child: _recording,
      onLongPress: _startRecording,
      onLongPressUp: _stopRecording,
    );
  }

  Widget get _recording {
    return Container(
      alignment: Alignment.center,
      height: 48,
      child: Text(
        widget.onTapStartStop
            ? InheritedL10n.of(context).l10n.clickToRecordLabel
            : InheritedL10n.of(context).l10n.holdToRecordLabel,
        textAlign: TextAlign.center,
        style: _style,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: widget.onTapStartStop ? null : BorderRadius.circular(200),
      ),
    );
  }

  TextStyle get _style {
    final theme = InheritedChatTheme.of(context).theme;
    return theme.inputTextStyle.copyWith(color: theme.inputTextColor);
  }

  Color get _backgroundColor {
    return InheritedChatTheme.of(context).theme.inputBackgroundColor;
  }

  void _startRecording() {
    widget.onStart?.call();
    showBottomSheet(
      backgroundColor: _backgroundColor.withValues(alpha: 0.6),
      constraints: const BoxConstraints(minWidth: double.infinity),
      context: context,
      builder: (context) => _bottomSheet,
    );
  }

  void _stopRecording() {
    Navigator.of(context).pop();
    widget.onStop?.call();
  }

  Widget get _animatingMic {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        ScaleTransition(
          scale: _animation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(200),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 20,
                )
              ],
            ),
            child: Icon(
              Icons.circle,
              size: 200,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        const Icon(Icons.mic, size: 150),
      ],
    );
  }

  Widget _bottomSheetContainer(Widget child, double height) {
    return Container(
      alignment: Alignment.center,
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.elliptical(200, 80),
          topRight: Radius.elliptical(200, 80),
        ),
      ),
      child: child,
    );
  }

  Widget get _holdForRecording {
    return _bottomSheetContainer(
      Column(
        children: [
          const SizedBox(height: 20),
          Text(
            widget.onTapStartStop
                ? InheritedL10n.of(context).l10n.clickToSendLabel
                : InheritedL10n.of(context).l10n.releaseToSendLabel,
            style: _style,
          ),
          const SizedBox(height: 40),
          Icon(
            Icons.volume_up_rounded,
            size: 48,
            color: InheritedChatTheme.of(context).theme.inputTextColor,
          ),
        ],
      ),
      150,
    );
  }

  Widget get _bottomSheet {
    return SizedBox(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _animatingMic,
          _holdForRecording,
        ],
      ),
    );
  }
}
