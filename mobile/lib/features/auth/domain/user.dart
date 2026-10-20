/// Current user (private profile).
class Me {
  const Me({
    required this.id,
    required this.email,
    required this.onboarded,
    this.nickname,
    this.gender,
    this.birthday,
    this.age,
    this.avatarId,
    this.bio,
    this.interests = const [],
    this.locale = 'vi',
    this.agePrefMin = 18,
    this.agePrefMax = 99,
    this.hasLocation = false,
    this.locationHidden = false,
  });

  final int agePrefMin;
  final int agePrefMax;
  final bool hasLocation;
  final bool locationHidden;
  final String id;
  final String email;
  final bool onboarded;
  final String? nickname;
  final String? gender;
  final String? birthday;
  final int? age;
  final String? avatarId;
  final String? bio;
  final List<String> interests;
  final String locale;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        email: j['email'] as String,
        onboarded: j['onboarded'] == true,
        nickname: j['nickname'] as String?,
        gender: j['gender'] as String?,
        birthday: j['birthday'] as String?,
        age: (j['age'] as num?)?.toInt(),
        avatarId: j['avatarId'] as String?,
        bio: j['bio'] as String?,
        interests: (j['interests'] as List? ?? const []).cast<String>(),
        locale: (j['locale'] as String?) ?? 'vi',
        agePrefMin: (j['agePrefMin'] as num?)?.toInt() ?? 18,
        agePrefMax: (j['agePrefMax'] as num?)?.toInt() ?? 99,
        hasLocation: j['hasLocation'] == true,
        locationHidden: j['locationHidden'] == true,
      );
}

/// Another user as seen by me.
class PublicUser {
  const PublicUser({
    required this.id,
    required this.nickname,
    required this.avatarId,
    this.gender,
    this.age,
    this.bio,
    this.interests = const [],
    this.online = false,
    this.lastSeenAt,
    this.distanceKm,
  });

  /// Approximate distance (server-rounded, Nearby list only).
  final int? distanceKm;

  final String id;
  final String nickname;
  final String avatarId;
  final String? gender;
  final int? age;
  final String? bio;
  final List<String> interests;
  final bool online;
  final DateTime? lastSeenAt;

  PublicUser copyWith({bool? online}) => PublicUser(
        id: id, nickname: nickname, avatarId: avatarId, gender: gender, age: age, bio: bio,
        interests: interests, online: online ?? this.online, lastSeenAt: lastSeenAt, distanceKm: distanceKm,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'nickname': nickname, 'avatarId': avatarId, 'gender': gender, 'age': age, 'bio': bio,
        'interests': interests, 'lastSeenAt': lastSeenAt?.toIso8601String(),
      };

  factory PublicUser.fromJson(Map<String, dynamic> j) => PublicUser(
        id: j['id'] as String,
        nickname: (j['nickname'] as String?) ?? 'Lumi',
        avatarId: (j['avatarId'] as String?) ?? 'a01',
        gender: j['gender'] as String?,
        age: (j['age'] as num?)?.toInt(),
        bio: j['bio'] as String?,
        interests: (j['interests'] as List? ?? const []).cast<String>(),
        online: j['online'] == true,
        lastSeenAt: j['lastSeenAt'] != null ? DateTime.tryParse(j['lastSeenAt'] as String) : null,
        distanceKm: (j['distanceKm'] as num?)?.toInt(),
      );
}

class CodeSent {
  const CodeSent(this.email, this.devCode);
  final String email;
  final String? devCode;
  factory CodeSent.fromJson(Map<String, dynamic> j) => CodeSent(j['email'] as String, j['devCode'] as String?);
}
