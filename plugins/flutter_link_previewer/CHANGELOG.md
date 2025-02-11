## 2.6.0

- Updated dependencies (requires Dart >=2.14.0)
- Fixed Android example. Thanks @rvndsngwn for reporting!

## 2.5.2

Additionally, revert `json_annotation` upgrade

## 2.5.1

Revert `meta` upgrade, because `pub.dev` is analyzing code with an old Flutter version

## 2.5.0

- Update to Flutter 2.5
- Rename `REGEX_EMAIL` to `regexEmail` and `REGEX_LINK` to `regexLink`

## 2.4.2

- Update dependencies

## 2.4.1

- Update dependencies

## 2.4.0

- Update dependencies

## 2.3.0

- Improve REGEX
- Add custom `imageBuilder`

## 2.2.3

- Update dependencies

## 2.2.2

- Fix completer that never completes and add `corsProxy` parameter. Thanks @wer-mathurin for the PR!
- Export `getPreviewData` to allow you to create your own implementation of a link preview.

## 2.2.1

- Update dependencies

## 2.2.0

- Add `hideImage` param

## 2.1.0

- Update dependencies

## 2.0.8

- Update dependencies

## 2.0.7

- Fix alignment

## 2.0.6

- Update to Flutter 2.2

## 2.0.5

- Fix links starting from a capital `Http`

## 2.0.4

- Add preview for the image link

## 2.0.3

- Add a custom header above the text

## 2.0.2

- Fix paddings for an empty preview data
- Limit number of images parsed
- Fix regex

## 2.0.1

- Fix custom padding and add a custom link press handler

## 2.0.0

- **BREAKING**: `onPreviewDataFetched` and `previewData` are now required. In the previous version, a link preview used on a ListView resulted in a fetch call every time the preview was appearing on a screen.

## 1.0.6

- Fix warnings and layout issues

## 1.0.5

- Add an optional animation

## 1.0.4

- Update dependencies

## 1.0.3

- Update dependencies

## 1.0.2

- Update dependencies

## 1.0.1

- Add CI

## 1.0.0

- Add documentation

## 0.2.2

- Update to null safety

## 0.2.1

- Code cleanup

## 0.2.0

- Flutter 2 update

## 0.1.0

- Dependency update

## 0.0.9

- Readme added

## 0.0.8

- Dependency update

## 0.0.7

- Use types from utility library

## 0.0.6

- Make widget stateless

## 0.0.5

- Render plain text on loading and error

## 0.0.4

- Critical fix and remove unneeded code

## 0.0.3

- Code improvements and cleanup

## 0.0.2

- Added customization

## 0.0.1

- Initial release
