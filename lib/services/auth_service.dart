import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'supabase_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ==================== AUTHENTICATION METHODS ====================

  /// Sign in user with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.success && response.token != null && response.user != null) {
        await _saveAuthData(response.token!, response.user!);
      }
      
      return response;
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Sign in failed: ${e.toString()}',
      );
    }
  }

  /// Sign up new user
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'customer',
  }) async {
    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      
      if (response.success && response.token != null && response.user != null) {
        await _saveAuthData(response.token!, response.user!);
      }
      
      return response;
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Sign up failed: ${e.toString()}',
      );
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      await _clearAuthData();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Get current authenticated user
  static Future<User?> getCurrentUser() async {
    try {
      // Try to get from Supabase first
      final user = await SupabaseService.getCurrentUser();
      if (user != null) {
        return user;
      }
      
      // Fallback to stored user
      return await _getStoredUser();
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final token = await _getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Refresh user data from Supabase
  static Future<User?> refreshUserData() async {
    try {
      final user = await SupabaseService.getCurrentUser();
      if (user != null) {
        await _saveAuthData('supabase_token', user);
        return user;
      }
      return null;
    } catch (e) {
      print('Refresh user data error: $e');
      return null;
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /// Save authentication data to local storage
  static Future<void> _saveAuthData(String token, User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, user.toJson().toString());
    } catch (e) {
      print('Save auth data error: $e');
    }
  }

  /// Clear authentication data from local storage
  static Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      print('Clear auth data error: $e');
    }
  }

  /// Get stored authentication token
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Get stored user data
  static Future<User?> _getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        // Parse the stored user data
        // Note: This is a simplified approach. In production, you might want to use proper JSON serialization
        return null; // For now, always get fresh data from Supabase
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}