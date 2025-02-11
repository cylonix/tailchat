import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' show PreviewData;
import 'package:flutter_linkify/flutter_linkify.dart' hide UrlLinkifier;
import 'package:url_launcher/url_launcher.dart';
import '../url_linkifier.dart' show UrlLinkifier;
import '../utils.dart' show getPreviewData;

/// A widget that renders text with highlighted links.
/// Eventually unwraps to the full preview of the first found link
/// if the parsing was successful.
@immutable
class LinkPreview extends StatefulWidget {
  /// Creates [LinkPreview]
  const LinkPreview({
    Key? key,
    this.animationDuration,
    this.corsProxy,
    this.enableAnimation = false,
    this.header,
    this.headerStyle,
    this.hideImage,
    this.imageBuilder,
    this.linkStyle,
    this.metadataTextStyle,
    this.metadataTitleStyle,
    this.onLinkPressed,
    required this.onPreviewDataFetched,
    this.padding,
    required this.previewData,
    required this.text,
    this.textStyle,
    required this.width,
  }) : super(key: key);

  /// Expand animation duration
  final Duration? animationDuration;

  /// CORS proxy to make more previews work on web. Not tested.
  final String? corsProxy;

  /// Enables expand animation. Default value is false.
  final bool? enableAnimation;

  /// Custom header above provided text
  final String? header;

  /// Style of the custom header
  final TextStyle? headerStyle;

  /// Hides image data from the preview
  final bool? hideImage;

  /// Function that allows you to build a custom image
  final Widget Function(String)? imageBuilder;

  /// Style of highlighted links in the text
  final TextStyle? linkStyle;

  /// Style of preview's description
  final TextStyle? metadataTextStyle;

  /// Style of preview's title
  final TextStyle? metadataTitleStyle;

  /// Custom link press handler
  final void Function(String)? onLinkPressed;

  /// Callback which is called when [PreviewData] was successfully parsed.
  /// Use it to save [PreviewData] to the state and pass it back
  /// to the [LinkPreview.previewData] so the [LinkPreview] would not fetch
  /// preview data again.
  final void Function(PreviewData) onPreviewDataFetched;

  /// Padding around initial text widget
  final EdgeInsets? padding;

  /// Pass saved [PreviewData] here so [LinkPreview] would not fetch preview
  /// data again
  final PreviewData? previewData;

  /// Text used for parsing
  final String text;

  /// Style of the provided text
  final TextStyle? textStyle;

  /// Width of the [LinkPreview] widget
  final double width;

