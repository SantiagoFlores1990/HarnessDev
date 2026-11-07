/// Roles del sistema.
enum UserRole {
  admin('ADMIN'),
  client('CLIENT');

  const UserRole(this.apiValue);
  final String apiValue;

  static UserRole fromApi(String value) =>
      value == 'ADMIN' ? UserRole.admin : UserRole.client;

  String get label => this == UserRole.admin ? 'Administrador' : 'Cliente';
}

/// Usuario autenticado.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        role: UserRole.fromApi(json['role'] as String),
      );
}

/// Sesion activa.
class Session {
  const Session({required this.user});
  final AppUser user;
}
