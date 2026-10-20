import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In vi, this message translates to:
  /// **'Gặp gỡ những tâm hồn đồng điệu'**
  String get appTagline;

  /// No description provided for @welcomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trò chuyện ẩn danh,\nkết nối thật lòng'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghép đôi ngẫu nhiên với người lạ. Nếu cả hai cùng thích, hai bạn sẽ thành bạn bè.'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get getStarted;

  /// No description provided for @haveAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đã có tài khoản'**
  String get haveAccount;

  /// No description provided for @email.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Nhập lại mật khẩu'**
  String get confirmPassword;

  /// No description provided for @newPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get newPassword;

  /// No description provided for @login.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get login;

  /// No description provided for @loginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tiếp tục trò chuyện'**
  String get loginSubtitle;

  /// No description provided for @register.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get register;

  /// No description provided for @registerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ cần email. Chúng tôi sẽ gửi mã xác minh 6 số.'**
  String get registerSubtitle;

  /// No description provided for @forgotPassword.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get forgotPassword;

  /// No description provided for @forgotTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email đã đăng ký, chúng tôi sẽ gửi mã đặt lại mật khẩu.'**
  String get forgotSubtitle;

  /// No description provided for @sendCode.
  ///
  /// In vi, this message translates to:
  /// **'Gửi mã'**
  String get sendCode;

  /// No description provided for @resetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại mật khẩu'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã 6 số đã gửi tới {email} và mật khẩu mới.'**
  String resetSubtitle(String email);

  /// No description provided for @resetAction.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get resetAction;

  /// No description provided for @verifyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh email'**
  String get verifyTitle;

  /// No description provided for @verifySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã 6 số chúng tôi vừa gửi tới\n{email}'**
  String verifySubtitle(String email);

  /// No description provided for @verifyAction.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh'**
  String get verifyAction;

  /// No description provided for @resendCode.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại mã'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại sau {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @codeSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi mã mới'**
  String get codeSent;

  /// No description provided for @devCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Mã thử nghiệm (dev): {code} — chạm để điền'**
  String devCodeHint(String code);

  /// No description provided for @noAccount.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản?'**
  String get noAccount;

  /// No description provided for @termsNote.
  ///
  /// In vi, this message translates to:
  /// **'Bằng việc tiếp tục, bạn xác nhận đã đủ 18 tuổi và đồng ý với Điều khoản & Chính sách cộng đồng.'**
  String get termsNote;

  /// No description provided for @validationEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get validationEmail;

  /// No description provided for @validationPassword.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 8 ký tự, gồm cả chữ và số'**
  String get validationPassword;

  /// No description provided for @validationPasswordMatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu không khớp'**
  String get validationPasswordMatch;

  /// No description provided for @validationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get validationRequired;

  /// No description provided for @passwordChanged.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu'**
  String get passwordChanged;

  /// No description provided for @onbStep.
  ///
  /// In vi, this message translates to:
  /// **'Bước {current}/{total}'**
  String onbStep(int current, int total);

  /// No description provided for @onbNameTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn tên là gì?'**
  String get onbNameTitle;

  /// No description provided for @onbNameSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh sẽ chỉ hiện khi hai bạn đã thành bạn bè.'**
  String get onbNameSubtitle;

  /// No description provided for @nickname.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh'**
  String get nickname;

  /// No description provided for @gender.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get genderOther;

  /// No description provided for @onbBirthdayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sinh nhật của bạn'**
  String get onbBirthdayTitle;

  /// No description provided for @onbBirthdaySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Lumi chỉ dành cho người từ 18 tuổi trở lên. Ngày sinh không hiển thị công khai, chỉ hiện tuổi.'**
  String get onbBirthdaySubtitle;

  /// No description provided for @pickBirthday.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày sinh'**
  String get pickBirthday;

  /// No description provided for @ageYears.
  ///
  /// In vi, this message translates to:
  /// **'{age} tuổi'**
  String ageYears(int age);

  /// No description provided for @underageError.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần đủ 18 tuổi để sử dụng Lumi'**
  String get underageError;

  /// No description provided for @onbAvatarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn avatar'**
  String get onbAvatarTitle;

  /// No description provided for @onbAvatarSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Không cần ảnh thật. Hãy chọn nhân vật đại diện cho bạn.'**
  String get onbAvatarSubtitle;

  /// No description provided for @onbInterestsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sở thích & giới thiệu'**
  String get onbInterestsTitle;

  /// No description provided for @onbInterestsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tối đa {max} sở thích để dễ tìm người hợp gu.'**
  String onbInterestsSubtitle(int max);

  /// No description provided for @bio.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu ngắn'**
  String get bio;

  /// No description provided for @bioHint.
  ///
  /// In vi, this message translates to:
  /// **'Một câu về bạn…'**
  String get bioHint;

  /// No description provided for @next.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get next;

  /// No description provided for @back.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get back;

  /// No description provided for @finish.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất'**
  String get finish;

  /// No description provided for @tabDiscover.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get tabDiscover;

  /// No description provided for @tabFeed.
  ///
  /// In vi, this message translates to:
  /// **'Bảng tin'**
  String get tabFeed;

  /// No description provided for @tabChats.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get tabChats;

  /// No description provided for @tabMe.
  ///
  /// In vi, this message translates to:
  /// **'Tôi'**
  String get tabMe;

  /// No description provided for @hello.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào, {name}'**
  String hello(String name);

  /// No description provided for @onlineNow.
  ///
  /// In vi, this message translates to:
  /// **'{count} người đang online'**
  String onlineNow(int count);

  /// No description provided for @soulMatch.
  ///
  /// In vi, this message translates to:
  /// **'Soul Match'**
  String get soulMatch;

  /// No description provided for @soulMatchDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chat ẩn danh {minutes} phút với một người lạ'**
  String soulMatchDesc(int minutes);

  /// No description provided for @voiceMatch.
  ///
  /// In vi, this message translates to:
  /// **'Voice Match'**
  String get voiceMatch;

  /// No description provided for @voiceMatchDesc.
  ///
  /// In vi, this message translates to:
  /// **'Gọi thoại ẩn danh {minutes} phút'**
  String voiceMatchDesc(int minutes);

  /// No description provided for @matchFilter.
  ///
  /// In vi, this message translates to:
  /// **'Muốn gặp'**
  String get matchFilter;

  /// No description provided for @filterAny.
  ///
  /// In vi, this message translates to:
  /// **'Mọi người'**
  String get filterAny;

  /// No description provided for @start.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get start;

  /// No description provided for @howItWorks.
  ///
  /// In vi, this message translates to:
  /// **'Cách hoạt động'**
  String get howItWorks;

  /// No description provided for @how1.
  ///
  /// In vi, this message translates to:
  /// **'Ghép ngẫu nhiên với một người lạ đang online'**
  String get how1;

  /// No description provided for @how2.
  ///
  /// In vi, this message translates to:
  /// **'Trò chuyện ẩn danh trước khi hết giờ'**
  String get how2;

  /// No description provided for @how3.
  ///
  /// In vi, this message translates to:
  /// **'Cả hai cùng thả tim → thành bạn bè'**
  String get how3;

  /// No description provided for @searching.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm người phù hợp…'**
  String get searching;

  /// No description provided for @searchingHint.
  ///
  /// In vi, this message translates to:
  /// **'Giữ ứng dụng mở nhé. Thường mất vài giây.'**
  String get searchingHint;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @stranger.
  ///
  /// In vi, this message translates to:
  /// **'Người lạ bí ẩn'**
  String get stranger;

  /// No description provided for @commonInterests.
  ///
  /// In vi, this message translates to:
  /// **'Cùng thích'**
  String get commonInterests;

  /// No description provided for @soulIntro.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn đã được ghép! Hãy chào nhau trước khi hết giờ nhé.'**
  String get soulIntro;

  /// No description provided for @typeMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tin nhắn…'**
  String get typeMessage;

  /// No description provided for @partnerTyping.
  ///
  /// In vi, this message translates to:
  /// **'Đang soạn tin…'**
  String get partnerTyping;

  /// No description provided for @partnerLiked.
  ///
  /// In vi, this message translates to:
  /// **'Đối phương đã thả tim cho bạn 💜'**
  String get partnerLiked;

  /// No description provided for @youLiked.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã thả tim. Chờ đối phương…'**
  String get youLiked;

  /// No description provided for @like.
  ///
  /// In vi, this message translates to:
  /// **'Thích'**
  String get like;

  /// No description provided for @skip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get skip;

  /// No description provided for @skipConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc cuộc trò chuyện này?'**
  String get skipConfirm;

  /// No description provided for @endedTimeout.
  ///
  /// In vi, this message translates to:
  /// **'Hết giờ rồi'**
  String get endedTimeout;

  /// No description provided for @endedSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc trò chuyện đã kết thúc'**
  String get endedSkipped;

  /// No description provided for @endedPartnerSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Đối phương đã rời đi'**
  String get endedPartnerSkipped;

  /// No description provided for @endedPartnerLeft.
  ///
  /// In vi, this message translates to:
  /// **'Đối phương mất kết nối'**
  String get endedPartnerLeft;

  /// No description provided for @endedBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Đã chặn người này'**
  String get endedBlocked;

  /// No description provided for @endedHint.
  ///
  /// In vi, this message translates to:
  /// **'Đừng buồn, người tiếp theo có thể là tri kỷ của bạn!'**
  String get endedHint;

  /// No description provided for @findAnother.
  ///
  /// In vi, this message translates to:
  /// **'Tìm người khác'**
  String get findAnother;

  /// No description provided for @backHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get backHome;

  /// No description provided for @mutualTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn đã thành bạn bè!'**
  String get mutualTitle;

  /// No description provided for @mutualSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Giờ bạn có thể nhắn tin với {name} bất cứ lúc nào.'**
  String mutualSubtitle(String name);

  /// No description provided for @sayHi.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin ngay'**
  String get sayHi;

  /// No description provided for @voiceConnecting.
  ///
  /// In vi, this message translates to:
  /// **'Đang kết nối giọng nói…'**
  String get voiceConnecting;

  /// No description provided for @voiceConnected.
  ///
  /// In vi, this message translates to:
  /// **'Đang trò chuyện'**
  String get voiceConnected;

  /// No description provided for @voiceUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Voice Match chưa được bật trên máy chủ này'**
  String get voiceUnavailable;

  /// No description provided for @mute.
  ///
  /// In vi, this message translates to:
  /// **'Tắt mic'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In vi, this message translates to:
  /// **'Bật mic'**
  String get unmute;

  /// No description provided for @speaking.
  ///
  /// In vi, this message translates to:
  /// **'Đang nói…'**
  String get speaking;

  /// No description provided for @micPermission.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền micro để gọi thoại'**
  String get micPermission;

  /// No description provided for @chatsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get chatsTitle;

  /// No description provided for @friendsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè'**
  String get friendsTitle;

  /// No description provided for @noChats.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện'**
  String get noChats;

  /// No description provided for @noChatsHint.
  ///
  /// In vi, this message translates to:
  /// **'Thử Soul Match để kết bạn mới nhé!'**
  String get noChatsHint;

  /// No description provided for @noFriends.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bạn bè'**
  String get noFriends;

  /// No description provided for @goMatch.
  ///
  /// In vi, this message translates to:
  /// **'Đi ghép đôi'**
  String get goMatch;

  /// No description provided for @online.
  ///
  /// In vi, this message translates to:
  /// **'Đang online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In vi, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @seen.
  ///
  /// In vi, this message translates to:
  /// **'Đã xem'**
  String get seen;

  /// No description provided for @sent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get sent;

  /// No description provided for @sending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi…'**
  String get sending;

  /// No description provided for @failedTapRetry.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lỗi · chạm để thử lại'**
  String get failedTapRetry;

  /// No description provided for @systemMatched.
  ///
  /// In vi, this message translates to:
  /// **'Hai bạn đã kết nối qua Soul Match ✨'**
  String get systemMatched;

  /// No description provided for @chatBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không thể nhắn tin với người này'**
  String get chatBlocked;

  /// No description provided for @you.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get you;

  /// No description provided for @unfriend.
  ///
  /// In vi, this message translates to:
  /// **'Hủy kết bạn'**
  String get unfriend;

  /// No description provided for @unfriendConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Hủy kết bạn và xóa lịch sử trò chuyện?'**
  String get unfriendConfirm;

  /// No description provided for @viewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get viewProfile;

  /// No description provided for @feedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng tin'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài viết nào'**
  String get feedEmpty;

  /// No description provided for @feedEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Hãy là người đầu tiên chia sẻ khoảnh khắc!'**
  String get feedEmptyHint;

  /// No description provided for @newPost.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ khoảnh khắc'**
  String get newPost;

  /// No description provided for @postHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang nghĩ gì?'**
  String get postHint;

  /// No description provided for @post.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get post;

  /// No description provided for @deletePost.
  ///
  /// In vi, this message translates to:
  /// **'Xóa bài viết'**
  String get deletePost;

  /// No description provided for @posted.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng'**
  String get posted;

  /// No description provided for @me.
  ///
  /// In vi, this message translates to:
  /// **'Tôi'**
  String get me;

  /// No description provided for @editProfile.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get editProfile;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu'**
  String get saved;

  /// No description provided for @interests.
  ///
  /// In vi, this message translates to:
  /// **'Sở thích'**
  String get interests;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @blockedUsers.
  ///
  /// In vi, this message translates to:
  /// **'Người đã chặn'**
  String get blockedUsers;

  /// No description provided for @noBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa chặn ai'**
  String get noBlocked;

  /// No description provided for @unblock.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chặn'**
  String get unblock;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn đăng xuất?'**
  String get logoutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tài khoản'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ dữ liệu, bạn bè và tin nhắn sẽ bị xóa vĩnh viễn. Tiếp tục?'**
  String get deleteAccountConfirm;

  /// No description provided for @about.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get about;

  /// No description provided for @server.
  ///
  /// In vi, this message translates to:
  /// **'Máy chủ'**
  String get server;

  /// No description provided for @version.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản'**
  String get version;

  /// No description provided for @safetyCenter.
  ///
  /// In vi, this message translates to:
  /// **'An toàn cộng đồng'**
  String get safetyCenter;

  /// No description provided for @safetyText.
  ///
  /// In vi, this message translates to:
  /// **'Không chia sẻ thông tin cá nhân với người lạ. Báo cáo ngay nếu gặp hành vi quấy rối.'**
  String get safetyText;

  /// No description provided for @report.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get report;

  /// No description provided for @block.
  ///
  /// In vi, this message translates to:
  /// **'Chặn'**
  String get block;

  /// No description provided for @blockConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Chặn người này? Hai bạn sẽ không thể ghép đôi hay nhắn tin với nhau.'**
  String get blockConfirm;

  /// No description provided for @reportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo người dùng'**
  String get reportTitle;

  /// No description provided for @reportReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get reportReason;

  /// No description provided for @reasonSpam.
  ///
  /// In vi, this message translates to:
  /// **'Spam / quảng cáo'**
  String get reasonSpam;

  /// No description provided for @reasonHarassment.
  ///
  /// In vi, this message translates to:
  /// **'Quấy rối, xúc phạm'**
  String get reasonHarassment;

  /// No description provided for @reasonInappropriate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung không phù hợp'**
  String get reasonInappropriate;

  /// No description provided for @reasonUnderage.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 18 tuổi'**
  String get reasonUnderage;

  /// No description provided for @reasonScam.
  ///
  /// In vi, this message translates to:
  /// **'Lừa đảo'**
  String get reasonScam;

  /// No description provided for @reasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get reasonOther;

  /// No description provided for @reportDetails.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả thêm (không bắt buộc)'**
  String get reportDetails;

  /// No description provided for @reportSent.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn bạn! Chúng tôi sẽ xem xét báo cáo.'**
  String get reportSent;

  /// No description provided for @submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get submit;

  /// No description provided for @confirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get loading;

  /// No description provided for @connecting.
  ///
  /// In vi, this message translates to:
  /// **'Đang kết nối…'**
  String get connecting;

  /// No description provided for @somethingWrong.
  ///
  /// In vi, this message translates to:
  /// **'Đã có lỗi xảy ra'**
  String get somethingWrong;

  /// No description provided for @errNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được máy chủ. Kiểm tra mạng hoặc địa chỉ máy chủ.'**
  String get errNetwork;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc mật khẩu không đúng'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailTaken.
  ///
  /// In vi, this message translates to:
  /// **'Email này đã được đăng ký'**
  String get errEmailTaken;

  /// No description provided for @errInvalidCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã không đúng hoặc đã hết hạn'**
  String get errInvalidCode;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In vi, this message translates to:
  /// **'Nhập sai quá nhiều lần. Hãy yêu cầu mã mới.'**
  String get errTooManyAttempts;

  /// No description provided for @errCooldown.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng đợi {seconds}s trước khi gửi lại mã'**
  String errCooldown(int seconds);

  /// No description provided for @errSession.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'**
  String get errSession;

  /// No description provided for @errRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn thao tác quá nhanh, thử lại sau nhé'**
  String get errRateLimited;

  /// No description provided for @errSessionClosed.
  ///
  /// In vi, this message translates to:
  /// **'Phiên ghép đôi đã kết thúc'**
  String get errSessionClosed;

  /// No description provided for @errBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không thể tương tác với người này'**
  String get errBlocked;

  /// No description provided for @interest_music.
  ///
  /// In vi, this message translates to:
  /// **'Âm nhạc'**
  String get interest_music;

  /// No description provided for @interest_movies.
  ///
  /// In vi, this message translates to:
  /// **'Phim ảnh'**
  String get interest_movies;

  /// No description provided for @interest_gaming.
  ///
  /// In vi, this message translates to:
  /// **'Game'**
  String get interest_gaming;

  /// No description provided for @interest_travel.
  ///
  /// In vi, this message translates to:
  /// **'Du lịch'**
  String get interest_travel;

  /// No description provided for @interest_food.
  ///
  /// In vi, this message translates to:
  /// **'Ăn uống'**
  String get interest_food;

  /// No description provided for @interest_sports.
  ///
  /// In vi, this message translates to:
  /// **'Thể thao'**
  String get interest_sports;

  /// No description provided for @interest_reading.
  ///
  /// In vi, this message translates to:
  /// **'Đọc sách'**
  String get interest_reading;

  /// No description provided for @interest_anime.
  ///
  /// In vi, this message translates to:
  /// **'Anime'**
  String get interest_anime;

  /// No description provided for @interest_photography.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh'**
  String get interest_photography;

  /// No description provided for @interest_art.
  ///
  /// In vi, this message translates to:
  /// **'Nghệ thuật'**
  String get interest_art;

  /// No description provided for @interest_tech.
  ///
  /// In vi, this message translates to:
  /// **'Công nghệ'**
  String get interest_tech;

  /// No description provided for @interest_pets.
  ///
  /// In vi, this message translates to:
  /// **'Thú cưng'**
  String get interest_pets;

  /// No description provided for @interest_fitness.
  ///
  /// In vi, this message translates to:
  /// **'Gym'**
  String get interest_fitness;

  /// No description provided for @interest_coffee.
  ///
  /// In vi, this message translates to:
  /// **'Cà phê'**
  String get interest_coffee;

  /// No description provided for @interest_fashion.
  ///
  /// In vi, this message translates to:
  /// **'Thời trang'**
  String get interest_fashion;

  /// No description provided for @interest_kpop.
  ///
  /// In vi, this message translates to:
  /// **'K-pop'**
  String get interest_kpop;

  /// No description provided for @interest_astrology.
  ///
  /// In vi, this message translates to:
  /// **'Chiêm tinh'**
  String get interest_astrology;

  /// No description provided for @interest_dance.
  ///
  /// In vi, this message translates to:
  /// **'Nhảy'**
  String get interest_dance;

  /// No description provided for @interest_nature.
  ///
  /// In vi, this message translates to:
  /// **'Thiên nhiên'**
  String get interest_nature;

  /// No description provided for @interest_study.
  ///
  /// In vi, this message translates to:
  /// **'Học tập'**
  String get interest_study;

  /// No description provided for @filters.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc'**
  String get filters;

  /// No description provided for @ageRange.
  ///
  /// In vi, this message translates to:
  /// **'Độ tuổi'**
  String get ageRange;

  /// No description provided for @ageRangeValue.
  ///
  /// In vi, this message translates to:
  /// **'{min} – {max} tuổi'**
  String ageRangeValue(int min, int max);

  /// No description provided for @ageRangeHint.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ ghép với người trong độ tuổi này và cũng chấp nhận tuổi của bạn.'**
  String get ageRangeHint;

  /// No description provided for @genderFilter.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get genderFilter;

  /// No description provided for @preferNearby.
  ///
  /// In vi, this message translates to:
  /// **'Ưu tiên người gần đây'**
  String get preferNearby;

  /// No description provided for @preferNearbyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Ghép với người trong bán kính ~30 km khi có thể'**
  String get preferNearbyDesc;

  /// No description provided for @nearbyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người gần đây'**
  String get nearbyTitle;

  /// No description provided for @nearbyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Xem ai đang ở quanh bạn'**
  String get nearbyDesc;

  /// No description provided for @distanceApprox.
  ///
  /// In vi, this message translates to:
  /// **'~{km} km'**
  String distanceApprox(int km);

  /// No description provided for @radius.
  ///
  /// In vi, this message translates to:
  /// **'Bán kính'**
  String get radius;

  /// No description provided for @radiusKm.
  ///
  /// In vi, this message translates to:
  /// **'{km} km'**
  String radiusKm(int km);

  /// No description provided for @locationEnable.
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí'**
  String get locationEnable;

  /// No description provided for @locationWhy.
  ///
  /// In vi, this message translates to:
  /// **'Lumi chỉ lưu vị trí gần đúng (~1 km). Người khác chỉ thấy khoảng cách ước lượng, không bao giờ thấy toạ độ của bạn.'**
  String get locationWhy;

  /// No description provided for @locationDenied.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã từ chối quyền vị trí.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In vi, this message translates to:
  /// **'Quyền vị trí bị tắt. Hãy bật trong Cài đặt.'**
  String get locationDeniedForever;

  /// No description provided for @locationServiceOff.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ định vị đang tắt.'**
  String get locationServiceOff;

  /// No description provided for @openSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở Cài đặt'**
  String get openSettings;

  /// No description provided for @hideLocation.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn vị trí của tôi'**
  String get hideLocation;

  /// No description provided for @hideLocationDesc.
  ///
  /// In vi, this message translates to:
  /// **'Không xuất hiện trong Người gần đây và ghép theo khoảng cách'**
  String get hideLocationDesc;

  /// No description provided for @locationHiddenInfo.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí của bạn đang ẩn. Bật lại để xem người gần đây.'**
  String get locationHiddenInfo;

  /// No description provided for @removeLocation.
  ///
  /// In vi, this message translates to:
  /// **'Xoá vị trí đã lưu'**
  String get removeLocation;

  /// No description provided for @updateLocation.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật vị trí'**
  String get updateLocation;

  /// No description provided for @nearbyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ai trong bán kính này. Thử mở rộng bán kính nhé!'**
  String get nearbyEmpty;

  /// No description provided for @attachPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get attachPhoto;

  /// No description provided for @attachCamera.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get attachCamera;

  /// No description provided for @attachFile.
  ///
  /// In vi, this message translates to:
  /// **'Tệp'**
  String get attachFile;

  /// No description provided for @holdToRecord.
  ///
  /// In vi, this message translates to:
  /// **'Giữ để ghi âm'**
  String get holdToRecord;

  /// No description provided for @releaseToSend.
  ///
  /// In vi, this message translates to:
  /// **'Thả để gửi · vuốt sang trái để huỷ'**
  String get releaseToSend;

  /// No description provided for @recordTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn thoại quá ngắn'**
  String get recordTooShort;

  /// No description provided for @voiceMessage.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn thoại'**
  String get voiceMessage;

  /// No description provided for @photoMessage.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get photoMessage;

  /// No description provided for @fileTooLarge.
  ///
  /// In vi, this message translates to:
  /// **'Tệp vượt quá {mb} MB'**
  String fileTooLarge(int mb);

  /// No description provided for @fileTypeNotAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Loại tệp này không được hỗ trợ'**
  String get fileTypeNotAllowed;

  /// No description provided for @uploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải lên…'**
  String get uploading;

  /// No description provided for @download.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống'**
  String get download;

  /// No description provided for @callVoice.
  ///
  /// In vi, this message translates to:
  /// **'Gọi thoại'**
  String get callVoice;

  /// No description provided for @calling.
  ///
  /// In vi, this message translates to:
  /// **'Đang gọi…'**
  String get calling;

  /// No description provided for @incomingCall.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc gọi đến'**
  String get incomingCall;

  /// No description provided for @incomingCallFrom.
  ///
  /// In vi, this message translates to:
  /// **'{name} đang gọi cho bạn'**
  String incomingCallFrom(String name);

  /// No description provided for @accept.
  ///
  /// In vi, this message translates to:
  /// **'Nghe'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get decline;

  /// No description provided for @hangUp.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get hangUp;

  /// No description provided for @callEnded.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc gọi đã kết thúc'**
  String get callEnded;

  /// No description provided for @callDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc gọi bị từ chối'**
  String get callDeclined;

  /// No description provided for @callNoAnswer.
  ///
  /// In vi, this message translates to:
  /// **'Không có người nghe máy'**
  String get callNoAnswer;

  /// No description provided for @peerBusy.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè đang trong cuộc gọi khác'**
  String get peerBusy;

  /// No description provided for @speaker.
  ///
  /// In vi, this message translates to:
  /// **'Loa ngoài'**
  String get speaker;

  /// No description provided for @errInvalidAgeRange.
  ///
  /// In vi, this message translates to:
  /// **'Độ tuổi không hợp lệ'**
  String get errInvalidAgeRange;

  /// No description provided for @sentStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get sentStatus;

  /// No description provided for @deliveredStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận'**
  String get deliveredStatus;

  /// No description provided for @logoutKeepTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lịch sử trò chuyện trên máy này?'**
  String get logoutKeepTitle;

  /// No description provided for @logoutKeepBody.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn chỉ được lưu trên điện thoại của bạn (đã mã hoá), không lưu trên máy chủ. Nếu xoá, lịch sử sẽ mất vĩnh viễn.'**
  String get logoutKeepBody;

  /// No description provided for @keepData.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lại'**
  String get keepData;

  /// No description provided for @wipeData.
  ///
  /// In vi, this message translates to:
  /// **'Xoá khỏi máy'**
  String get wipeData;

  /// No description provided for @localStorageNote.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn được lưu mã hoá trên thiết bị này. Đổi/cài lại máy sẽ mất lịch sử nếu chưa sao lưu.'**
  String get localStorageNote;

  /// No description provided for @exportBackup.
  ///
  /// In vi, this message translates to:
  /// **'Xuất bản sao lưu'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In vi, this message translates to:
  /// **'Nhập bản sao lưu'**
  String get importBackup;

  /// No description provided for @backupDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xuất bản sao lưu'**
  String get backupDone;

  /// No description provided for @restoreDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã khôi phục {count} tin nhắn'**
  String restoreDone(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
