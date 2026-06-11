enum UserRole {
  user,
  maintainer,
  admin,
  superAdmin;

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'USER':
        return UserRole.user;
      case 'MAINTAINER':
        return UserRole.maintainer;
      case 'ADMIN':
        return UserRole.admin;
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      default:
        return UserRole.user;
    }
  }

  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;

  bool get isMaintainer => this == UserRole.maintainer;

  bool get canAccessAdmin => isAdmin || isMaintainer;
}