import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tailchat';

  @override
  String get loadingConfigTitle => 'Tailchat is loading saved configurations. Please wait';

  @override
  String get loadingConfigLabel => 'Configuration is still be loaded...';

  @override
  String get urlFormatErrorAlert => 'URL format error';

  @override
  String get currentSetting => 'Current setting';

  @override
  String get hitReturnToConfirm => 'Hit enter key to confirm';

  @override
  String get changeButtonText => 'Change';

  @override
  String get userName => 'Username';

  @override
  String get userNameHint => 'Please enter your username';

  @override
  String get errDeviceExists => 'The device already exists.';

  @override
  String get errEmailExists => 'Email is already used by another user.';

  @override
  String get errLabelExists => 'The label already exists.';

  @override
  String get errUserExists => 'The user already exists.';

  @override
  String get errBadUserInfo => 'There is an error in the user information.';

  @override
  String get errUserNotExists => 'The user does not exist.';

  @override
  String get ok => 'OK';

  @override
  String get confirmDialogTitle => 'Please confirm';

  @override
  String get yesButton => 'Yes';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get disapprovedMsg => 'Device is disapproved. Please contact administrator.';

  @override
  String get needsApprovalMsg => 'Device is not yet approved. Please contact administrator.';

  @override
  String get refreshText => 'Refresh';

  @override
  String get rotateText => 'Rotate';

  @override
  String get unauthorizedTitle => 'Unauthorized.';

  @override
  String get authorizedTitle => 'Authorized.';

  @override
  String get authorizedMsg => 'Device is now authorized.';

  @override
  String get qrScan => 'Scan';

  @override
  String get scanMeText => 'Scan the QR code to add me as a friend';

  @override
  String get scanAgainText => 'Scan again';

  @override
  String get noCodeFoundFromImageText => 'No code found from image';

  @override
  String get codeInvalidText => 'Code invalid';

  @override
  String get deviceTitle => 'Device';

  @override
  String get chooseChatTitle => 'Please select a chat';

  @override
  String get sendToText => 'Send to ';

  @override
  String get fileNotExistsText => 'File not exists';

  @override
  String get noFilesHint => 'Select files from gallery or file manager.';

  @override
  String get addCaption => 'Add caption';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get statusTitle => 'Status';

  @override
  String get aboutTitle => 'About Tailchat';

  @override
  String get pleaseAgreeToUserAgreementText => 'Please agree to the User Agreement and Privacy Policy.';

  @override
  String get pleaseAgreeToPersonalInfoGuideText => 'Please agree to the Personal Information Protection Guidelines';

  @override
  String get policyTitle => 'Privacy policy';

  @override
  String get userAgreement => 'User agreement';

  @override
  String get userAgreementAndPolicyTitle => 'User agreement and privacy policy';

  @override
  String get haveReadAndAgreeWithTerms => 'I have read and agreed with the user agreement and privacy policy';

  @override
  String get policyHint => 'Please check policy agreement before logging in';

  @override
  String get networkUnavailableHint => 'Network is not available. Please check the network setting of the device.';

  @override
  String get agree => 'Agree';

  @override
  String get disAgree => 'Disagree';

  @override
  String get personalInfoGuideTitle => 'Personal Information Protection Guidelines';

  @override
  String get personalInfoGuide => 'Any information used by the app is only stored locally on your devices. In order to provide you with services, the app uses your device name, operating system version and IP address to help connect your device and manage your settings. We will not decrypt your traffic. We will not send any information to any server, so we will never see your data or logs. If you agree, please click the agree button below to accept our service.';

  @override
  String get policyDialog => 'Please read carefully and fully understand the terms of the \"User agreement\" and \"Privacy policy\", including but not limited to: In order to provide you with better services, the app uses the your device\'s IP address to establish a peer connection, device name, operating system information for device management in the app. We will not use the data for other purposes and no information is sent to any of our servers. All data are only stored locally on your devices. You can read the agreement and the policy for details. If you agree, please click the agree button below to start using our service.';

  @override
  String get alertErrorMessage => 'Error';

  @override
  String get logout => 'Log out';

  @override
  String get leaveText => 'Leave';

  @override
  String get version => 'Version';

  @override
  String get contact => 'Contact us';

  @override
  String get email => 'Email Contact';

  @override
  String get address => 'Address';

  @override
  String copyright(Object company) {
    return '$company. All Rights Reserved ';
  }

  @override
  String get unauthenticated => 'Session expired, please login again.';

  @override
  String get hostnameText => 'Host';

  @override
  String get ipText => 'IP';

  @override
  String get osText => 'OS';

  @override
  String get mkeyText => 'ID';

  @override
  String get nkeyText => 'Node';

  @override
  String get activeText => 'Active';

  @override
  String get relayText => 'Relay';

  @override
  String get directText => 'Direct';

  @override
  String get exitNodeText => 'Exit node';

  @override
  String get allowedIPsText => 'Allowed IPs';

  @override
  String get videoMeetingText => 'Video meeting';

  @override
  String get txBytes => 'Tx';

  @override
  String get rxBytes => 'Rx';

  @override
  String get lastHandshake => 'Last handshake';

  @override
  String get lastSeen => 'Last seen';

  @override
  String get createdTime => 'Created';

  @override
  String get offlineDevicesTitle => 'Offline devices';

  @override
  String get offlineDevicesLastSeenTitle => 'Devices last seen more than 5 minutes ago';

  @override
  String get selfTitle => 'This device';

  @override
  String get statusList => 'Status list';

  @override
  String get publicKey => 'Public key';

  @override
  String get introWords => 'Tailchat is a truly serverless, secure instant messaging app built on Tailscale\'s WireGuard®-based mesh network. No message storage. No central servers. Just direct, encrypted communication. Tailchat is not affiliated with, endorsed by, or sponsored by Tailscale Inc. Tailscale® and Tailnet are trademarks of Tailscale Inc.';

  @override
  String get introTitle => 'Welcome to Tailchat';

  @override
  String get getStarted => 'Get started';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get showLog => 'Open logs';

  @override
  String get showDaemonLog => 'Open Tailchat service logs';

  @override
  String get daemonLogConsoleTitleText => 'Tailchat background service log console';

  @override
  String get logConsoleTitleText => 'Log console';

  @override
  String get logConsoleFilterText => 'Filter log message';

  @override
  String get debugText => 'Debug';

  @override
  String get verboseText => 'Verbose';

  @override
  String get infoText => 'Info';

  @override
  String get warningText => 'Warning';

  @override
  String get errorText => 'Error';

  @override
  String get wtfText => 'WTF';

  @override
  String get daemon => 'Tailchat Daemon';

  @override
  String get status => 'Status';

  @override
  String get userInformation => 'User information';

  @override
  String get name => 'name';

  @override
  String get country => 'Country';

  @override
  String get contactWay => 'Contact information';

  @override
  String get photo => 'Photo';

  @override
  String get file => 'File';

  @override
  String get phone => 'Phone number';

  @override
  String get mail => 'Mail';

  @override
  String get companyInformation => 'Company information';

  @override
  String get companyName => 'Company name';

  @override
  String get companyJob => 'Position';

  @override
  String get companyAddress => 'Company address';

  @override
  String get nightMode => 'Night mode';

  @override
  String get dayMode => 'Day mode';

  @override
  String get videoInviteText => 'invites you to a video meeting';

  @override
  String get videoRequestText => 'Waiting for the peer\'s approval';

  @override
  String get connectFailText => 'Failed to connect with the peer. Please try again later';

  @override
  String get usernameEmpty => 'User name cannot be empty.';

  @override
  String get goodUsernameText => 'Username must be of minimum of 4 chars with English letters and/or numbers only.';

  @override
  String get namespaceEmpty => 'Organization cannot be empty.';

  @override
  String get invalidNamespaceTitle => 'Organization name error';

  @override
  String get advancedStatusTitle => 'Advanced';

  @override
  String get daemonStatusDetail => 'Daemon status detail';

  @override
  String get peerStatusDetail => 'Peer status detail';

  @override
  String get contactsAndPeersTitle => 'Contacts and devices';

  @override
  String get confirmApproveQrCodeLogin => 'Please confirm if you approve the login';

  @override
  String get waitForQrCode => 'Waiting for qr code scan result...';

  @override
  String get approvedQrCodeLogin => 'QR code login approved';

  @override
  String get notApprovedQrCodeLogin => 'QR code login not yet approved';

  @override
  String get qrCodeHandlerError => 'Failed to handle qr code scan result';

  @override
  String get qrCodeHandlerSuccess => 'Succeeded to handle QR code scan result';

  @override
  String get enterPhone => 'Please enter your mobile phone number';

  @override
  String get smsCode => 'One time code';

  @override
  String get enterSmsCode => 'Please enter the one time code sent to your mobile phone';

  @override
  String get phoneError => 'Please enter a valid mobile phone number';

  @override
  String get smsError => 'Please enter a valid one time code';

  @override
  String get smsValidationError => 'SMS code validation failed';

  @override
  String get sendSmsCode => 'Send code';

  @override
  String get noSelectedItem => 'No Item Selected';

  @override
  String get advancedSettingsTitle => 'Advanced Settings';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get searchHintText => 'Search';

  @override
  String get userDevicesDetails => '...';

  @override
  String get userDevicesDetailsTip => 'Details of the user and devices';

  @override
  String get userMoreOperationTip => 'More';

  @override
  String get confirmText => 'Confirm';

  @override
  String get copyText => 'Copy';

  @override
  String get deleteText => 'Delete';

  @override
  String get removeText => 'Remove';

  @override
  String get editText => 'Edit';

  @override
  String get recallText => 'Recall';

  @override
  String get deleteFromAllPeersText => 'Delete from all peers';

  @override
  String get deleteFromAllPeersSuccessText => 'Deleted from all peers.';

  @override
  String get pinText => 'Pin';

  @override
  String get saveText => 'Save';

  @override
  String get shareText => 'Share';

  @override
  String get sendAgainText => 'Send again';

  @override
  String get sendText => 'Send';

  @override
  String get confirmSessionDeleteMessageText => 'Really deleting the session?';

  @override
  String get notYetImplementedMessageText => 'Not yet implemented';

  @override
  String get notificationsText => 'Notifications';

  @override
  String get unknownText => 'Unknown';

  @override
  String get notFoundText => 'not found';

  @override
  String get addUsersText => 'Add users';

  @override
  String get selectUsersText => 'Select users';

  @override
  String get selectADeviceText => 'Select a device';

  @override
  String get selectUserForChatText => 'Please select the user to join the chat.';

  @override
  String get selectOneUserOnlyForChatText => 'Need to select only one user into chat.';

  @override
  String get selectOneDeviceOnlyForChatText => 'Need to select one device for the chat.';

  @override
  String get confirmAddingToGroupChatText => 'Confirm adding to group chat';

  @override
  String get pleaseSelectOneUserText => 'Please select one user.';

  @override
  String get pleaseSelectOneDeviceText => 'Please select one device. If there is no device available, please choose a different user.';

  @override
  String get chatWithAUserText => 'Chat with a user';

  @override
  String get chatWithAUserOnDeviceText => 'Chat with a user on a device';

  @override
  String get selfUserNotFoundError => 'User profile not found for self.';

  @override
  String get selfUserNotInGroupChatError => 'Need to select self into the group chat.';

  @override
  String get groupChatUserCountNotEnoughError => 'Need to select more than one other user for a group chat.';

  @override
  String get groupNameText => 'Group name';

  @override
  String get groupNameInputHintText => 'Input group name';

  @override
  String get groupNameEmptyError => 'Group name must not be empty.';

  @override
  String get addGroupChatText => 'Add group chat';

  @override
  String get addFriendText => 'Add friend';

  @override
  String get scanToAddText => 'Scan to add friend';

  @override
  String get addFriendSuccessText => 'Add friend success';

  @override
  String get deleteFriendSuccess => 'Delete friend success';

  @override
  String get deleteFriendFailed => 'Failed to delete friend. Please try again later';

  @override
  String get deleteFriend => 'Delete friend';

  @override
  String get deleteFriendDetail => 'Delete the friend and delete the chat record with the friend';

  @override
  String get requestSendText => 'Add to address book';

  @override
  String get friendRequestText => 'Friend request';

  @override
  String get agreeVerifyText => 'Approve';

  @override
  String get refuseVerifyText => 'Reject';

  @override
  String get refuseRequestSuccess => 'You have rejected your friend request';

  @override
  String get refuseFailedText => 'Reject request failed';

  @override
  String get newFriendText => 'New friend';

  @override
  String get waitVerifyText => 'Waiting for approval';

  @override
  String get useMobileText => 'Please scan the code with your mobile device.';

  @override
  String get myQrCodeText => 'My QR code';

  @override
  String get noFriendRequestText => 'There is no request to add friends currently';

  @override
  String get selfText => 'I am ';

  @override
  String get noteText => 'Friend request notes';

  @override
  String get sendRequestFailedText => 'Request send failed';

  @override
  String get sendRequestSuccess => 'You have sent a friend request';

  @override
  String get cannotAddSelf => 'You cannot add yourself as a friend';

  @override
  String get userNotExist => 'The user does not exist';

  @override
  String get tryLaterText => 'Please try later';

  @override
  String get qrCodeErrDetail => 'Fail to get QR code, unknown exception';

  @override
  String get qrCodeExpired => 'QR code has expired, please refresh and try again';

  @override
  String get scanFriendFailedText => 'Processing error after scanning code to add friends';

  @override
  String get selectUsersForGroupChatText => 'Please select the users to join the group.';

  @override
  String get noDeviceAvailableToChatMessageText => 'No device is available to chat.';

  @override
  String get groupChatInfoMissingErrorText => 'Group chat information is missing.';

  @override
  String get invalidChatUserCountErrorText => 'Invalid number of users.';

  @override
  String get chatText => 'Chat';

  @override
  String get chatWithAllDevicesText => 'Chat with all available devices of this user';

  @override
  String get chatWithSingleDeviceText => 'Chat with a device of this user';

  @override
  String get allDevicesText => 'All devices';

  @override
  String get userText => 'User';

  @override
  String get personalUsers => 'Community user';

  @override
  String chatWithUserText(Object username) {
    return 'Chat with $username';
  }

  @override
  String get prompt => 'Alert';

  @override
  String get successText => 'Success';

  @override
  String get failedText => 'Failed';

  @override
  String get bindFailedContent => 'Failed to add the mobile phone number.';

  @override
  String get setVerbosityLevelText => 'Daemon logging verbosity level';

  @override
  String get displayNameText => 'Display name';

  @override
  String get emailText => 'Email';

  @override
  String get audioOnlyText => 'Audio only';

  @override
  String get audioMutedText => 'Audio muted';

  @override
  String get videoMutedText => 'Video muted';

  @override
  String videoWaitingForPeerToAnswerText(String peer) {
    return 'Waiting for $peer to answer the call';
  }

  @override
  String get enableARSetting => 'AR Glasses Mode';

  @override
  String get enableTVSetting => 'Enable TV Mode';

  @override
  String get tvModeText => 'TV Mode';

  @override
  String get saveToFileText => 'Save to file';

  @override
  String get saveToGalleryText => 'Save to photos';

  @override
  String imageSavedToFileText(String file) {
    return 'Image saved to $file';
  }

  @override
  String get imageSavedToGalleryText => 'Image saved to gallery';

  @override
  String get errSavingImageText => 'Error saving media';

  @override
  String get unsupportedMediaText => 'Unsupported image or video format';

  @override
  String get cameraText => 'Camera';

  @override
  String get galleryText => 'Gallery';

  @override
  String get downloadWeChatText => 'Please download WeChat app first';

  @override
  String get videoText => 'Video';

  @override
  String get selectUserForVideoCallText => 'Select user to join the video call';

  @override
  String get switchCameraText => 'Switch camera';

  @override
  String get toggleFlashText => 'Toggle flash';

  @override
  String get scanFromImageText => 'Scan from image';

  @override
  String get emptyQrCodeText => 'QR code is empty';

  @override
  String get recentChatsText => 'Recent chats';

  @override
  String get messageSendResultsText => 'Message send results';

  @override
  String get successDeviceCountText => 'Success device count';

  @override
  String get failureDeviceCountText => 'Failure device count';

  @override
  String get dontShowAgainText => 'Don\'t show again';

  @override
  String get fileSavedToText => 'File saved to';

  @override
  String get failedToSaveFileText => 'Failed to save file';

  @override
  String get saveToAppStorageText => 'Save to app storage';

  @override
  String get saveToSharedStorageText => 'Save to shared storage';

  @override
  String get forwardText => 'Forward';

  @override
  String get retrySendingToFailedDevicesText => 'Retry sending to failed devices';

  @override
  String get sharedTextText => 'Shared text';

  @override
  String get forwardMessagesToText => 'Forward messages to';

  @override
  String get highText => 'High';

  @override
  String get higherText => 'Higher';

  @override
  String get lowText => 'Low';

  @override
  String get mediumText => 'Medium';

  @override
  String get standardText => 'Standard';

  @override
  String get forceToTurnOffText => 'Force to turn off';

  @override
  String get turnOnSuccessText => 'Successfully connected to cylonix';

  @override
  String get turnOffSuccessText => 'Successfully disconnected from cylonix';

  @override
  String get moreOptionsText => 'More options';

  @override
  String get addAccountDetailsText => 'Add account details';

  @override
  String get addAccountDetailsHintText => 'For example, set up username or add email';

  @override
  String get addAccountDetailsSucceedText => 'Add account details succeed.';

  @override
  String get addAccountDetailsFailedText => 'Failed to add account details.';

  @override
  String get firstNameText => 'First name';

  @override
  String get lastNameText => 'Last name';

  @override
  String get inputHasNoUpdateText => 'Input has no update';

  @override
  String get updateProfilePictureText => 'Update profile picture';

  @override
  String get userAvatarNotExistsText => 'User avatar does not exist';

  @override
  String get replyText => 'Reply';

  @override
  String get simpleChatUI => 'Simple chat user interface';

  @override
  String get onlyGroupChatAdminCanRemoveMemberText => 'Only group chat administrator can remove member';

  @override
  String get generateNewRoomIDText => 'Generate a new room ID';

  @override
  String get useDefaultRoomText => 'Use default room';

  @override
  String get deleteAllChatMessagesText => 'Delete all chat messages';

  @override
  String get confirmDeleteAllChatMessagesText => 'Please confirm if to delete all chat messages. Messages will be forever deleted.';

  @override
  String get deleteAllChatMessagesSucceededText => 'Delete all chat messages succeeded.';

  @override
  String get deleteAllChatMessagesFailedText => 'Failed to delete all chat messages.';

  @override
  String get setMessageExpirationTimeText => 'Set message expiration time';

  @override
  String get fifteenSecondsText => '15 seconds';

  @override
  String get oneMinuteText => '1 minute';

  @override
  String get oneHourText => '1 hour';

  @override
  String get oneDayText => '1 day';

  @override
  String get noExpirationText => 'No expiration';

  @override
  String get remoteNotExistsText => 'Remote does not exist.';

  @override
  String get remoteNameTxt => 'Remote name';

  @override
  String get inputRemoteText => 'Input remote device code or IP or name';

  @override
  String userNotAvailableText(Object user) {
    return '$user is not available';
  }

  @override
  String get homeText => 'Home';

  @override
  String get sidebarText => 'SideBar';

  @override
  String get checkForUpdateText => 'Check for app update';

  @override
  String get clickToUpdateText => 'Click to update app';

  @override
  String get cannotLaunchUrlText => 'Cannot launch URL';

  @override
  String get confirmToOverwriteFileText => 'File exists already. Do you want to overwrite it?';

  @override
  String get expandText => 'Expand';

  @override
  String get compactText => 'Compact';

  @override
  String get showIntroPagesOnNextStartText => 'Show user agreement and privacy policy pages on next app start';

  @override
  String get restartDaemonServiceText => 'Restart daemon service';

  @override
  String get confirmRestartDaemonServiceText => 'To restore the service we need to restart the daemon process. It may ask you to approve the change with administrator permission twice. Please approve the changes when being prompted.';

  @override
  String get changeText => 'Change';

  @override
  String get doneText => 'Done';

  @override
  String get searchUserText => 'Search user';

  @override
  String get cannotInviteSelfText => 'Cannot invite self';

  @override
  String serverNotReachableText(Object server) {
    return '$server is not reachable. Please try again later.';
  }

  @override
  String get startTimeText => 'Start time';

  @override
  String get pageUpText => 'Page up';

  @override
  String get pageDownText => 'Page down';

  @override
  String get noUserAvailableDetailsText => 'No user is available. This could be due to either there is no user online or any newly added user is not yet sync\'ed to your device. It may take as long as a minute to be synced up.';

  @override
  String get toStartText => 'To start';

  @override
  String get addVideoCallText => 'Start call';

  @override
  String get returnText => 'Return';

  @override
  String get openToEditText => 'Open to edit';

  @override
  String get meetingOptionText => 'meeting options';

  @override
  String get bitrateScaleFactorText => 'Bitrate scale factor';

  @override
  String get todayLabel => 'Today';

  @override
  String get selectDateLabel => 'Select date';

  @override
  String get selectTimeLabel => 'Select time';

  @override
  String get amText => 'AM';

  @override
  String get pmText => 'PM';

  @override
  String get twentyFourHourText => '24 hour';

  @override
  String get setMeetingOptionsLabel => 'Set meeting options';

  @override
  String get setPortraitModeLabel => 'Set portrait mode';

  @override
  String get enableSimulcastLabel => 'Enable simulcast';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSettingsTitle => 'Appearance settings';

  @override
  String get featureTitle => 'Feature';

  @override
  String get featureSettingsTitle => 'Feature settings';

  @override
  String get networkTitle => 'Network';

  @override
  String get networkSettingsTitle => 'Network settings';

  @override
  String get shieldsUpTitle => 'Shields up';

  @override
  String get dontAllowIncomingConnectionsText => 'Don\'t allow incoming connections.';

  @override
  String get failedToSaveChangeText => 'failed to save change';

  @override
  String get pressOneMoreTimeToExitTheAppText => 'Press one more time in 10 seconds to exit the app.';
}
