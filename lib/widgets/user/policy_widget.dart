// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../api/config.dart' as config;
import '../../utils/global.dart';
import '../scroll_controller_with_arrow_keys.dart';

class PolicyPage extends StatefulWidget {
  const PolicyPage({
    super.key,
    this.title = "",
    this.radius = 8,
    required this.mdFileName,
  });

  final String title;
  final double radius;
  final String mdFileName;
  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final _controller = ScrollController();
  String _content = "";

  @override
  void initState() {
    super.initState();
    _loadPolicyContent();
  }

  void _loadPolicyContent() async {
    var s = await rootBundle.loadString('lib/assets/${widget.mdFileName}');
    s = s.replaceAll("\${APP_NAME}", config.appName);
    s = s.replaceAll("\${CONTACT_EMAIL}", config.contactEmail());
    s = s.replaceAll("\${COMPANY_NAME}", config.companyName());
    _content = s;
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Global.logger.d("loading doc ${widget.mdFileName}");
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0.0,
        centerTitle: true,
      ),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Expanded(
              child: _content.isNotEmpty
                  ? ScrollControllerWithArrowKeys(
                      controller: _controller,
                      child: Markdown(
                        data: _content,
                        controller: _controller,
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
