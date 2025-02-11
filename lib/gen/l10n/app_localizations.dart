import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Tailchat'**
  String get appTitle;

  /// loading start up config title
  ///
  /// In en, this message translates to:
  /// **'Tailchat is loading saved configurations. Please wait'**
  String get loadingConfigTitle;

  /// semantic label text for the loading circle
  ///
  /// In en, this message translates to:
  /// **'Configuration is still be loaded...'**
  String get loadingConfigLabel;

  /// URL format error alert text
  ///
  /// In en, this message translates to:
  /// **'URL format error'**
  String get urlFormatErrorAlert;

  /// current setting text
  ///
  /// In en, this message translates to:
  /// **'Current setting'**
  String get currentSetting;

  /// hit enter key to confirm helper text
  ///
  /// In en, this message translates to:
  /// **'Hit enter key to confirm'**
  String get hitReturnToConfirm;

  /// change button text
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeButtonText;

  /// Input text field of username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get userName;

  /// Input text field of username hint
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get userNameHint;

  /// register device already exists failure text
  ///
  /// In en, this message translates to:
  /// **'The device already exists.'**
  String get errDeviceExists;

  /// register email already exists failure text
  ///
  /// In en, this message translates to:
  /// **'Email is already used by another user.'**
  String get errEmailExists;

  /// register label already exists failure text
  ///
  /// In en, this message translates to:
  /// **'The label already exists.'**
  String get errLabelExists;

  /// register user already exists failure text
  ///
  /// In en, this message translates to:
  /// **'The user already exists.'**
  String get errUserExists;

  /// register user information error text
  ///
  /// In en, this message translates to:
  /// **'There is an error in the user information.'**
  String get errBadUserInfo;

  /// register user does not exist text
  ///
  /// In en, this message translates to:
  /// **'The user does not exist.'**
  String get errUserNotExists;

  /// ok button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Please confirm'**
  String get confirmDialogTitle;

  /// Yes button text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesButton;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// device disapproved message
  ///
  /// In en, this message translates to:
  /// **'Device is disapproved. Please contact administrator.'**
  String get disapprovedMsg;

  /// device needs approval message
  ///
  /// In en, this message translates to:
  /// **'Device is not yet approved. Please contact administrator.'**
  String get needsApprovalMsg;

  /// Refresh meeting text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshText;

  /// Rotate the screen text
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotateText;

  /// unauthorized alert title
  ///
  /// In en, this message translates to:
  /// **'Unauthorized.'**
  String get unauthorizedTitle;

  /// Authorized alert title
  ///
  /// In en, this message translates to:
  /// **'Authorized.'**
  String get authorizedTitle;

  /// device authorized message
  ///
  /// In en, this message translates to:
  /// **'Device is now authorized.'**
  String get authorizedMsg;

  /// QR scan text
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get qrScan;

  /// QR scan text
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code to add me as a friend'**
  String get scanMeText;

  /// scan again text
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgainText;

  /// no code found from image text
  ///
  /// In en, this message translates to:
  /// **'No code found from image'**
  String get noCodeFoundFromImageText;

  /// code invalid text
  ///
  /// In en, this message translates to:
  /// **'Code invalid'**
  String get codeInvalidText;

  /// Device title text
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceTitle;

  /// Chat list text
  ///
  /// In en, this message translates to:
  /// **'Please select a chat'**
  String get chooseChatTitle;

  /// Send to user text
  ///
  /// In en, this message translates to:
  /// **'Send to '**
  String get sendToText;

  /// File not exists text
  ///
  /// In en, this message translates to:
  /// **'File not exists'**
  String get fileNotExistsText;

  /// No files hint text
  ///
  /// In en, this message translates to:
  /// **'Select files from gallery or file manager.'**
  String get noFilesHint;

  /// Add caption text
  ///
  /// In en, this message translates to:
  /// **'Add caption'**
  String get addCaption;

  /// Settings list title text
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Status title text
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusTitle;

  /// About list title text
  ///
  /// In en, this message translates to:
  /// **'About Tailchat'**
  String get aboutTitle;

  /// please agree to user agreement text
  ///
  /// In en, this message translates to:
  /// **'Please agree to the User Agreement and Privacy Policy.'**
  String get pleaseAgreeToUserAgreementText;

  /// please agree to personal info guide text
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Personal Information Protection Guidelines'**
  String get pleaseAgreeToPersonalInfoGuideText;

  /// Privacy policy title text
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get policyTitle;

  /// User agreement title text
  ///
  /// In en, this message translates to:
  /// **'User agreement'**
  String get userAgreement;

  /// user agreement and privacy policy title text
  ///
  /// In en, this message translates to:
  /// **'User agreement and privacy policy'**
  String get userAgreementAndPolicyTitle;

  /// Have read and agreed text
  ///
  /// In en, this message translates to:
  /// **'I have read and agreed with the user agreement and privacy policy'**
  String get haveReadAndAgreeWithTerms;

  /// check policy agreement text
  ///
  /// In en, this message translates to:
  /// **'Please check policy agreement before logging in'**
  String get policyHint;

  /// check network text
  ///
  /// In en, this message translates to:
  /// **'Network is not available. Please check the network setting of the device.'**
  String get networkUnavailableHint;

  /// Agree text
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agree;

  /// Disagree text
  ///
  /// In en, this message translates to:
  /// **'Disagree'**
  String get disAgree;

  /// Personal information protection guidelines title text
  ///
  /// In en, this message translates to:
  /// **'Personal Information Protection Guidelines'**
  String get personalInfoGuideTitle;

  /// Personal information protection guidelines text
  ///
  /// In en, this message translates to:
  /// **'Any information used by the app is only stored locally on your devices. In order to provide you with services, the app uses your device name, operating system version and IP address to help connect your device and manage your settings. We will not decrypt your traffic. We will not send any information to any server, so we will never see your data or logs. If you agree, please click the agree button below to accept our service.'**
  String get personalInfoGuide;

  /// policy dialog text
  ///
  /// In en, this message translates to:
  /// **'Please read carefully and fully understand the terms of the \"User agreement\" and \"Privacy policy\", including but not limited to: In order to provide you with better services, the app uses the your device\'s IP address to establish a peer connection, device name, operating system information for device management in the app. We will not use the data for other purposes and no information is sent to any of our servers. All data are only stored locally on your devices. You can read the agreement and the policy for details. If you agree, please click the agree button below to start using our service.'**
  String get policyDialog;

  /// alert error message title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get alertErrorMessage;

  /// Log out text
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @leaveText.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveText;

  /// Version text
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Contact us text
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contact;

  /// Email address text
  ///
  /// In en, this message translates to:
  /// **'Email Contact'**
  String get email;

  /// Office address text
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// copy right text
  ///
  /// In en, this message translates to:
  /// **'{company}. All Rights Reserved '**
  String copyright(Object company);

  /// token expired, need to login again
  ///
  /// In en, this message translates to:
  /// **'Session expired, please login again.'**
  String get unauthenticated;

  /// host name text
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostnameText;

  /// IP text
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get ipText;

  /// os text
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get osText;

  /// Machine key text
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get mkeyText;

  /// Node key text
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get nkeyText;

  /// active text
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeText;

  /// active text
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get relayText;

  /// direct text
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get directText;

  /// exit node text
  ///
  /// In en, this message translates to:
  /// **'Exit node'**
  String get exitNodeText;

  /// allowed IPs text
  ///
  /// In en, this message translates to:
  /// **'Allowed IPs'**
  String get allowedIPsText;

  /// video meeting text
  ///
  /// In en, this message translates to:
  /// **'Video meeting'**
  String get videoMeetingText;

  /// tx bytes
  ///
  /// In en, this message translates to:
  /// **'Tx'**
  String get txBytes;

  /// rx bytes
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get rxBytes;

  /// Last handshake time
  ///
  /// In en, this message translates to:
  /// **'Last handshake'**
  String get lastHandshake;

  /// Last seen time
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lastSeen;

  /// No description provided for @createdTime.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdTime;

  /// offline devices title text
  ///
  /// In en, this message translates to:
  /// **'Offline devices'**
  String get offlineDevicesTitle;

  /// devices last seen subtitle text
  ///
  /// In en, this message translates to:
  /// **'Devices last seen more than 5 minutes ago'**
  String get offlineDevicesLastSeenTitle;

  /// device self title text
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get selfTitle;

  /// No description provided for @statusList.
  ///
  /// In en, this message translates to:
  /// **'Status list'**
  String get statusList;

  /// public key text
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// introduction page words
  ///
  /// In en, this message translates to:
  /// **'Tailchat is a truly serverless, secure instant messaging app built on Tailscale\'s WireGuard®-based mesh network. No message storage. No central servers. Just direct, encrypted communication. Tailchat is not affiliated with, endorsed by, or sponsored by Tailscale Inc. Tailscale® and Tailnet are trademarks of Tailscale Inc.'**
  String get introWords;

  /// introduction page title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tailchat'**
  String get introTitle;

  /// introduction page get started hint
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// theme mode at setting page
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// Light Mode in theme page
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// Dark Mode in theme page
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// show console log for debugging
  ///
  /// In en, this message translates to:
  /// **'Open logs'**
  String get showLog;

  /// show daemon console log for debugging
  ///
  /// In en, this message translates to:
  /// **'Open Tailchat service logs'**
  String get showDaemonLog;

  /// tailchat daemon log console title text
  ///
  /// In en, this message translates to:
  /// **'Tailchat background service log console'**
  String get daemonLogConsoleTitleText;

  /// log console title text
  ///
  /// In en, this message translates to:
  /// **'Log console'**
  String get logConsoleTitleText;

  /// log console filter text
  ///
  /// In en, this message translates to:
  /// **'Filter log message'**
  String get logConsoleFilterText;

  /// debug label text
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugText;

  /// Verbose label text
  ///
  /// In en, this message translates to:
  /// **'Verbose'**
  String get verboseText;

  /// Info label text
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoText;

  /// warning label text
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningText;

  /// error label text
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorText;

  /// WTF label text
  ///
  /// In en, this message translates to:
  /// **'WTF'**
  String get wtfText;

  /// the daemon service
  ///
  /// In en, this message translates to:
  /// **'Tailchat Daemon'**
  String get daemon;

  /// status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// title of user detail page
  ///
  /// In en, this message translates to:
  /// **'User information'**
  String get userInformation;

  /// for user name's label
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get name;

  /// for Country label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// for Contact information's label
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get contactWay;

  /// Photo text
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// for Phone Number's label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone;

  /// for Mail's label
  ///
  /// In en, this message translates to:
  /// **'Mail'**
  String get mail;

  /// for Company Information's label
  ///
  /// In en, this message translates to:
  /// **'Company information'**
  String get companyInformation;

  /// for Company Name's label
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyName;

  /// for Position's label
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get companyJob;

  /// for Company Address's label
  ///
  /// In en, this message translates to:
  /// **'Company address'**
  String get companyAddress;

  /// Used to open/close the night mode
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get nightMode;

  /// Used to open/close the night mode
  ///
  /// In en, this message translates to:
  /// **'Day mode'**
  String get dayMode;

  /// Invites you to a video meeting text
  ///
  /// In en, this message translates to:
  /// **'invites you to a video meeting'**
  String get videoInviteText;

  /// Waiting for the peer's approval text
  ///
  /// In en, this message translates to:
  /// **'Waiting for the peer\'s approval'**
  String get videoRequestText;

  /// Failed to connect with the peer text
  ///
  /// In en, this message translates to:
  /// **'Failed to connect with the peer. Please try again later'**
  String get connectFailText;

  /// prompt text for user name empty error
  ///
  /// In en, this message translates to:
  /// **'User name cannot be empty.'**
  String get usernameEmpty;

  /// good username text
  ///
  /// In en, this message translates to:
  /// **'Username must be of minimum of 4 chars with English letters and/or numbers only.'**
  String get goodUsernameText;

  /// prompt text for organization empty error
  ///
  /// In en, this message translates to:
  /// **'Organization cannot be empty.'**
  String get namespaceEmpty;

  /// invalid organization name message title
  ///
  /// In en, this message translates to:
  /// **'Organization name error'**
  String get invalidNamespaceTitle;

  /// advanced status title text
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedStatusTitle;

  /// daemon status detail subtitle text
  ///
  /// In en, this message translates to:
  /// **'Daemon status detail'**
  String get daemonStatusDetail;

  /// peer status detail subtitle text
  ///
  /// In en, this message translates to:
  /// **'Peer status detail'**
  String get peerStatusDetail;

  /// contacts and peers title text
  ///
  /// In en, this message translates to:
  /// **'Contacts and devices'**
  String get contactsAndPeersTitle;

  /// approve qr code login confirm dialog text
  ///
  /// In en, this message translates to:
  /// **'Please confirm if you approve the login'**
  String get confirmApproveQrCodeLogin;

  /// qr code waiting status text
  ///
  /// In en, this message translates to:
  /// **'Waiting for qr code scan result...'**
  String get waitForQrCode;

  /// approved qr code login status text
  ///
  /// In en, this message translates to:
  /// **'QR code login approved'**
  String get approvedQrCodeLogin;

  /// not approved qr code login status text
  ///
  /// In en, this message translates to:
  /// **'QR code login not yet approved'**
  String get notApprovedQrCodeLogin;

  /// qr code handler error text
  ///
  /// In en, this message translates to:
  /// **'Failed to handle qr code scan result'**
  String get qrCodeHandlerError;

  /// qr code handler success text
  ///
  /// In en, this message translates to:
  /// **'Succeeded to handle QR code scan result'**
  String get qrCodeHandlerSuccess;

  /// ask user to enter mobile phone number
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile phone number'**
  String get enterPhone;

  /// label of sms one time code
  ///
  /// In en, this message translates to:
  /// **'One time code'**
  String get smsCode;

  /// Input text field of sms code
  ///
  /// In en, this message translates to:
  /// **'Please enter the one time code sent to your mobile phone'**
  String get enterSmsCode;

  /// phone number is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid mobile phone number'**
  String get phoneError;

  /// sms code length is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid one time code'**
  String get smsError;

  /// sms code validation failure title text
  ///
  /// In en, this message translates to:
  /// **'SMS code validation failed'**
  String get smsValidationError;

  /// send sms code button label
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendSmsCode;

  /// No Item Selected text
  ///
  /// In en, this message translates to:
  /// **'No Item Selected'**
  String get noSelectedItem;

  /// advanced setting title text
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettingsTitle;

  /// sessions title text
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// contacts title text
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// search input hint text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHintText;

  /// user devices details text
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get userDevicesDetails;

  /// user devices details tip text
  ///
  /// In en, this message translates to:
  /// **'Details of the user and devices'**
  String get userDevicesDetailsTip;

  /// user more operation tip text
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get userMoreOperationTip;

  /// confirm label text
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmText;

  /// copy text
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyText;

  /// delete label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteText;

  /// remove label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeText;

  /// Edit label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editText;

  /// recall text
  ///
  /// In en, this message translates to:
  /// **'Recall'**
  String get recallText;

  /// delete from all peers text
  ///
  /// In en, this message translates to:
  /// **'Delete from all peers'**
  String get deleteFromAllPeersText;

  /// delete from all peers success text
  ///
  /// In en, this message translates to:
  /// **'Deleted from all peers.'**
  String get deleteFromAllPeersSuccessText;

  /// pin label
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinText;

  /// save label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveText;

  /// share label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareText;

  /// send again label
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendAgainText;

  /// send text
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendText;

  /// confirm deleting a session message text
  ///
  /// In en, this message translates to:
  /// **'Really deleting the session?'**
  String get confirmSessionDeleteMessageText;

  /// not yet implemented message text
  ///
  /// In en, this message translates to:
  /// **'Not yet implemented'**
  String get notYetImplementedMessageText;

  /// Notifications label text
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsText;

  /// Unknown label text
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownText;

  /// not found text
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get notFoundText;

  /// add users label text
  ///
  /// In en, this message translates to:
  /// **'Add users'**
  String get addUsersText;

  /// select users text
  ///
  /// In en, this message translates to:
  /// **'Select users'**
  String get selectUsersText;

  /// select a device text
  ///
  /// In en, this message translates to:
  /// **'Select a device'**
  String get selectADeviceText;

  /// select user for chat label
  ///
  /// In en, this message translates to:
  /// **'Please select the user to join the chat.'**
  String get selectUserForChatText;

  /// select more than one user for chat error text
  ///
  /// In en, this message translates to:
  /// **'Need to select only one user into chat.'**
  String get selectOneUserOnlyForChatText;

  /// select more than one device for chat error text
  ///
  /// In en, this message translates to:
  /// **'Need to select one device for the chat.'**
  String get selectOneDeviceOnlyForChatText;

  /// confirm adding to group chat text
  ///
  /// In en, this message translates to:
  /// **'Confirm adding to group chat'**
  String get confirmAddingToGroupChatText;

  /// please select one user text
  ///
  /// In en, this message translates to:
  /// **'Please select one user.'**
  String get pleaseSelectOneUserText;

  /// please select one device text
  ///
  /// In en, this message translates to:
  /// **'Please select one device. If there is no device available, please choose a different user.'**
  String get pleaseSelectOneDeviceText;

  /// chat with a user text
  ///
  /// In en, this message translates to:
  /// **'Chat with a user'**
  String get chatWithAUserText;

  /// chat with a user on a device text
  ///
  /// In en, this message translates to:
  /// **'Chat with a user on a device'**
  String get chatWithAUserOnDeviceText;

  /// self user not found error message
  ///
  /// In en, this message translates to:
  /// **'User profile not found for self.'**
  String get selfUserNotFoundError;

  /// self user not selected in group chat error message
  ///
  /// In en, this message translates to:
  /// **'Need to select self into the group chat.'**
  String get selfUserNotInGroupChatError;

  /// group chat user number not enough error message
  ///
  /// In en, this message translates to:
  /// **'Need to select more than one other user for a group chat.'**
  String get groupChatUserCountNotEnoughError;

  /// label for group name
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameText;

  /// group name input hint text
  ///
  /// In en, this message translates to:
  /// **'Input group name'**
  String get groupNameInputHintText;

  /// group name is empty error message
  ///
  /// In en, this message translates to:
  /// **'Group name must not be empty.'**
  String get groupNameEmptyError;

  /// add group chat text
  ///
  /// In en, this message translates to:
  /// **'Add group chat'**
  String get addGroupChatText;

  /// add friend text
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get addFriendText;

  /// No description provided for @scanToAddText.
  ///
  /// In en, this message translates to:
  /// **'Scan to add friend'**
  String get scanToAddText;

  /// add friend success text
  ///
  /// In en, this message translates to:
  /// **'Add friend success'**
  String get addFriendSuccessText;

  /// Delete friend successfully text
  ///
  /// In en, this message translates to:
  /// **'Delete friend success'**
  String get deleteFriendSuccess;

  /// Failed to delete friend text
  ///
  /// In en, this message translates to:
  /// **'Failed to delete friend. Please try again later'**
  String get deleteFriendFailed;

  /// Delete friend text
  ///
  /// In en, this message translates to:
  /// **'Delete friend'**
  String get deleteFriend;

  /// Delete friend detail text
  ///
  /// In en, this message translates to:
  /// **'Delete the friend and delete the chat record with the friend'**
  String get deleteFriendDetail;

  /// Friend request send text
  ///
  /// In en, this message translates to:
  /// **'Add to address book'**
  String get requestSendText;

  /// friend request text
  ///
  /// In en, this message translates to:
  /// **'Friend request'**
  String get friendRequestText;

  /// Pass verification text
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get agreeVerifyText;

  /// Refuse verification text
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get refuseVerifyText;

  /// Refuse success text
  ///
  /// In en, this message translates to:
  /// **'You have rejected your friend request'**
  String get refuseRequestSuccess;

  /// Refuse failed text
  ///
  /// In en, this message translates to:
  /// **'Reject request failed'**
  String get refuseFailedText;

  /// New friend text
  ///
  /// In en, this message translates to:
  /// **'New friend'**
  String get newFriendText;

  /// Waiting for verification text
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get waitVerifyText;

  /// Waiting for verification text
  ///
  /// In en, this message translates to:
  /// **'Please scan the code with your mobile device.'**
  String get useMobileText;

  /// My QR code text
  ///
  /// In en, this message translates to:
  /// **'My QR code'**
  String get myQrCodeText;

  /// My QR code text
  ///
  /// In en, this message translates to:
  /// **'There is no request to add friends currently'**
  String get noFriendRequestText;

  /// self text
  ///
  /// In en, this message translates to:
  /// **'I am '**
  String get selfText;

  /// note text
  ///
  /// In en, this message translates to:
  /// **'Friend request notes'**
  String get noteText;

  /// Request sending failed text
  ///
  /// In en, this message translates to:
  /// **'Request send failed'**
  String get sendRequestFailedText;

  /// Request send successfully text
  ///
  /// In en, this message translates to:
  /// **'You have sent a friend request'**
  String get sendRequestSuccess;

  /// You cannot add yourself text
  ///
  /// In en, this message translates to:
  /// **'You cannot add yourself as a friend'**
  String get cannotAddSelf;

  /// The user does not exist text
  ///
  /// In en, this message translates to:
  /// **'The user does not exist'**
  String get userNotExist;

  /// Please try later text
  ///
  /// In en, this message translates to:
  /// **'Please try later'**
  String get tryLaterText;

  /// get qr code err text
  ///
  /// In en, this message translates to:
  /// **'Fail to get QR code, unknown exception'**
  String get qrCodeErrDetail;

  /// qr code expired text
  ///
  /// In en, this message translates to:
  /// **'QR code has expired, please refresh and try again'**
  String get qrCodeExpired;

  /// add friends text
  ///
  /// In en, this message translates to:
  /// **'Processing error after scanning code to add friends'**
  String get scanFriendFailedText;

  /// label for selecting users of a group chat
  ///
  /// In en, this message translates to:
  /// **'Please select the users to join the group.'**
  String get selectUsersForGroupChatText;

  /// no device is available to chat error message text
  ///
  /// In en, this message translates to:
  /// **'No device is available to chat.'**
  String get noDeviceAvailableToChatMessageText;

  /// group chat info missing error text
  ///
  /// In en, this message translates to:
  /// **'Group chat information is missing.'**
  String get groupChatInfoMissingErrorText;

  /// invalid number of chat users error text
  ///
  /// In en, this message translates to:
  /// **'Invalid number of users.'**
  String get invalidChatUserCountErrorText;

  /// Chat text
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatText;

  /// chat with all devices title text
  ///
  /// In en, this message translates to:
  /// **'Chat with all available devices of this user'**
  String get chatWithAllDevicesText;

  /// chat with single device title text
  ///
  /// In en, this message translates to:
  /// **'Chat with a device of this user'**
  String get chatWithSingleDeviceText;

  /// All devices
  ///
  /// In en, this message translates to:
  /// **'All devices'**
  String get allDevicesText;

  /// user text
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userText;

  /// Personal user text
  ///
  /// In en, this message translates to:
  /// **'Community user'**
  String get personalUsers;

  /// chat with user text
  ///
  /// In en, this message translates to:
  /// **'Chat with {username}'**
  String chatWithUserText(Object username);

  /// prompt , dialog title
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get prompt;

  /// Success text
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successText;

  /// Failed text
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedText;

  /// Binding failure text.
  ///
  /// In en, this message translates to:
  /// **'Failed to add the mobile phone number.'**
  String get bindFailedContent;

  /// set verbosity level text
  ///
  /// In en, this message translates to:
  /// **'Daemon logging verbosity level'**
  String get setVerbosityLevelText;

  /// display name text
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameText;

  /// email label text
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailText;

  /// audio only text
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get audioOnlyText;

  /// audio muted text
  ///
  /// In en, this message translates to:
  /// **'Audio muted'**
  String get audioMutedText;

  /// video muted text
  ///
  /// In en, this message translates to:
  /// **'Video muted'**
  String get videoMutedText;

  /// waiting for peer to answer call text
  ///
  /// In en, this message translates to:
  /// **'Waiting for {peer} to answer the call'**
  String videoWaitingForPeerToAnswerText(String peer);

  /// AR Glasses Mode text
  ///
  /// In en, this message translates to:
  /// **'AR Glasses Mode'**
  String get enableARSetting;

  /// Enable TV Mode text
  ///
  /// In en, this message translates to:
  /// **'Enable TV Mode'**
  String get enableTVSetting;

  /// TV Mode text
  ///
  /// In en, this message translates to:
  /// **'TV Mode'**
  String get tvModeText;

  /// save to file text
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get saveToFileText;

  /// save to photos text
  ///
  /// In en, this message translates to:
  /// **'Save to photos'**
  String get saveToGalleryText;

  /// image saved to file text
  ///
  /// In en, this message translates to:
  /// **'Image saved to {file}'**
  String imageSavedToFileText(String file);

  /// image saved to gallery text
  ///
  /// In en, this message translates to:
  /// **'Image saved to gallery'**
  String get imageSavedToGalleryText;

  /// error saving image text
  ///
  /// In en, this message translates to:
  /// **'Error saving media'**
  String get errSavingImageText;

  /// unsupported image or video format text
  ///
  /// In en, this message translates to:
  /// **'Unsupported image or video format'**
  String get unsupportedMediaText;

  /// camera text
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraText;

  /// No description provided for @galleryText.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryText;

  /// please download WeChat app text
  ///
  /// In en, this message translates to:
  /// **'Please download WeChat app first'**
  String get downloadWeChatText;

  /// video text
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoText;

  /// No description provided for @selectUserForVideoCallText.
  ///
  /// In en, this message translates to:
  /// **'Select user to join the video call'**
  String get selectUserForVideoCallText;

  /// switch camera text
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCameraText;

  /// toggle flash text
  ///
  /// In en, this message translates to:
  /// **'Toggle flash'**
  String get toggleFlashText;

  /// No description provided for @scanFromImageText.
  ///
  /// In en, this message translates to:
  /// **'Scan from image'**
  String get scanFromImageText;

  /// empty qr code text
  ///
  /// In en, this message translates to:
  /// **'QR code is empty'**
  String get emptyQrCodeText;

  /// recent chats text
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get recentChatsText;

  /// message send results text
  ///
  /// In en, this message translates to:
  /// **'Message send results'**
  String get messageSendResultsText;

  /// success device count text
  ///
  /// In en, this message translates to:
  /// **'Success device count'**
  String get successDeviceCountText;

  /// failure device count
  ///
  /// In en, this message translates to:
  /// **'Failure device count'**
  String get failureDeviceCountText;

  /// don't show again text
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get dontShowAgainText;

  /// No description provided for @fileSavedToText.
  ///
  /// In en, this message translates to:
  /// **'File saved to'**
  String get fileSavedToText;

  /// failed to save file text
  ///
  /// In en, this message translates to:
  /// **'Failed to save file'**
  String get failedToSaveFileText;

  /// save to app storage text
  ///
  /// In en, this message translates to:
  /// **'Save to app storage'**
  String get saveToAppStorageText;

  /// save to shared storage text
  ///
  /// In en, this message translates to:
  /// **'Save to shared storage'**
  String get saveToSharedStorageText;

  /// forward text
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardText;

  /// retry sending to failed device text
  ///
  /// In en, this message translates to:
  /// **'Retry sending to failed devices'**
  String get retrySendingToFailedDevicesText;

  /// shared text text
  ///
  /// In en, this message translates to:
  /// **'Shared text'**
  String get sharedTextText;

  /// forward messages to text
  ///
  /// In en, this message translates to:
  /// **'Forward messages to'**
  String get forwardMessagesToText;

  /// high text
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get highText;

  /// higher text
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get higherText;

  /// low text
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get lowText;

  /// medium text
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get mediumText;

  /// standard text
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardText;

  /// force to turn off text
  ///
  /// In en, this message translates to:
  /// **'Force to turn off'**
  String get forceToTurnOffText;

  /// turn on success text
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to cylonix'**
  String get turnOnSuccessText;

  /// turn off success text
  ///
  /// In en, this message translates to:
  /// **'Successfully disconnected from cylonix'**
  String get turnOffSuccessText;

  /// more options text
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsText;

  /// add account details text
  ///
  /// In en, this message translates to:
  /// **'Add account details'**
  String get addAccountDetailsText;

  /// add account details hint text
  ///
  /// In en, this message translates to:
  /// **'For example, set up username or add email'**
  String get addAccountDetailsHintText;

  /// add account details succeed text
  ///
  /// In en, this message translates to:
  /// **'Add account details succeed.'**
  String get addAccountDetailsSucceedText;

  /// add account details failed text
  ///
  /// In en, this message translates to:
  /// **'Failed to add account details.'**
  String get addAccountDetailsFailedText;

  /// First name text
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameText;

  /// last name text
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameText;

  /// No description provided for @inputHasNoUpdateText.
  ///
  /// In en, this message translates to:
  /// **'Input has no update'**
  String get inputHasNoUpdateText;

  /// update profile picture text
  ///
  /// In en, this message translates to:
  /// **'Update profile picture'**
  String get updateProfilePictureText;

  /// user avatar not exists text
  ///
  /// In en, this message translates to:
  /// **'User avatar does not exist'**
  String get userAvatarNotExistsText;

  /// reply text
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyText;

  /// simple chat UI text
  ///
  /// In en, this message translates to:
  /// **'Simple chat user interface'**
  String get simpleChatUI;

  /// only group chat administrator can remove member text
  ///
  /// In en, this message translates to:
  /// **'Only group chat administrator can remove member'**
  String get onlyGroupChatAdminCanRemoveMemberText;

  /// generate a new room ID text
  ///
  /// In en, this message translates to:
  /// **'Generate a new room ID'**
  String get generateNewRoomIDText;

  /// use default room text
  ///
  /// In en, this message translates to:
  /// **'Use default room'**
  String get useDefaultRoomText;

  /// delete all chat messages text
  ///
  /// In en, this message translates to:
  /// **'Delete all chat messages'**
  String get deleteAllChatMessagesText;

  /// confirm delete all chat messages text
  ///
  /// In en, this message translates to:
  /// **'Please confirm if to delete all chat messages. Messages will be forever deleted.'**
  String get confirmDeleteAllChatMessagesText;

  /// delete all chat messages succeeded text
  ///
  /// In en, this message translates to:
  /// **'Delete all chat messages succeeded.'**
  String get deleteAllChatMessagesSucceededText;

  /// failed to delete all chat messages text
  ///
  /// In en, this message translates to:
  /// **'Failed to delete all chat messages.'**
  String get deleteAllChatMessagesFailedText;

  /// set message expiration time text
  ///
  /// In en, this message translates to:
  /// **'Set message expiration time'**
  String get setMessageExpirationTimeText;

  /// 15 seconds text
  ///
  /// In en, this message translates to:
  /// **'15 seconds'**
  String get fifteenSecondsText;

  /// 1 minute text
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get oneMinuteText;

  /// 1 hour text
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get oneHourText;

  /// 1 day text
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get oneDayText;

  /// no expiration text
  ///
  /// In en, this message translates to:
  /// **'No expiration'**
  String get noExpirationText;

  /// remote not exists text
  ///
  /// In en, this message translates to:
  /// **'Remote does not exist.'**
  String get remoteNotExistsText;

  /// No description provided for @remoteNameTxt.
  ///
  /// In en, this message translates to:
  /// **'Remote name'**
  String get remoteNameTxt;

  /// input remote text
  ///
  /// In en, this message translates to:
  /// **'Input remote device code or IP or name'**
  String get inputRemoteText;

  /// user not available text
  ///
  /// In en, this message translates to:
  /// **'{user} is not available'**
  String userNotAvailableText(Object user);

  /// home text
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeText;

  /// sidebar text
  ///
  /// In en, this message translates to:
  /// **'SideBar'**
  String get sidebarText;

  /// check for app update text
  ///
  /// In en, this message translates to:
  /// **'Check for app update'**
  String get checkForUpdateText;

  /// click to update text
  ///
  /// In en, this message translates to:
  /// **'Click to update app'**
  String get clickToUpdateText;

  /// cannot launch URL text
  ///
  /// In en, this message translates to:
  /// **'Cannot launch URL'**
  String get cannotLaunchUrlText;

  /// confirm to overwrite file text
  ///
  /// In en, this message translates to:
  /// **'File exists already. Do you want to overwrite it?'**
  String get confirmToOverwriteFileText;

  /// expand text
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expandText;

  /// compact text
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compactText;

  /// show intro page on next start text
  ///
  /// In en, this message translates to:
  /// **'Show user agreement and privacy policy pages on next app start'**
  String get showIntroPagesOnNextStartText;

  /// restart daemon service text
  ///
  /// In en, this message translates to:
  /// **'Restart daemon service'**
  String get restartDaemonServiceText;

  /// confirm to restart daemon service text
  ///
  /// In en, this message translates to:
  /// **'To restore the service we need to restart the daemon process. It may ask you to approve the change with administrator permission twice. Please approve the changes when being prompted.'**
  String get confirmRestartDaemonServiceText;

  /// change text
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeText;

  /// done text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneText;

  /// search user text
  ///
  /// In en, this message translates to:
  /// **'Search user'**
  String get searchUserText;

  /// cannot invite self text
  ///
  /// In en, this message translates to:
  /// **'Cannot invite self'**
  String get cannotInviteSelfText;

  /// server is not reachable text
  ///
  /// In en, this message translates to:
  /// **'{server} is not reachable. Please try again later.'**
  String serverNotReachableText(Object server);

  /// start time text
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTimeText;

  /// page up text
  ///
  /// In en, this message translates to:
  /// **'Page up'**
  String get pageUpText;

  /// page down text
  ///
  /// In en, this message translates to:
  /// **'Page down'**
  String get pageDownText;

  /// details of why there is no user available
  ///
  /// In en, this message translates to:
  /// **'No user is available. This could be due to either there is no user online or any newly added user is not yet sync\'ed to your device. It may take as long as a minute to be synced up.'**
  String get noUserAvailableDetailsText;

  /// to start text
  ///
  /// In en, this message translates to:
  /// **'To start'**
  String get toStartText;

  /// instant video call text
  ///
  /// In en, this message translates to:
  /// **'Start call'**
  String get addVideoCallText;

  /// return text
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnText;

  /// open to edit text
  ///
  /// In en, this message translates to:
  /// **'Open to edit'**
  String get openToEditText;

  /// No description provided for @meetingOptionText.
  ///
  /// In en, this message translates to:
  /// **'meeting options'**
  String get meetingOptionText;

  /// bitrate scale factor text
  ///
  /// In en, this message translates to:
  /// **'Bitrate scale factor'**
  String get bitrateScaleFactorText;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// Select date label
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDateLabel;

  /// Select time label
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTimeLabel;

  /// AM text
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get amText;

  /// PM text
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pmText;

  /// 24 hour text
  ///
  /// In en, this message translates to:
  /// **'24 hour'**
  String get twentyFourHourText;

  /// set meeting options label
  ///
  /// In en, this message translates to:
  /// **'Set meeting options'**
  String get setMeetingOptionsLabel;

  /// set portrait mode label
  ///
  /// In en, this message translates to:
  /// **'Set portrait mode'**
  String get setPortraitModeLabel;

  /// enable simulcast label
  ///
  /// In en, this message translates to:
  /// **'Enable simulcast'**
  String get enableSimulcastLabel;

  /// appearance title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// appearance settings title
  ///
  /// In en, this message translates to:
  /// **'Appearance settings'**
  String get appearanceSettingsTitle;

  /// feature title
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get featureTitle;

  /// feature settings title
  ///
  /// In en, this message translates to:
  /// **'Feature settings'**
  String get featureSettingsTitle;

  /// network title
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkTitle;

  /// network settings title
  ///
  /// In en, this message translates to:
  /// **'Network settings'**
  String get networkSettingsTitle;

  /// shields up title
  ///
  /// In en, this message translates to:
  /// **'Shields up'**
  String get shieldsUpTitle;

  /// don't allow incoming connections text
  ///
  /// In en, this message translates to:
  /// **'Don\'t allow incoming connections.'**
  String get dontAllowIncomingConnectionsText;

  /// failed to save change text
  ///
  /// In en, this message translates to:
  /// **'failed to save change'**
  String get failedToSaveChangeText;

  /// press one more time in 10 seconds to exit the app text
  ///
  /// In en, this message translates to:
  /// **'Press one more time in 10 seconds to exit the app.'**
  String get pressOneMoreTimeToExitTheAppText;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