  @override
  _LinkPreviewState createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool isFetchingPreviewData = false;
  bool shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration ?? const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );
    didUpdateWidget(widget);
  }

  @override
  void didUpdateWidget(covariant LinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!isFetchingPreviewData && widget.previewData == null) {
      _fetchData(widget.text);
    }

    if (widget.previewData != null && oldWidget.previewData == null) {
      setState(() {
        shouldAnimate = true;
      });
      _controller.reset();
      _controller.forward();
    } else if (widget.previewData != null) {
      setState(() {
        shouldAnimate = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<PreviewData> _fetchData(String text) async {
    setState(() {
      isFetchingPreviewData = true;
    });

    final previewData = await getPreviewData(text, proxy: widget.corsProxy);
    _handlePreviewDataFetched(previewData);
    return previewData;
  }

  void _handlePreviewDataFetched(PreviewData previewData) async {
    await Future.delayed(
      widget.animationDuration ?? const Duration(milliseconds: 300),
    );

    if (mounted) {
      widget.onPreviewDataFetched(previewData);
      setState(() {
        isFetchingPreviewData = false;
      });
    }
  }

  bool _hasData(PreviewData? previewData) {
    return previewData?.title != null ||
        previewData?.description != null ||
        previewData?.image?.url != null;
  }

  bool _hasOnlyImage() {
    return widget.previewData?.title == null &&
        widget.previewData?.description == null &&
        widget.previewData?.image?.url != null;
  }

  Future<void> _onOpen(LinkableElement link) async {
    if (await canLaunchUrl(Uri.parse(link.url))) {
      await launchUrl(Uri.parse(link.url));
    }
  }

  Widget _animated(Widget child) {
    return SizeTransition(
      axis: Axis.vertical,
      axisAlignment: -1,
      sizeFactor: _animation,
      child: child,
    );
  }

  Widget _bodyWidget(PreviewData data, String text, double width) {
    final _padding = widget.padding ??
        const EdgeInsets.only(
          bottom: 16,
          left: 24,
          right: 24,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: EdgeInsets.only(
            bottom: _padding.bottom,
            left: _padding.left,
            right: _padding.right,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (data.title != null) _titleWidget(data.title!),
              if (data.description != null)
                _descriptionWidget(data.description!),
            ],
          ),
        ),
        if (data.image?.url != null && widget.hideImage != true)
          _imageWidget(data.image!.url, width),
      ],
    );
  }

  Widget _containerWidget({
    required bool animate,
    bool withPadding = false,
    Widget? child,
  }) {
    final _padding = widget.padding ??
        const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        );

    final shouldAnimate = widget.enableAnimation == true && animate;

    return Container(
      constraints: BoxConstraints(maxWidth: widget.width),
      padding: withPadding ? _padding : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: withPadding
                ? const EdgeInsets.all(0)
                : EdgeInsets.only(
                    left: _padding.left,
                    right: _padding.right,
                    top: _padding.top,
                    bottom: _hasOnlyImage() ? 0 : 16,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.header != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.header!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.headerStyle,
                    ),
                  ),
                _linkify(),
                if (withPadding && child != null)
                  shouldAnimate ? _animated(child) : child,
              ],
            ),
          ),
          if (!withPadding && child != null)
            shouldAnimate ? _animated(child) : child,
        ],
      ),
    );
  }

  Widget _descriptionWidget(String description) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: widget.metadataTextStyle,
      ),
    );
  }

  Widget _imageWidget(String url, double width) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: width,
      ),
      width: width,
      child: widget.imageBuilder != null
          ? widget.imageBuilder!(url)
          : Image.network(
              url,
              fit: BoxFit.contain,
            ),
    );
  }

  Widget _linkify() {
    return SelectableLinkify(
      linkifiers: [const EmailLinkifier(), UrlLinkifier()],
      linkStyle: widget.linkStyle,
      maxLines: 100,
      minLines: 1,
      onOpen: widget.onLinkPressed != null
          ? (element) => widget.onLinkPressed!(element.url)
          : _onOpen,
      options: const LinkifyOptions(
        defaultToHttps: true,
        humanize: false,
        looseUrl: true,
      ),
      text: widget.text,
      style: widget.textStyle,
    );
  }

  Widget _minimizedBodyWidget(PreviewData data, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.title != null || data.description != null)
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (data.title != null) _titleWidget(data.title!),
                        if (data.description != null)
                          _descriptionWidget(data.description!),
                      ],
                    ),
                  ),
                ),
                if (data.image?.url != null && widget.hideImage != true)
                  _minimizedImageWidget(data.image!.url),
              ],
            ),
          ),
      ],
    );
  }

  Widget _minimizedImageWidget(String url) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(12),
      ),
      child: SizedBox(
        height: 48,
        width: 48,
        child: widget.imageBuilder != null
            ? widget.imageBuilder!(url)
            : Image.network(url),
      ),
    );
  }

  Widget _titleWidget(String title) {
    final style = widget.metadataTitleStyle ??
        const TextStyle(
          fontWeight: FontWeight.bold,
        );

    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _previewData = widget.previewData;

    if (_previewData != null && _hasData(_previewData)) {
      final aspectRatio = widget.previewData!.image == null
          ? null
          : widget.previewData!.image!.width /
              widget.previewData!.image!.height;

      final _width = aspectRatio == 1 ? widget.width : widget.width - 32;

      return _containerWidget(
        animate: shouldAnimate,
        child: aspectRatio == 1
            ? _minimizedBodyWidget(_previewData, widget.text)
            : _bodyWidget(_previewData, widget.text, _width),
        withPadding: aspectRatio == 1,
      );
    } else {
      return _containerWidget(animate: false);
    }
  }
}
