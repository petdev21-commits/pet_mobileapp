class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final double petCoinBalance;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.petCoinBalance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'customer',
      petCoinBalance: (json['pet_coin_balance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'pet_coin_balance': petCoinBalance,
    };
  }
}

class AuthResponse {
  final bool success;
  final String? token;
  final User? user;
  final String? error;

  AuthResponse({
    required this.success,
    this.token,
    this.user,
    this.error,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      token: json['token'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      error: json['error'],
    );
  }
}
