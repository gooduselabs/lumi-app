// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Meet kindred souls';

  @override
  String get welcomeTitle => 'Chat anonymously,\nconnect for real';

  @override
  String get welcomeSubtitle =>
      'Get matched with a random stranger. If you both like each other, you become friends.';

  @override
  String get getStarted => 'Get started';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get newPassword => 'New password';

  @override
  String get login => 'Log in';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Log in to keep chatting';

  @override
  String get register => 'Sign up';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Just your email. We\'ll send a 6-digit code.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotTitle => 'Forgot password';

  @override
  String get forgotSubtitle =>
      'Enter your email and we\'ll send you a reset code.';

  @override
  String get sendCode => 'Send code';

  @override
  String get resetTitle => 'Reset password';

  @override
  String resetSubtitle(String email) {
    return 'Enter the 6-digit code sent to $email and a new password.';
  }

  @override
  String get resetAction => 'Change password';

  @override
  String get verifyTitle => 'Verify your email';

  @override
  String verifySubtitle(String email) {
    return 'Enter the 6-digit code we sent to\n$email';
  }

  @override
  String get verifyAction => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get codeSent => 'A new code was sent';

  @override
  String devCodeHint(String code) {
    return 'Dev code: $code — tap to fill';
  }

  @override
  String get noAccount => 'No account yet?';

  @override
  String get termsNote =>
      'By continuing you confirm you\'re 18+ and agree to the Terms & Community Guidelines.';

  @override
  String get validationEmail => 'Invalid email';

  @override
  String get validationPassword =>
      'At least 8 characters with letters and numbers';

  @override
  String get validationPasswordMatch => 'Passwords don\'t match';

  @override
  String get validationRequired => 'Required';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String onbStep(int current, int total) {
    return 'Step $current/$total';
  }

  @override
  String get onbNameTitle => 'What\'s your name?';

  @override
  String get onbNameSubtitle =>
      'Your nickname is only shown once you become friends.';

  @override
  String get nickname => 'Nickname';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get onbBirthdayTitle => 'Your birthday';

  @override
  String get onbBirthdaySubtitle =>
      'Lumi is for adults 18+. Only your age is shown, never the date.';

  @override
  String get pickBirthday => 'Pick your birthday';

  @override
  String ageYears(int age) {
    return '$age years old';
  }

  @override
  String get underageError => 'You must be 18 or older to use Lumi';

  @override
  String get onbAvatarTitle => 'Pick an avatar';

  @override
  String get onbAvatarSubtitle =>
      'No real photo needed. Choose a character that feels like you.';

  @override
  String get onbInterestsTitle => 'Interests & bio';

  @override
  String onbInterestsSubtitle(int max) {
    return 'Pick up to $max interests to find people on your wavelength.';
  }

  @override
  String get bio => 'Short bio';

  @override
  String get bioHint => 'A line about you…';

  @override
  String get next => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Finish';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabMe => 'Me';

  @override
  String hello(String name) {
    return 'Hi, $name';
  }

  @override
  String onlineNow(int count) {
    return '$count people online';
  }

  @override
  String get soulMatch => 'Soul Match';

  @override
  String soulMatchDesc(int minutes) {
    return '$minutes-minute anonymous chat with a stranger';
  }

  @override
  String get voiceMatch => 'Voice Match';

  @override
  String voiceMatchDesc(int minutes) {
    return '$minutes-minute anonymous voice call';
  }

  @override
  String get matchFilter => 'Meet';

  @override
  String get filterAny => 'Everyone';

  @override
  String get start => 'Start';

  @override
  String get howItWorks => 'How it works';

  @override
  String get how1 => 'Get paired with a random stranger online';

  @override
  String get how2 => 'Chat anonymously before time runs out';

  @override
  String get how3 => 'Both tap the heart → you\'re friends';

  @override
  String get searching => 'Finding someone for you…';

  @override
  String get searchingHint => 'Keep the app open. It usually takes seconds.';

  @override
  String get cancel => 'Cancel';

  @override
  String get stranger => 'Mysterious stranger';

  @override
  String get commonInterests => 'In common';

  @override
  String get soulIntro => 'You\'re matched! Say hi before the timer runs out.';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get partnerTyping => 'Typing…';

  @override
  String get partnerLiked => 'Your match liked you 💜';

  @override
  String get youLiked => 'You liked them. Waiting for them…';

  @override
  String get like => 'Like';

  @override
  String get skip => 'Skip';

  @override
  String get skipConfirm => 'End this conversation?';

  @override
  String get endedTimeout => 'Time\'s up';

  @override
  String get endedSkipped => 'The chat has ended';

  @override
  String get endedPartnerSkipped => 'Your match left';

  @override
  String get endedPartnerLeft => 'Your match disconnected';

  @override
  String get endedBlocked => 'You blocked this user';

  @override
  String get endedHint => 'No worries, the next one might be your soulmate!';

  @override
  String get findAnother => 'Find someone else';

  @override
  String get backHome => 'Back home';

  @override
  String get mutualTitle => 'You\'re now friends!';

  @override
  String mutualSubtitle(String name) {
    return 'You can now chat with $name anytime.';
  }

  @override
  String get sayHi => 'Say hi';

  @override
  String get voiceConnecting => 'Connecting audio…';

  @override
  String get voiceConnected => 'On air';

  @override
  String get voiceUnavailable => 'Voice Match isn\'t enabled on this server';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get speaking => 'Speaking…';

  @override
  String get micPermission => 'Microphone permission is required';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get noChats => 'No conversations yet';

  @override
  String get noChatsHint => 'Try Soul Match to make new friends!';

  @override
  String get noFriends => 'No friends yet';

  @override
  String get goMatch => 'Go match';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get seen => 'Seen';

  @override
  String get sent => 'Sent';

  @override
  String get sending => 'Sending…';

  @override
  String get failedTapRetry => 'Failed · tap to retry';

  @override
  String get systemMatched => 'You connected via Soul Match ✨';

  @override
  String get chatBlocked => 'You can\'t message this user';

  @override
  String get you => 'You';

  @override
  String get unfriend => 'Unfriend';

  @override
  String get unfriendConfirm => 'Unfriend and delete the chat history?';

  @override
  String get viewProfile => 'View profile';

  @override
  String get feedTitle => 'Feed';

  @override
  String get feedEmpty => 'No posts yet';

  @override
  String get feedEmptyHint => 'Be the first to share a moment!';

  @override
  String get newPost => 'Share a moment';

  @override
  String get postHint => 'What\'s on your mind?';

  @override
  String get post => 'Post';

  @override
  String get deletePost => 'Delete post';

  @override
  String get posted => 'Posted';

  @override
  String get me => 'Me';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get settings => 'Settings';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get interests => 'Interests';

  @override
  String get language => 'Language';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noBlocked => 'You haven\'t blocked anyone';

  @override
  String get unblock => 'Unblock';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Log out of Lumi?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirm =>
      'All your data, friends and messages will be permanently deleted. Continue?';

  @override
  String get about => 'About';

  @override
  String get server => 'Server';

  @override
  String get version => 'Version';

  @override
  String get safetyCenter => 'Community safety';

  @override
  String get safetyText =>
      'Never share personal info with strangers. Report harassment right away.';

  @override
  String get report => 'Report';

  @override
  String get block => 'Block';

  @override
  String get blockConfirm =>
      'Block this user? You won\'t be matched or able to message each other.';

  @override
  String get reportTitle => 'Report user';

  @override
  String get reportReason => 'Reason';

  @override
  String get reasonSpam => 'Spam / ads';

  @override
  String get reasonHarassment => 'Harassment';

  @override
  String get reasonInappropriate => 'Inappropriate content';

  @override
  String get reasonUnderage => 'Underage';

  @override
  String get reasonScam => 'Scam';

  @override
  String get reasonOther => 'Other';

  @override
  String get reportDetails => 'More details (optional)';

  @override
  String get reportSent => 'Thanks! We\'ll review your report.';

  @override
  String get submit => 'Submit';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get connecting => 'Connecting…';

  @override
  String get somethingWrong => 'Something went wrong';

  @override
  String get errNetwork =>
      'Can\'t reach the server. Check your connection or server address.';

  @override
  String get errInvalidCredentials => 'Wrong email or password';

  @override
  String get errEmailTaken => 'This email is already registered';

  @override
  String get errInvalidCode => 'Invalid or expired code';

  @override
  String get errTooManyAttempts => 'Too many attempts. Request a new code.';

  @override
  String errCooldown(int seconds) {
    return 'Please wait ${seconds}s before requesting another code';
  }

  @override
  String get errSession => 'Your session expired. Please log in again.';

  @override
  String get errRateLimited => 'You\'re going too fast, try again shortly';

  @override
  String get errSessionClosed => 'This match has ended';

  @override
  String get errBlocked => 'You can\'t interact with this user';

  @override
  String get interest_music => 'Music';

  @override
  String get interest_movies => 'Movies';

  @override
  String get interest_gaming => 'Gaming';

  @override
  String get interest_travel => 'Travel';

  @override
  String get interest_food => 'Food';

  @override
  String get interest_sports => 'Sports';

  @override
  String get interest_reading => 'Reading';

  @override
  String get interest_anime => 'Anime';

  @override
  String get interest_photography => 'Photography';

  @override
  String get interest_art => 'Art';

  @override
  String get interest_tech => 'Tech';

  @override
  String get interest_pets => 'Pets';

  @override
  String get interest_fitness => 'Fitness';

  @override
  String get interest_coffee => 'Coffee';

  @override
  String get interest_fashion => 'Fashion';

  @override
  String get interest_kpop => 'K-pop';

  @override
  String get interest_astrology => 'Astrology';

  @override
  String get interest_dance => 'Dance';

  @override
  String get interest_nature => 'Nature';

  @override
  String get interest_study => 'Study';

  @override
  String get filters => 'Filters';

  @override
  String get ageRange => 'Age range';

  @override
  String ageRangeValue(int min, int max) {
    return '$min – $max years';
  }

  @override
  String get ageRangeHint =>
      'Only matches people in this range who also accept your age.';

  @override
  String get genderFilter => 'Gender';

  @override
  String get preferNearby => 'Prefer people nearby';

  @override
  String get preferNearbyDesc => 'Match within ~30 km when possible';

  @override
  String get nearbyTitle => 'People nearby';

  @override
  String get nearbyDesc => 'See who\'s around you';

  @override
  String distanceApprox(int km) {
    return '~$km km';
  }

  @override
  String get radius => 'Radius';

  @override
  String radiusKm(int km) {
    return '$km km';
  }

  @override
  String get locationEnable => 'Enable location';

  @override
  String get locationWhy =>
      'Lumi only stores an approximate location (~1 km). Others only see a rough distance, never your coordinates.';

  @override
  String get locationDenied => 'Location permission was denied.';

  @override
  String get locationDeniedForever =>
      'Location is blocked. Enable it in Settings.';

  @override
  String get locationServiceOff => 'Location services are off.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get hideLocation => 'Hide my location';

  @override
  String get hideLocationDesc => 'Don\'t appear in Nearby or distance matching';

  @override
  String get locationHiddenInfo =>
      'Your location is hidden. Turn it back on to see people nearby.';

  @override
  String get removeLocation => 'Remove saved location';

  @override
  String get updateLocation => 'Update location';

  @override
  String get nearbyEmpty => 'Nobody in this radius yet. Try a wider radius!';

  @override
  String get attachPhoto => 'Photo';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachFile => 'File';

  @override
  String get holdToRecord => 'Hold to record';

  @override
  String get releaseToSend => 'Release to send · slide left to cancel';

  @override
  String get recordTooShort => 'Voice message too short';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get photoMessage => 'Photo';

  @override
  String fileTooLarge(int mb) {
    return 'File is larger than $mb MB';
  }

  @override
  String get fileTypeNotAllowed => 'This file type isn\'t supported';

  @override
  String get uploading => 'Uploading…';

  @override
  String get download => 'Download';

  @override
  String get callVoice => 'Voice call';

  @override
  String get calling => 'Calling…';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String incomingCallFrom(String name) {
    return '$name is calling you';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get hangUp => 'Hang up';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callDeclined => 'Call declined';

  @override
  String get callNoAnswer => 'No answer';

  @override
  String get peerBusy => 'Your friend is in another call';

  @override
  String get speaker => 'Speaker';

  @override
  String get errInvalidAgeRange => 'Invalid age range';
}
