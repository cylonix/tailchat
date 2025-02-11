# Flutter Link Previewer

[![Pub](https://img.shields.io/pub/v/flutter_link_previewer)](https://pub.dartlang.org/packages/flutter_link_previewer)
[![build](https://github.com/flyerhq/flutter_link_previewer/workflows/build/badge.svg)](https://github.com/flyerhq/flutter_link_previewer/actions?query=workflow%3Abuild)
[![CodeFactor](https://www.codefactor.io/repository/github/flyerhq/flutter_link_previewer/badge)](https://www.codefactor.io/repository/github/flyerhq/flutter_link_previewer)

URL preview extracted from the provided text with basic customization and ability to render from cached data.

<img src="https://user-images.githubusercontent.com/14123304/117151394-5285fd80-adb9-11eb-857b-3c21558ecd24.png" width="428" height="926">

## Getting Started

```dart
import 'package:flutter_link_previewer/flutter_link_previewer.dart';

LinkPreview(
  enableAnimation: true,
  onPreviewDataFetched: (data) {
    setState(() {
      // Save preview data to the state              
    });
  },
  previewData: _previewData, // Pass the preview data from the state
  text: 'https://flyer.chat',
  width: MediaQuery.of(context).size.width,
)
```

## Customization

```dart
final style = TextStyle(
  color: Colors.red,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.375,
);


LinkPreview(
  linkStyle: style,
  metadataTextStyle: style.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  ),
  metadataTitleStyle: style.copyWith(
    fontWeight: FontWeight.w800,
  ),
  padding: EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  ),
  onPreviewDataFetched: _onPreviewDataFetched,
  previewData: _previewData,
  text: 'https://flyer.chat',
  textStyle: style,
  width: width,
);
```

## License

[MIT](LICENSE)
