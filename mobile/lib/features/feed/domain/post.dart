import '../../auth/domain/user.dart';

class Post {
  const Post({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.likeCount,
    required this.likedByMe,
    required this.mine,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final PublicUser author;
  final int likeCount;
  final bool likedByMe;
  final bool mine;

  Post copyWith({int? likeCount, bool? likedByMe}) => Post(
        id: id, body: body, createdAt: createdAt, author: author,
        likeCount: likeCount ?? this.likeCount, likedByMe: likedByMe ?? this.likedByMe, mine: mine,
      );

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        author: PublicUser.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
        likeCount: (j['likeCount'] as num).toInt(),
        likedByMe: j['likedByMe'] == true,
        mine: j['mine'] == true,
      );
}
