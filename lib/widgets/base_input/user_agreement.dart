// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../gen/l10n/app_localizations.dart';
import '../url_link.dart';

class UserAgreement extends StatefulWidget {
  final Function(bool)? onAgreementCheckedChange;
  final FocusNode? focus;
  final FocusNode? nextFocus;
  final bool showCheckBox;
  const UserAgreement({
    super.key,
    this.focus,
    this.nextFocus,
    this.onAgreementCheckedChange,
    this.showCheckBox = false,
  });

  @override
  State<UserAgreement> createState() => _UserAgreementState();
}

class _UserAgreementState extends State<UserAgreement> {
  bool _checkboxSelected = Pst.enableAR ?? false;
  @override
  Widget build(BuildContext context) {
    if (!widget.showCheckBox) {
      return _textLink;
    }
    return Row(
      children: [
        _checkBox,
        Expanded(child: _textLink),
      ],
    );
  }

  Widget get _textLink {
    final tr = AppLocalizations.of(context);
    return Wrap(
      alignment:
          widget.showCheckBox ? WrapAlignment.start : WrapAlignment.center,
      children: [
        Text(
          widget.showCheckBox
              ? tr.haveReadAndAgreeWithTerms
              : 'By continuing, you have agreed to the ',
        ),
        _agreement,
        Text(" and "),
        _policy,
      ],
    );
  }

  Widget get _checkBox {
    return Checkbox.adaptive(
      focusNode: widget.focus,
      shape: const CircleBorder(),
      value: _checkboxSelected,
      onChanged: (value) {
        setState(() {
          _checkboxSelected = value!;
        });
        widget.onAgreementCheckedChange?.call(_checkboxSelected);
        if (_checkboxSelected) {
          widget.nextFocus?.requestFocus();
        }
      },
    );
  }

  Widget get _agreement {
    final tr = AppLocalizations.of(context);
    return UrlLink(
      label: tr.userAgreement,
      url: "https://cylonix.io/web/view/tailchat/terms.html",
    );
  }

  Widget get _policy {
    final tr = AppLocalizations.of(context);
    return UrlLink(
      label: tr.policyTitle,
      url: "https://cylonix.io/web/view/tailchat/privacy_policy.html",
    );
  }
}
