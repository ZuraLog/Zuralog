/// Zuralog Edge Agent — UserProfile Domain Model.
///
/// Represents the authenticated user's profile data as returned by the
/// Cloud Brain `GET /api/v1/me/profile` endpoint. Immutable value object
/// with helpers for AI greeting name resolution.
library;

/// Sentinel value used by [UserProfile.copyWith] to distinguish between
/// "caller passed null explicitly" and "caller omitted the argument".
///
/// This enables nullable fields to be cleared to `null` via [copyWith].
const Object _copyWithSentinel = Object();

/// Immutable domain model for a Zuralog user profile.
///
/// Fields mirror the Cloud Brain profile schema. Use [fromJson] to
/// deserialize a backend response and [copyWith] to produce updated
/// instances without mutation.
class UserProfile {
  /// Supabase user UUID.
  final String id;

  /// User's email address.
  final String email;

  /// Optional display name set by the user.
  final String? displayName;

  /// Optional short nickname preferred for AI greetings.
  final String? nickname;

  /// Optional date of birth.
  final DateTime? birthday;

  /// Optional gender identifier.
  final String? gender;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingComplete;

  /// Timestamp when the account was created (set by the server).
  ///
  /// `null` when the backend has not yet returned this field (e.g. legacy
  /// sessions where the profile was fetched before the schema update).
  final DateTime? createdAt;

  /// Creates an immutable [UserProfile].
  ///
  /// [id] and [email] are required; all other fields are optional.
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.nickname,
    this.birthday,
    this.gender,
    required this.onboardingComplete,
    this.createdAt,
  });

  /// The name shown in AI greetings.
  ///
  /// Resolution order: [nickname] → [displayName] → email prefix.
  String get aiName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    return email.split('@').first;
  }

  /// Deserializes a [UserProfile] from a Cloud Brain JSON response map.
  ///
  /// [json] must contain `id` (String) and `email` (String).
  /// All other keys are optional and will be `null` if absent.
  ///
  /// Returns a fully populated [UserProfile] instance.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      nickname: json['nickname'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      gender: json['gender'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Returns a new [UserProfile] with the specified fields replaced.
  ///
  /// Fields not passed to [copyWith] retain their current values.
  /// [id] and [email] are immutable and cannot be changed via [copyWith].
  ///
  /// Nullable fields ([displayName], [nickname], [birthday]) use a sentinel
  /// default so callers can explicitly clear them to `null`:
  /// ```dart
  /// profile.copyWith(nickname: null); // clears nickname
  /// profile.copyWith();               // nickname unchanged
  /// ```
  UserProfile copyWith({
    Object? displayName = _copyWithSentinel,
    Object? nickname = _copyWithSentinel,
    Object? birthday = _copyWithSentinel,
    String? gender,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName == _copyWithSentinel
          ? this.displayName
          : displayName as String?,
      nickname: nickname == _copyWithSentinel
          ? this.nickname
          : nickname as String?,
      birthday: birthday == _copyWithSentinel
          ? this.birthday
          : birthday as DateTime?,
      gender: gender ?? this.gender,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          nickname == other.nickname &&
          birthday == other.birthday &&
          gender == other.gender &&
          onboardingComplete == other.onboardingComplete &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        nickname,
        birthday,
        gender,
        onboardingComplete,
        createdAt,
      );
}
