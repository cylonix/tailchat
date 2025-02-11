// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

import 'api/config.dart';
import 'gen/l10n/app_localizations.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/base_input/button.dart';
import 'widgets/tv/caption.dart';
import 'widgets/tv/left_side.dart';
import 'widgets/user/user_agreement.dart';

class IntroPage extends StatefulWidget {
  final Completer? completer;
  const IntroPage({super.key, this.completer});

  @override
  State<IntroPage> createState() => _State();
}

class _State extends State<IntroPage> {
  final _introScreenKey = GlobalKey<IntroductionScreenState>();
  bool _tvModeDecided = false;
  bool _userAgreementAgreed = false;
  bool _personalInfoGuideAgreed = false;
  int _initialIndex = 0;
  bool _isAndroidTV = Pst.enableTV ?? false;
  final Logger _logger = Logger(tag: "intro-page");

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        FocusScope.of(context).requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isAndroidTV ? _buildAndroidTV : _buildNonAndroidTV;
  }

  Widget get _buildAndroidTV {
    final tr = AppLocalizations.of(context);
    return _getTVPage(
      _policyIcon,
      tr.userAgreementAndPolicyTitle,
      _userAgreementBody,
    );
  }

  Widget _getTVPage(Widget icon, String title, Widget right) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeftSide(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 16),
              Caption(context, title),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SingleChildScrollView(
                  child: right,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get _privacyPageForTV {
    final tr = AppLocalizations.of(context);
    return _getTVPage(
      _policyInfoIcon,
      tr.personalInfoGuideTitle,
      _privacyPageBody,
    );
  }

  bool get _isAR {
    return Pst.enableAR ?? false;
  }

  double get _topImageHeight {
    return _isAR ? 32 : 80;
  }

  Widget get _divider {
    return SizedBox(height: _isAR ? 8 : 16);
  }

  TextStyle? get _textStyle {
    return _isAndroidTV ? Theme.of(context).textTheme.titleMedium : null;
  }

  Widget get _privacyPageBody {
    final tr = AppLocalizations.of(context);
    return Column(children: [
      _divider,
      Text(
        tr.personalInfoGuide,
        textAlign: TextAlign.justify,
        style: _textStyle,
      ),
      const SizedBox(height: 16),
      Wrap(
        runSpacing: 16,
        spacing: 16,
        children: [
          BaseInputButton(
            autoFocus: true,
            filledButton: true,
            height: _isAR ? 30 : 40,
            width: _isAR ? null : 200,
            child: Text(tr.agree, style: _textStyle),
            onPressed: () {
              _personalInfoGuideAgreed = true;
              if (_isAndroidTV) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _introDonePageForTV,
                  ),
                );
              } else {
                _introScreenKey.currentState?.next();
              }
            },
          ),
          BaseInputButton(
            height: _isAR ? 30 : 40,
            width: _isAR ? null : 200,
            outlineButton: true,
            onPressed: () => exit(0),
            child: Text(tr.disAgree, style: _textStyle),
          ),
        ],
      ),
    ]);
  }

  Widget get _introDonePageForTV {
    final tr = AppLocalizations.of(context);
    return _getTVPage(
      _logo,
      tr.introTitle,
      Column(
        children: [
          _divider,
          Text(tr.introWords, textAlign: TextAlign.justify, style: _textStyle),
          _divider,
          _divider,
          _doneButton,
        ],
      ),
    );
  }

  Widget get _buildNonAndroidTV {
    if (Platform.isAndroid && canBeAndroidTV()) {
      if (!_tvModeDecided) {
        return Scaffold(body: _chooseTVMode);
      }
    }
    return Scaffold(
      body: IntroductionScreen(
        key: _introScreenKey,
        initialPage: _initialIndex,
        pages: _pages,
        isProgress: true,
        showBackButton: true,
        back: const Icon(Icons.arrow_back_ios_rounded),
        next: const Icon(Icons.arrow_forward_ios_rounded),
        done: Text(AppLocalizations.of(context).getStarted, style: _textStyle),
        onDone: () => _handleIntroDone(),
      ),
    );
  }

  Widget get _doneButton {
    return BaseInputButton(
      autoFocus: true,
      height: 40,
      width: 300,
      onPressed: _handleIntroDone,
      child: Text(AppLocalizations.of(context).getStarted, style: _textStyle),
    );
  }

  void _handleIntroDone() async {
    final tr = AppLocalizations.of(context);
    if (!_userAgreementAgreed || !_personalInfoGuideAgreed) {
      final msg = _userAgreementAgreed
          ? tr.pleaseAgreeToPersonalInfoGuideText
          : tr.pleaseAgreeToUserAgreementText;
      _initialIndex = _userAgreementAgreed ? 1 : 0;
      await showAlertDialog(context, tr.prompt, msg);
      // An ugly way to intro screen to get back to the right page before it
      // correctly handles the initialPage parameter on rebuild.
      if (!_isAndroidTV) {
        await _introScreenKey.currentState?.animateScroll(_initialIndex);
      }
      return;
    }
    // When done button is pressed
    _logger.d("Intro done. Calling completion and switch back to home page");
    _switchBackToHomePage();
    widget.completer?.complete();
    await _disableIntroPage();
  }

  void _switchBackToHomePage() {
    Navigator.of(context).popUntil(ModalRoute.withName('/'));
  }

  Future<void> _disableIntroPage() async {
    await Pst.saveSkipIntro(true);
  }

  Widget _topImage(Widget child) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget get _policyIcon {
    return Icon(Icons.policy_outlined, size: _topImageHeight);
  }

  Widget get _policyInfoIcon {
    return Icon(Icons.privacy_tip_outlined, size: _topImageHeight);
  }

  Widget get _chooseTVMode {
    final tr = AppLocalizations.of(context);
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 64),
          Icon(Icons.live_tv_rounded, size: _topImageHeight),
          const SizedBox(height: 64),
          Caption(context, tr.enableTVSetting),
          const SizedBox(height: 64),
          Row(mainAxisSize: MainAxisSize.min, children: [
            BaseInputButton(
              width: 150,
              child: Text(tr.cancelButton),
              onPressed: () {
                setState(() {
                  _tvModeDecided = true;
                });
              },
            ),
            const SizedBox(width: 32),
            BaseInputButton(
              onPressed: () {
                Pst.saveEnableTV(true);
                setState(() {
                  _isAndroidTV = true;
                  _tvModeDecided = true;
                });
              },
              width: 150,
              child: Text(tr.yesButton),
            ),
          ]),
        ],
      ),
    );
  }

  PageViewModel get _userAgreementPage {
    final tr = AppLocalizations.of(context);
    return _getPage(
      _logo,
      tr.userAgreementAndPolicyTitle,
      _userAgreementBody,
    );
  }

  Widget get _userAgreementBody {
    return UserAgreement(
      onAgreed: () {
        _userAgreementAgreed = true;
        if (_isAndroidTV) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _privacyPageForTV,
            ),
          );
        } else {
          _introScreenKey.currentState?.next();
        }
      },
    );
  }

  PageViewModel get _privacyPage {
    final tr = AppLocalizations.of(context);
    return _getPage(
      _policyInfoIcon,
      tr.personalInfoGuideTitle,
      _privacyPageBody,
    );
  }

  Widget get _logo {
    const logo = "lib/assets/images/tailchat.png";
    return Image.asset(logo, width: 128, height: _topImageHeight);
  }

  PageViewModel get _introDonePage {
    final tr = AppLocalizations.of(context);
    return _getPage(
      _logo,
      tr.introTitle,
      Text(tr.introWords, textAlign: TextAlign.justify, style: _textStyle),
    );
  }

  Widget? _arTitleWidget(Widget top, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _topImage(top),
        const SizedBox(width: 16),
        Text(
          title,
          textScaler: const TextScaler.linear(1.1),
        )
      ],
    );
  }

  PageViewModel _getPage(Widget top, String title, Widget body) {
    return PageViewModel(
      image: _isAR ? null : _topImage(top),
      title: _isAR ? null : title,
      titleWidget: _isAR ? _arTitleWidget(top, title) : null,
      decoration: const PageDecoration(imageFlex: 1, bodyFlex: 3),
      bodyWidget: Container(
        margin: const EdgeInsets.only(left: 20, right: 20),
        child: body,
      ),
    );
  }

  List<PageViewModel> get _pages {
    return [
      _userAgreementPage,
      _privacyPage,
      _introDonePage,
    ];
  }
}
