// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'collapse';

  @override
  String get chats => 'Chats';

  @override
  String get contacts => 'Contacts';

  @override
  String get profile => 'Profile';

  @override
  String get resizeSidebar => 'Resize sidebar';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get routeUnavailable => 'Page unavailable — back to chats';

  @override
  String get signIn => 'Sign in';

  @override
  String get register => 'Create account';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display name';

  @override
  String get usernameHint => '4–32 characters';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get authHint => 'Your account lives on this Tinode server.';

  @override
  String get server => 'Server';

  @override
  String get missingConfig =>
      'The Tinode application key is missing. Start the app with the server\'s client.json configuration.';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm =>
      'Sign out on this device? Cached messages stay on this device and remain isolated from other accounts.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get copy => 'Copy';

  @override
  String get revealSpoiler => 'Reveal spoiler';

  @override
  String get reply => 'Reply';

  @override
  String get forward => 'Forward';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get deleteConfirm => 'Delete this message?';

  @override
  String get copied => 'Copied';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline — queued messages will be sent when connected';

  @override
  String get connecting => 'Connecting…';

  @override
  String get connectionError =>
      'Unable to connect. Check the server and try again.';

  @override
  String get authError =>
      'Could not sign in. Check your username and password.';

  @override
  String get operationError =>
      'Could not complete the action. Please try again.';

  @override
  String get emptyChats => 'No chats yet. Find someone in Contacts.';

  @override
  String get emptyContacts =>
      'Search by username to find people on this server.';

  @override
  String get search => 'Search username';

  @override
  String get noResults => 'No contacts found';

  @override
  String get message => 'Message';

  @override
  String get messageHint => 'Write a message…';

  @override
  String get emptyMessages => 'Say hello';

  @override
  String get send => 'Send';

  @override
  String get attachment => 'Attach';

  @override
  String get photo => 'Photo';

  @override
  String get camera => 'Camera';

  @override
  String get video => 'Video';

  @override
  String get file => 'File';

  @override
  String get audio => 'Voice message';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get sticker => 'Image as sticker';

  @override
  String get record => 'Record voice message';

  @override
  String get stopRecording => 'Stop and send';

  @override
  String get recording => 'Recording…';

  @override
  String get permissionDenied =>
      'Permission was not granted. You can enable it in device settings.';

  @override
  String get attachmentTooLarge => 'The attachment exceeds the 10 MB limit.';

  @override
  String get unsupportedMessage => 'Unsupported message';

  @override
  String get deletedMessage => 'Message deleted';

  @override
  String get forwardedMessage => 'Forwarded message';

  @override
  String get replying => 'Replying to a message';

  @override
  String get messageUnavailable => 'This message is unavailable.';

  @override
  String get latestMessages => 'Latest messages';

  @override
  String newMessages(int count) {
    return '$count new messages';
  }

  @override
  String get unreadMessages => 'Unread messages';

  @override
  String get queued => 'Queued';

  @override
  String get sending => 'Sending';

  @override
  String get sent => 'Sent';

  @override
  String get received => 'Delivered';

  @override
  String get read => 'Read';

  @override
  String get failed => 'Not sent';

  @override
  String get about => 'About';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get startChat => 'Start chat';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get english => 'English';

  @override
  String get russian => 'Russian';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get notifications => 'Notifications';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get pushNotConfigured =>
      'Push notifications require this app\'s Firebase configuration and the server\'s push-provider credentials.';

  @override
  String get notificationsEnabled => 'Notifications enabled';

  @override
  String get selectChat => 'Choose a chat';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get create => 'Create';

  @override
  String get members => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get userId => 'User ID';

  @override
  String get download => 'Open attachment';

  @override
  String get loading => 'Loading…';

  @override
  String get refresh => 'Refresh';

  @override
  String get searchMessages => 'Search messages';

  @override
  String get searchWords => 'Words or word beginnings';

  @override
  String get searchScope =>
      'Search text saved on this device in this chat. Matches words or word beginnings, ignoring case.';

  @override
  String get indexingMessages => 'Preparing saved messages…';

  @override
  String get searchComplete => 'All chat history is available for search';

  @override
  String get searchPartial =>
      'Searching saved messages; some history is not downloaded';

  @override
  String get loadOlderMessages => 'Load more history';

  @override
  String get noMessageMatches => 'No matching messages';

  @override
  String get newerResults => 'Newer results';

  @override
  String get olderResults => 'Older results';

  @override
  String get mediaGallery => 'Shared archive';

  @override
  String get mediaVisual => 'Media';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get mediaFiles => 'Files';

  @override
  String get mediaCached => 'Offline · saved on this device';

  @override
  String get mediaEmpty => 'Nothing here yet';

  @override
  String get mediaUnavailable => 'This media is unavailable';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get resetZoom => 'Reset zoom';
}
