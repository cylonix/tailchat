// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('receive_sharing_intent/messages');

  const testUriString = "content://media/external/images/media/43993";

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case "getInitialText":
          return testUriString;
        case "getInitialTextAsUri":
          return Uri.parse(testUriString);
        default:
          throw UnimplementedError();
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getInitialText', () async {
    var actual = await ReceiveSharingIntent.getInitialText();
    expect(actual, testUriString);
  });

  test('getInitialTextAsUri', () async {
    var actual = await ReceiveSharingIntent.getInitialTextAsUri();
    expect(actual, Uri.parse(testUriString));
  });
}
