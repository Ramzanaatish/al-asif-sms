class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String role;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: j['username']?.toString() ?? '',
        fullName: j['full_name']?.toString() ?? j['username']?.toString() ?? '',
        role: j['role']?.toString() ?? '',
      );

  bool get isPrincipal => role == 'principal';
  bool get isAdmin => role == 'administrator';
  bool get isTeacher => role == 'teacher';
  bool get isAccountant => role == 'accountant';
  bool get isParent => role == 'parent';
  bool get isStaff => isPrincipal || isAdmin || isTeacher || isAccountant;

  static const List<String> allRoles = [
    'principal',
    'administrator',
    'teacher',
    'accountant',
    'parent',
  ];
}
