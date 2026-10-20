// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTagline => 'Gặp gỡ những tâm hồn đồng điệu';

  @override
  String get welcomeTitle => 'Trò chuyện ẩn danh,\nkết nối thật lòng';

  @override
  String get welcomeSubtitle =>
      'Ghép đôi ngẫu nhiên với người lạ. Nếu cả hai cùng thích, hai bạn sẽ thành bạn bè.';

  @override
  String get getStarted => 'Bắt đầu';

  @override
  String get haveAccount => 'Tôi đã có tài khoản';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mật khẩu';

  @override
  String get confirmPassword => 'Nhập lại mật khẩu';

  @override
  String get newPassword => 'Mật khẩu mới';

  @override
  String get login => 'Đăng nhập';

  @override
  String get loginTitle => 'Chào mừng trở lại';

  @override
  String get loginSubtitle => 'Đăng nhập để tiếp tục trò chuyện';

  @override
  String get register => 'Đăng ký';

  @override
  String get registerTitle => 'Tạo tài khoản';

  @override
  String get registerSubtitle =>
      'Chỉ cần email. Chúng tôi sẽ gửi mã xác minh 6 số.';

  @override
  String get forgotPassword => 'Quên mật khẩu?';

  @override
  String get forgotTitle => 'Quên mật khẩu';

  @override
  String get forgotSubtitle =>
      'Nhập email đã đăng ký, chúng tôi sẽ gửi mã đặt lại mật khẩu.';

  @override
  String get sendCode => 'Gửi mã';

  @override
  String get resetTitle => 'Đặt lại mật khẩu';

  @override
  String resetSubtitle(String email) {
    return 'Nhập mã 6 số đã gửi tới $email và mật khẩu mới.';
  }

  @override
  String get resetAction => 'Đổi mật khẩu';

  @override
  String get verifyTitle => 'Xác minh email';

  @override
  String verifySubtitle(String email) {
    return 'Nhập mã 6 số chúng tôi vừa gửi tới\n$email';
  }

  @override
  String get verifyAction => 'Xác minh';

  @override
  String get resendCode => 'Gửi lại mã';

  @override
  String resendIn(int seconds) {
    return 'Gửi lại sau ${seconds}s';
  }

  @override
  String get codeSent => 'Đã gửi mã mới';

  @override
  String devCodeHint(String code) {
    return 'Mã thử nghiệm (dev): $code — chạm để điền';
  }

  @override
  String get noAccount => 'Chưa có tài khoản?';

  @override
  String get termsNote =>
      'Bằng việc tiếp tục, bạn xác nhận đã đủ 18 tuổi và đồng ý với Điều khoản & Chính sách cộng đồng.';

  @override
  String get validationEmail => 'Email không hợp lệ';

  @override
  String get validationPassword => 'Tối thiểu 8 ký tự, gồm cả chữ và số';

  @override
  String get validationPasswordMatch => 'Mật khẩu không khớp';

  @override
  String get validationRequired => 'Bắt buộc';

  @override
  String get passwordChanged => 'Đã đổi mật khẩu';

  @override
  String onbStep(int current, int total) {
    return 'Bước $current/$total';
  }

  @override
  String get onbNameTitle => 'Bạn tên là gì?';

  @override
  String get onbNameSubtitle =>
      'Biệt danh sẽ chỉ hiện khi hai bạn đã thành bạn bè.';

  @override
  String get nickname => 'Biệt danh';

  @override
  String get gender => 'Giới tính';

  @override
  String get genderMale => 'Nam';

  @override
  String get genderFemale => 'Nữ';

  @override
  String get genderOther => 'Khác';

  @override
  String get onbBirthdayTitle => 'Sinh nhật của bạn';

  @override
  String get onbBirthdaySubtitle =>
      'Lumi chỉ dành cho người từ 18 tuổi trở lên. Ngày sinh không hiển thị công khai, chỉ hiện tuổi.';

  @override
  String get pickBirthday => 'Chọn ngày sinh';

  @override
  String ageYears(int age) {
    return '$age tuổi';
  }

  @override
  String get underageError => 'Bạn cần đủ 18 tuổi để sử dụng Lumi';

  @override
  String get onbAvatarTitle => 'Chọn avatar';

  @override
  String get onbAvatarSubtitle =>
      'Không cần ảnh thật. Hãy chọn nhân vật đại diện cho bạn.';

  @override
  String get onbInterestsTitle => 'Sở thích & giới thiệu';

  @override
  String onbInterestsSubtitle(int max) {
    return 'Chọn tối đa $max sở thích để dễ tìm người hợp gu.';
  }

  @override
  String get bio => 'Giới thiệu ngắn';

  @override
  String get bioHint => 'Một câu về bạn…';

  @override
  String get next => 'Tiếp tục';

  @override
  String get back => 'Quay lại';

  @override
  String get finish => 'Hoàn tất';

  @override
  String get tabDiscover => 'Khám phá';

  @override
  String get tabFeed => 'Bảng tin';

  @override
  String get tabChats => 'Tin nhắn';

  @override
  String get tabMe => 'Tôi';

  @override
  String hello(String name) {
    return 'Xin chào, $name';
  }

  @override
  String onlineNow(int count) {
    return '$count người đang online';
  }

  @override
  String get soulMatch => 'Soul Match';

  @override
  String soulMatchDesc(int minutes) {
    return 'Chat ẩn danh $minutes phút với một người lạ';
  }

  @override
  String get voiceMatch => 'Voice Match';

  @override
  String voiceMatchDesc(int minutes) {
    return 'Gọi thoại ẩn danh $minutes phút';
  }

  @override
  String get matchFilter => 'Muốn gặp';

  @override
  String get filterAny => 'Mọi người';

  @override
  String get start => 'Bắt đầu';

  @override
  String get howItWorks => 'Cách hoạt động';

  @override
  String get how1 => 'Ghép ngẫu nhiên với một người lạ đang online';

  @override
  String get how2 => 'Trò chuyện ẩn danh trước khi hết giờ';

  @override
  String get how3 => 'Cả hai cùng thả tim → thành bạn bè';

  @override
  String get searching => 'Đang tìm người phù hợp…';

  @override
  String get searchingHint => 'Giữ ứng dụng mở nhé. Thường mất vài giây.';

  @override
  String get cancel => 'Hủy';

  @override
  String get stranger => 'Người lạ bí ẩn';

  @override
  String get commonInterests => 'Cùng thích';

  @override
  String get soulIntro =>
      'Hai bạn đã được ghép! Hãy chào nhau trước khi hết giờ nhé.';

  @override
  String get typeMessage => 'Nhập tin nhắn…';

  @override
  String get partnerTyping => 'Đang soạn tin…';

  @override
  String get partnerLiked => 'Đối phương đã thả tim cho bạn 💜';

  @override
  String get youLiked => 'Bạn đã thả tim. Chờ đối phương…';

  @override
  String get like => 'Thích';

  @override
  String get skip => 'Bỏ qua';

  @override
  String get skipConfirm => 'Kết thúc cuộc trò chuyện này?';

  @override
  String get endedTimeout => 'Hết giờ rồi';

  @override
  String get endedSkipped => 'Cuộc trò chuyện đã kết thúc';

  @override
  String get endedPartnerSkipped => 'Đối phương đã rời đi';

  @override
  String get endedPartnerLeft => 'Đối phương mất kết nối';

  @override
  String get endedBlocked => 'Đã chặn người này';

  @override
  String get endedHint =>
      'Đừng buồn, người tiếp theo có thể là tri kỷ của bạn!';

  @override
  String get findAnother => 'Tìm người khác';

  @override
  String get backHome => 'Về trang chủ';

  @override
  String get mutualTitle => 'Hai bạn đã thành bạn bè!';

  @override
  String mutualSubtitle(String name) {
    return 'Giờ bạn có thể nhắn tin với $name bất cứ lúc nào.';
  }

  @override
  String get sayHi => 'Nhắn tin ngay';

  @override
  String get voiceConnecting => 'Đang kết nối giọng nói…';

  @override
  String get voiceConnected => 'Đang trò chuyện';

  @override
  String get voiceUnavailable => 'Voice Match chưa được bật trên máy chủ này';

  @override
  String get mute => 'Tắt mic';

  @override
  String get unmute => 'Bật mic';

  @override
  String get speaking => 'Đang nói…';

  @override
  String get micPermission => 'Cần quyền micro để gọi thoại';

  @override
  String get chatsTitle => 'Tin nhắn';

  @override
  String get friendsTitle => 'Bạn bè';

  @override
  String get noChats => 'Chưa có cuộc trò chuyện';

  @override
  String get noChatsHint => 'Thử Soul Match để kết bạn mới nhé!';

  @override
  String get noFriends => 'Chưa có bạn bè';

  @override
  String get goMatch => 'Đi ghép đôi';

  @override
  String get online => 'Đang online';

  @override
  String get offline => 'Offline';

  @override
  String get seen => 'Đã xem';

  @override
  String get sent => 'Đã gửi';

  @override
  String get sending => 'Đang gửi…';

  @override
  String get failedTapRetry => 'Gửi lỗi · chạm để thử lại';

  @override
  String get systemMatched => 'Hai bạn đã kết nối qua Soul Match ✨';

  @override
  String get chatBlocked => 'Bạn không thể nhắn tin với người này';

  @override
  String get you => 'Bạn';

  @override
  String get unfriend => 'Hủy kết bạn';

  @override
  String get unfriendConfirm => 'Hủy kết bạn và xóa lịch sử trò chuyện?';

  @override
  String get viewProfile => 'Xem hồ sơ';

  @override
  String get feedTitle => 'Bảng tin';

  @override
  String get feedEmpty => 'Chưa có bài viết nào';

  @override
  String get feedEmptyHint => 'Hãy là người đầu tiên chia sẻ khoảnh khắc!';

  @override
  String get newPost => 'Chia sẻ khoảnh khắc';

  @override
  String get postHint => 'Bạn đang nghĩ gì?';

  @override
  String get post => 'Đăng';

  @override
  String get deletePost => 'Xóa bài viết';

  @override
  String get posted => 'Đã đăng';

  @override
  String get me => 'Tôi';

  @override
  String get editProfile => 'Chỉnh sửa hồ sơ';

  @override
  String get settings => 'Cài đặt';

  @override
  String get save => 'Lưu';

  @override
  String get saved => 'Đã lưu';

  @override
  String get interests => 'Sở thích';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get blockedUsers => 'Người đã chặn';

  @override
  String get noBlocked => 'Bạn chưa chặn ai';

  @override
  String get unblock => 'Bỏ chặn';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get logoutConfirm => 'Bạn muốn đăng xuất?';

  @override
  String get deleteAccount => 'Xóa tài khoản';

  @override
  String get deleteAccountConfirm =>
      'Toàn bộ dữ liệu, bạn bè và tin nhắn sẽ bị xóa vĩnh viễn. Tiếp tục?';

  @override
  String get about => 'Giới thiệu';

  @override
  String get server => 'Máy chủ';

  @override
  String get version => 'Phiên bản';

  @override
  String get safetyCenter => 'An toàn cộng đồng';

  @override
  String get safetyText =>
      'Không chia sẻ thông tin cá nhân với người lạ. Báo cáo ngay nếu gặp hành vi quấy rối.';

  @override
  String get report => 'Báo cáo';

  @override
  String get block => 'Chặn';

  @override
  String get blockConfirm =>
      'Chặn người này? Hai bạn sẽ không thể ghép đôi hay nhắn tin với nhau.';

  @override
  String get reportTitle => 'Báo cáo người dùng';

  @override
  String get reportReason => 'Lý do';

  @override
  String get reasonSpam => 'Spam / quảng cáo';

  @override
  String get reasonHarassment => 'Quấy rối, xúc phạm';

  @override
  String get reasonInappropriate => 'Nội dung không phù hợp';

  @override
  String get reasonUnderage => 'Dưới 18 tuổi';

  @override
  String get reasonScam => 'Lừa đảo';

  @override
  String get reasonOther => 'Khác';

  @override
  String get reportDetails => 'Mô tả thêm (không bắt buộc)';

  @override
  String get reportSent => 'Cảm ơn bạn! Chúng tôi sẽ xem xét báo cáo.';

  @override
  String get submit => 'Gửi';

  @override
  String get confirm => 'Xác nhận';

  @override
  String get close => 'Đóng';

  @override
  String get retry => 'Thử lại';

  @override
  String get loading => 'Đang tải…';

  @override
  String get connecting => 'Đang kết nối…';

  @override
  String get somethingWrong => 'Đã có lỗi xảy ra';

  @override
  String get errNetwork =>
      'Không kết nối được máy chủ. Kiểm tra mạng hoặc địa chỉ máy chủ.';

  @override
  String get errInvalidCredentials => 'Email hoặc mật khẩu không đúng';

  @override
  String get errEmailTaken => 'Email này đã được đăng ký';

  @override
  String get errInvalidCode => 'Mã không đúng hoặc đã hết hạn';

  @override
  String get errTooManyAttempts =>
      'Nhập sai quá nhiều lần. Hãy yêu cầu mã mới.';

  @override
  String errCooldown(int seconds) {
    return 'Vui lòng đợi ${seconds}s trước khi gửi lại mã';
  }

  @override
  String get errSession =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get errRateLimited => 'Bạn thao tác quá nhanh, thử lại sau nhé';

  @override
  String get errSessionClosed => 'Phiên ghép đôi đã kết thúc';

  @override
  String get errBlocked => 'Bạn không thể tương tác với người này';

  @override
  String get interest_music => 'Âm nhạc';

  @override
  String get interest_movies => 'Phim ảnh';

  @override
  String get interest_gaming => 'Game';

  @override
  String get interest_travel => 'Du lịch';

  @override
  String get interest_food => 'Ăn uống';

  @override
  String get interest_sports => 'Thể thao';

  @override
  String get interest_reading => 'Đọc sách';

  @override
  String get interest_anime => 'Anime';

  @override
  String get interest_photography => 'Nhiếp ảnh';

  @override
  String get interest_art => 'Nghệ thuật';

  @override
  String get interest_tech => 'Công nghệ';

  @override
  String get interest_pets => 'Thú cưng';

  @override
  String get interest_fitness => 'Gym';

  @override
  String get interest_coffee => 'Cà phê';

  @override
  String get interest_fashion => 'Thời trang';

  @override
  String get interest_kpop => 'K-pop';

  @override
  String get interest_astrology => 'Chiêm tinh';

  @override
  String get interest_dance => 'Nhảy';

  @override
  String get interest_nature => 'Thiên nhiên';

  @override
  String get interest_study => 'Học tập';

  @override
  String get filters => 'Bộ lọc';

  @override
  String get ageRange => 'Độ tuổi';

  @override
  String ageRangeValue(int min, int max) {
    return '$min – $max tuổi';
  }

  @override
  String get ageRangeHint =>
      'Chỉ ghép với người trong độ tuổi này và cũng chấp nhận tuổi của bạn.';

  @override
  String get genderFilter => 'Giới tính';

  @override
  String get preferNearby => 'Ưu tiên người gần đây';

  @override
  String get preferNearbyDesc =>
      'Ghép với người trong bán kính ~30 km khi có thể';

  @override
  String get nearbyTitle => 'Người gần đây';

  @override
  String get nearbyDesc => 'Xem ai đang ở quanh bạn';

  @override
  String distanceApprox(int km) {
    return '~$km km';
  }

  @override
  String get radius => 'Bán kính';

  @override
  String radiusKm(int km) {
    return '$km km';
  }

  @override
  String get locationEnable => 'Bật vị trí';

  @override
  String get locationWhy =>
      'Lumi chỉ lưu vị trí gần đúng (~1 km). Người khác chỉ thấy khoảng cách ước lượng, không bao giờ thấy toạ độ của bạn.';

  @override
  String get locationDenied => 'Bạn đã từ chối quyền vị trí.';

  @override
  String get locationDeniedForever =>
      'Quyền vị trí bị tắt. Hãy bật trong Cài đặt.';

  @override
  String get locationServiceOff => 'Dịch vụ định vị đang tắt.';

  @override
  String get openSettings => 'Mở Cài đặt';

  @override
  String get hideLocation => 'Ẩn vị trí của tôi';

  @override
  String get hideLocationDesc =>
      'Không xuất hiện trong Người gần đây và ghép theo khoảng cách';

  @override
  String get locationHiddenInfo =>
      'Vị trí của bạn đang ẩn. Bật lại để xem người gần đây.';

  @override
  String get removeLocation => 'Xoá vị trí đã lưu';

  @override
  String get updateLocation => 'Cập nhật vị trí';

  @override
  String get nearbyEmpty =>
      'Chưa có ai trong bán kính này. Thử mở rộng bán kính nhé!';

  @override
  String get attachPhoto => 'Ảnh';

  @override
  String get attachCamera => 'Chụp ảnh';

  @override
  String get attachFile => 'Tệp';

  @override
  String get holdToRecord => 'Giữ để ghi âm';

  @override
  String get releaseToSend => 'Thả để gửi · vuốt sang trái để huỷ';

  @override
  String get recordTooShort => 'Tin nhắn thoại quá ngắn';

  @override
  String get voiceMessage => 'Tin nhắn thoại';

  @override
  String get photoMessage => 'Ảnh';

  @override
  String fileTooLarge(int mb) {
    return 'Tệp vượt quá $mb MB';
  }

  @override
  String get fileTypeNotAllowed => 'Loại tệp này không được hỗ trợ';

  @override
  String get uploading => 'Đang tải lên…';

  @override
  String get download => 'Tải xuống';

  @override
  String get callVoice => 'Gọi thoại';

  @override
  String get calling => 'Đang gọi…';

  @override
  String get incomingCall => 'Cuộc gọi đến';

  @override
  String incomingCallFrom(String name) {
    return '$name đang gọi cho bạn';
  }

  @override
  String get accept => 'Nghe';

  @override
  String get decline => 'Từ chối';

  @override
  String get hangUp => 'Kết thúc';

  @override
  String get callEnded => 'Cuộc gọi đã kết thúc';

  @override
  String get callDeclined => 'Cuộc gọi bị từ chối';

  @override
  String get callNoAnswer => 'Không có người nghe máy';

  @override
  String get peerBusy => 'Bạn bè đang trong cuộc gọi khác';

  @override
  String get speaker => 'Loa ngoài';

  @override
  String get errInvalidAgeRange => 'Độ tuổi không hợp lệ';

  @override
  String get sentStatus => 'Đã gửi';

  @override
  String get deliveredStatus => 'Đã nhận';

  @override
  String get logoutKeepTitle => 'Giữ lịch sử trò chuyện trên máy này?';

  @override
  String get logoutKeepBody =>
      'Tin nhắn chỉ được lưu trên điện thoại của bạn (đã mã hoá), không lưu trên máy chủ. Nếu xoá, lịch sử sẽ mất vĩnh viễn.';

  @override
  String get keepData => 'Giữ lại';

  @override
  String get wipeData => 'Xoá khỏi máy';

  @override
  String get localStorageNote =>
      'Tin nhắn được lưu mã hoá trên thiết bị này. Đổi/cài lại máy sẽ mất lịch sử nếu chưa sao lưu.';

  @override
  String get exportBackup => 'Xuất bản sao lưu';

  @override
  String get importBackup => 'Nhập bản sao lưu';

  @override
  String get backupDone => 'Đã xuất bản sao lưu';

  @override
  String restoreDone(int count) {
    return 'Đã khôi phục $count tin nhắn';
  }

  @override
  String get serverAddress => 'Địa chỉ máy chủ';

  @override
  String get serverInvalid => 'URL không hợp lệ (vd. http://192.168.1.10:3000)';

  @override
  String get serverReachable => 'Kết nối được ✓';

  @override
  String get serverUnreachable => 'Không kết nối được máy chủ';

  @override
  String get serverDefault => 'Mặc định';

  @override
  String get serverReset => 'Mặc định';

  @override
  String get serverTest => 'Kiểm tra';

  @override
  String get startupError => 'Không khởi động được ứng dụng';

  @override
  String get offlineHint =>
      'Không kết nối được máy chủ. Kiểm tra mạng hoặc đổi địa chỉ máy chủ.';
}
