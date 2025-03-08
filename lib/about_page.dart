// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/config.dart';
import 'gen/l10n/app_localizations.dart';
import 'utils/global.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/common_widgets.dart';
import 'widgets/main_app_bar.dart';
import 'widgets/qrcode/qr_code_image.dart';
import 'widgets/url_link.dart';
import 'widgets/tv/caption.dart';
import 'widgets/tv/left_side.dart';
import 'widgets/tv/return_button.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.title = ""});
  final String title;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  PackageInfo? _packageInfo;
  final _logger = Logger(tag: "About");
  final _isTV = Pst.enableTV ?? false;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _packageInfo = info;
      });
    } catch (e) {
      _logger.e("failed to get package info: $e");
    }
  }

  Image get _logoImage {
    return Image.asset(
      "lib/assets/images/tailchat.png",
      width: 120,
      height: 120,
    );
  }

  Widget get _logo {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: commonBorderRadius(),
            ),
            child: _logoImage,
          )
        ],
      ),
    );
  }

  Widget get _title {
    final tr = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[Caption(context, tr.appTitle)],
    );
  }

  Widget get _version {
    const subVersion = String.fromEnvironment(
      "BUILD_SUB_VERSION",
      defaultValue: "7",
    );
    const version = String.fromEnvironment(
      "VERSION",
      defaultValue: "1.0.1",
    );
    return Text(
      "${_packageInfo?.version ?? version}-$subVersion",
      textAlign: TextAlign.center,
    );
  }

  Widget get _contact {
    final tr = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Divider(height: 1, thickness: 1),
          ListTile(
            title: Text(
              tr.email,
              textAlign: TextAlign.center,
            ),
            subtitle: Text(
              "contact@cylonix.io",
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }

  Widget get _copyRight {
    final tr = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.copyright, size: 16),
        Flexible(
          child: Text(
            copyrightText(tr),
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget get _homePage {
    final url = "https://github.com/cylonix/tailchat";
    final tr = AppLocalizations.of(context);
    return Column(
      children: [
        if (url.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isDesktop())
                _clickableQrImage(
                  url,
                  caption: url,
                  showAsButton: true,
                ),
              TextButton(
                child: Text(url),
                onPressed: () => _launchUrl(url),
              )
            ],
          ),
        const SizedBox(height: 20),
        if (officialSupportUrl?.isNotEmpty == true)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              if (isDesktop())
                _clickableQrImage(
                  officialSupportUrl!,
                  caption: tr.contact,
                  showAsButton: true,
                ),
              TextButton(
                child: Text(tr.contact),
                onPressed: () => _launchUrl(officialSupportUrl!),
              )
            ],
          ),
      ],
    );
  }

  Widget get _policy {
    final tr = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 32,
      children: <Widget>[
        UrlLink(
          label: tr.userAgreement,
          url: "https://cylonix.io/web/view/tailchat/terms.html",
        ),
        UrlLink(
          label: tr.policyTitle,
          url: "https://cylonix.io/web/view/tailchat/privacy_policy.html",
        ),
      ],
    );
  }

  void _launchUrl(String urlString) async {
    _logger.d("Try launching url $urlString");
    final tr = AppLocalizations.of(context);
    try {
      final url = Uri.parse(urlString);
      if (isDesktop() && !await canLaunchUrl(url)) {
        throw ("not allowed to launch.");
      }
      _logger.d("URL is valid. Launching $url");
      // Make sure to use external browser as in-app webview may not handle
      // app downloads correctly.
      await launchUrl(
        url,
        mode: Global.isAndroidTV
            ? LaunchMode.inAppWebView
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        await showAlertDialog(
          context,
          tr.prompt,
          "${tr.cannotLaunchUrlText}: $urlString $e",
        );
      }
    }
  }

  Widget _clickableQrImage(
    String url, {
    String? caption,
    String? leadingImage,
    double? imageWidth,
    bool showSaveAsButton = true,
    bool showAsButton = false,
  }) {
    final leading = leadingImage != null
        ? Image.asset(
            leadingImage,
            width: imageWidth,
          )
        : caption != null
            ? Text(caption)
            : null;
    final child = InkWell(
      child: isMobile()
          ? leading
          : QrCodeImage(
              url,
              qrImageSize: 256,
              showSaveAsButton: showSaveAsButton,
              leading: leadingImage != null
                  ? Image.asset(
                      leadingImage,
                      width: imageWidth,
                    )
                  : caption != null
                      ? Text(caption)
                      : null,
              image: _logoImage.image,
            ),
      onTap: () {
        _launchUrl(url);
      },
    );
    if (!showAsButton) {
      return child;
    }
    return IconButton(
      icon: const Icon(Icons.qr_code),
      tooltip: caption ?? url,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return Scaffold(
                appBar: MainAppBar(titleWidget: Text(caption ?? url)),
                body: Center(child: child),
              );
            },
          ),
        );
      },
    );
  }

  Widget _appQrImage(String url) {
    String? image;
    String? caption;
    double width = 200;
    if (url.contains("apple.com")) {
      image = "lib/assets/images/apple_store.png";
      caption = "iOS";
      width = 190;
    } else if (url.contains("google.com")) {
      image = "lib/assets/images/google_play.png";
    } else if (url.contains("android")) {
      caption = "Android";
    }
    return _clickableQrImage(
      url,
      leadingImage: image,
      caption: caption,
      imageWidth: width,
    );
  }

  Widget get _appLinks {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      alignment: WrapAlignment.center,
      spacing: 100,
      children: [
        if ((iosAppLink ?? "").isNotEmpty) _appQrImage(iosAppLink!),
        if ((androidAppLink ?? "").isNotEmpty) _appQrImage(androidAppLink!),
      ],
    );
  }

  Widget get _spacer {
    return const SizedBox(height: 32);
  }

  Widget get _body {
    final tr = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        _spacer,
        if (!_isTV) _logo,
        if (!_isTV) const SizedBox(height: 4),
        _title,
        _spacer,
        Center(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Text(
              tr.introWords,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
        _spacer,
        Text(tr.version, textAlign: TextAlign.center),
        _version,
        _spacer,
        _policy,
        _spacer,
        _contact,
        _spacer,
        if (isDesktop()) _appLinks,
        _spacer,
        _copyRight,
        _spacer,
        _homePage,
        _spacer,
      ],
    );
  }

  Widget get _bodyForTV {
    final tr = AppLocalizations.of(context);
    return Row(
      children: [
        LeftSide(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!Global.isAndroidTV) const ReturnButton(),
            Caption(context, tr.aboutTitle),
            _logo,
          ],
        ),
        Expanded(child: _body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: _isTV ? null : MainAppBar(titleWidget: Text(tr.aboutTitle)),
      body: _isTV ? _bodyForTV : _body,
    );
  }
}
