import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';
import '../models/user.dart';

class SupabaseService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  // ==================== CONNECTION & INITIALIZATION ====================

  /// Initialize Supabase connection
  static Future<void> initialize() async {
    await SupabaseConfig.initialize();
  }

  /// Check if Supabase is connected
  static bool get isConnected => true;

  /// Get current Supabase client
  static supabase.SupabaseClient get client => _client;

  // ==================== AUTHENTICATION ====================

  /// Sign up a new user
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'customer',
  }) async {
    try {
      // Create auth user using Supabase Auth
      final supabase.AuthResponse authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Create user profile in users table (matching actual schema)
        final userData = {
          'id': authResponse.user!.id,
          'email': email,
          'role': role,
          // Note: Password is handled by Supabase Auth, not stored in users table
        };

        await _client.from('users').insert(userData);

        // Create pet coin wallet for the user
        await _client.from('pet_coin_wallets').insert({
          'user_id': authResponse.user!.id,
          'balance': 0.0,
        });

        // Build response user data
        final userResponseData = {
          'id': authResponse.user!.id,
          'email': email,
          'name': name, // Keep name for app usage
          'role': role,
          'pet_coin_balance': 0.0,
          'is_active': true,
        };

        return AuthResponse(
          success: true,
          token: authResponse.session?.accessToken,
          user: User.fromJson(userResponseData),
        );
      } else {
        return AuthResponse(
          success: false,
          error: 'Failed to create user account',
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Sign in a user
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final supabase.AuthResponse authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        try {
          // Get user profile from users table
          final response = await _client
              .from('users')
              .select('*')
              .eq('id', authResponse.user!.id)
              .single();

          // Get pet coin wallet balance
          final walletResponse = await _client
              .from('pet_coin_wallets')
              .select('balance')
              .eq('user_id', authResponse.user!.id)
              .single();

          // Build user data with wallet balance
          final userData = Map<String, dynamic>.from(response);
          userData['name'] = userData['email']?.split('@')[0] ?? 'User'; // Extract name from email
          userData['pet_coin_balance'] = walletResponse['balance'] ?? 0.0;
          userData['is_active'] = true;

          return AuthResponse(
            success: true,
            token: authResponse.session?.accessToken,
            user: User.fromJson(userData),
          );
        } catch (e) {
          // If user doesn't exist in users table, create them
          if (e.toString().contains('No rows found')) {
            // Create user profile in users table
            final userData = {
              'id': authResponse.user!.id,
              'email': authResponse.user!.email ?? '',
              'role': 'customer', // Default role
            };

            await _client.from('users').insert(userData);

            // Create pet coin wallet for the user
            await _client.from('pet_coin_wallets').insert({
              'user_id': authResponse.user!.id,
              'balance': 0.0,
            });

            // Build response user data
            final userResponseData = {
              'id': authResponse.user!.id,
              'email': authResponse.user!.email ?? '',
              'name': (authResponse.user!.email ?? '').split('@')[0],
              'role': 'customer',
              'pet_coin_balance': 0.0,
              'is_active': true,
            };

            return AuthResponse(
              success: true,
              token: authResponse.session?.accessToken,
              user: User.fromJson(userResponseData),
            );
          } else {
            rethrow;
          }
        }
      } else {
        return AuthResponse(
          success: false,
          error: 'Invalid credentials',
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Login failed: ${e.toString()}',
      );
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current authenticated user
  static Future<User?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      try {
        final response = await _client
            .from('users')
            .select('*')
            .eq('id', user.id)
            .single();

        // Get pet coin wallet balance
        final walletResponse = await _client
            .from('pet_coin_wallets')
            .select('balance')
            .eq('user_id', user.id)
            .single();

        // Build user data with wallet balance
        final userData = Map<String, dynamic>.from(response);
        userData['name'] = userData['email']?.split('@')[0] ?? 'User';
        userData['pet_coin_balance'] = walletResponse['balance'] ?? 0.0;
        userData['is_active'] = true;

        return User.fromJson(userData);
      } catch (e) {
        // If user doesn't exist in users table, create them
        if (e.toString().contains('No rows found')) {
          // Create user profile in users table
          final userData = {
            'id': user.id,
            'email': user.email ?? '',
            'role': 'customer', // Default role
          };

          await _client.from('users').insert(userData);

          // Create pet coin wallet for the user
          await _client.from('pet_coin_wallets').insert({
            'user_id': user.id,
            'balance': 0.0,
          });

          // Build response user data
          final userResponseData = {
            'id': user.id,
            'email': user.email ?? '',
            'name': (user.email ?? '').split('@')[0],
            'role': 'customer',
            'pet_coin_balance': 0.0,
            'is_active': true,
          };

          return User.fromJson(userResponseData);
        } else {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if user is signed in
  static bool get isSignedIn => _client.auth.currentUser != null;

  // ==================== BASIC DATA OPERATIONS ====================

  /// Get user transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('transactions')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get current Pet Coin price
  static Future<double> getCurrentPrice() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('coin_value_rupees')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      return (response['coin_value_rupees'] ?? 1.0).toDouble();
    } catch (e) {
      return 1.0; // Default to 1 rupee per PET coin
    }
  }

  /// Get user wallet balance
  static Future<double> getUserWalletBalance() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0.0;

      final response = await _client
          .from('pet_coin_wallets')
          .select('balance')
          .eq('user_id', user.id)
          .single();

      return (response['balance'] ?? 0.0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// Get pending transactions (Admin only)
  static Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Check if user is admin
      final userResponse = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      if (userResponse['role'] != 'admin') {
        return [];
      }

      final response = await _client
          .from('transactions')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get all users (Admin only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Check if user is admin
      final userResponse = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      if (userResponse['role'] != 'admin') {
        return [];
      }

      final response = await _client
          .from('users')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}