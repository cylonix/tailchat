import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gen/l10n/app_localizations.dart';
import '../utils/global.dart';
import '../utils/logger.dart';
import '../utils/utils.dart';

class UrlLink extends StatelessWidget {
  static final _logger = Logger(tag: "UrlLink");
  final String label;
  final String url;
  const UrlLink({required this.label, required this.url, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        child: Text(
          label,
          style: TextStyle(color: Colors.blue),
        ),
        onTap: () => _launchUrl(url, context),
      ),
    );
  }

  void _launchUrl(String urlString, BuildContext context) async {
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
      if (context.mounted) {
        showAlertDialog(
          context,
          tr.prompt,
          "${tr.cannotLaunchUrlText}: $urlString $e",
          showCancel: false,
        );
      }
    }
  }
}
