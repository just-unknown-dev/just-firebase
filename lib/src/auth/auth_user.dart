import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Immutable snapshot of the currently authenticated user.
///
/// Wraps Firebase's [fb.User] and exposes only what game/app logic needs.
/// Construct via [JustFirebaseUser.fromFirebase].
class JustFirebaseUser {
  const JustFirebaseUser._({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
  });

  /// Firebase UID — stable across sign-in methods for the same account.
  final String uid;

  /// Whether the user signed in anonymously.
  final bool isAnonymous;

  /// Email address, or `null` for anonymous users.
  final String? email;

  /// Display name, or `null` if not set.
  final String? displayName;

  /// Profile photo URL, or `null` if not set.
  final String? photoUrl;

  /// Whether the email address has been verified.
  final bool isEmailVerified;

  factory JustFirebaseUser.fromFirebase(fb.User user) {
    return JustFirebaseUser._(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
    );
  }

  JustFirebaseUser copyWith({
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
  }) {
    return JustFirebaseUser._(
      uid: uid,
      isAnonymous: isAnonymous,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'isAnonymous': isAnonymous,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'isEmailVerified': isEmailVerified,
  };

  factory JustFirebaseUser.fromJson(Map<String, dynamic> json) {
    return JustFirebaseUser._(
      uid: json['uid'] as String,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JustFirebaseUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'JustFirebaseUser(uid: $uid, email: $email)';
}
