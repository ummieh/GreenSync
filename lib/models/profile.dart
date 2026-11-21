import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarPath,
  });

  final String id;
  final UserRole role;
  final String? fullName;
  final String? phone;
  final String? avatarPath;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: enumByName(UserRole.values, map['role'], UserRole.user),
        fullName: map['full_name'] as String?,
        phone: map['phone'] as String?,
        avatarPath: map['avatar_path'] as String?,
      );

  bool get hasName => (fullName ?? '').trim().isNotEmpty;

  String get displayName => hasName ? fullName!.trim() : 'GreenSync member';

  String get firstName => hasName ? fullName!.trim().split(' ').first : 'there';
}
