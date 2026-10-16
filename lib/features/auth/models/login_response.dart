import 'user_model.dart';
import 'auth_tokens.dart';

class LoginResponse {
  final AuthTokens tokens;
  final UserModel user;

  LoginResponse({
    required this.tokens,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    return LoginResponse(
      tokens: AuthTokens.fromJson(payload),
      user: UserModel.fromJson(payload['user'] as Map<String, dynamic>),
    );
  }
}
