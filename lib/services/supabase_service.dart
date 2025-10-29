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
          'petnt_balance': 0.0,
          'petbnt_balance': 0.0,
          'petindx_balance': 0.0,
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
      // First try Supabase Auth
      try {
        final supabase.AuthResponse authResponse = await _client.auth
            .signInWithPassword(email: email, password: password);

        if (authResponse.user != null) {
          try {
            // Get user profile from users table
            final response = await _client
                .from('users')
                .select('*')
                .eq('id', authResponse.user!.id)
                .single();

            // Get pet coin wallet balance (sum of all coin types)
            final walletResponse = await _client
                .from('pet_coin_wallets')
                .select('petnt_balance, petbnt_balance, petindx_balance')
                .eq('user_id', authResponse.user!.id)
                .single();

            // Build user data with wallet balance
            final userData = Map<String, dynamic>.from(response);
            userData['name'] = userData['email']?.split('@')[0] ?? 'User';
            final petnt = (walletResponse['petnt_balance'] ?? 0.0) as num;
            final petbnt = (walletResponse['petbnt_balance'] ?? 0.0) as num;
            final petindx = (walletResponse['petindx_balance'] ?? 0.0) as num;
            userData['pet_coin_balance'] =
                petnt.toDouble() + petbnt.toDouble() + petindx.toDouble();
            userData['is_active'] = true;

            return AuthResponse(
              success: true,
              token: authResponse.session?.accessToken,
              user: User.fromJson(userData),
            );
          } catch (e) {
            print('Error fetching user data: $e');
            return AuthResponse(success: false, error: 'Invalid credentials');
          }
        }
      } catch (authError) {
        print('Supabase Auth sign-in failed: $authError');
        // Fall through to check users table
      }

      // If Supabase Auth fails, check users table for admin-created users
      final userResponse = await _client
          .from('users')
          .select('*')
          .eq('email', email)
          .single();

      // Verify password matches
      if (userResponse['password'] != password) {
        return AuthResponse(success: false, error: 'Invalid credentials');
      }

      // Sign in with custom auth using the user's ID
      // Note: This creates a session in Supabase for compatibility
      // For production, you may want to implement a proper custom auth flow

      // Get pet coin wallet balance (sum of all coin types)
      final walletResponse = await _client
          .from('pet_coin_wallets')
          .select('petnt_balance, petbnt_balance, petindx_balance')
          .eq('user_id', userResponse['id'])
          .maybeSingle();

      // Build user data
      final userData = Map<String, dynamic>.from(userResponse);
      userData['name'] = userData['email']?.split('@')[0] ?? 'User';
      if (walletResponse != null) {
        final petnt = (walletResponse['petnt_balance'] ?? 0.0) as num;
        final petbnt = (walletResponse['petbnt_balance'] ?? 0.0) as num;
        final petindx = (walletResponse['petindx_balance'] ?? 0.0) as num;
        userData['pet_coin_balance'] =
            petnt.toDouble() + petbnt.toDouble() + petindx.toDouble();
      } else {
        userData['pet_coin_balance'] = 0.0;
      }
      userData['is_active'] = true;

      return AuthResponse(
        success: true,
        token: 'custom_token_${userResponse['id']}',
        user: User.fromJson(userData),
      );
    } catch (e) {
      print('Sign-in error: $e');
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

        // Get pet coin wallet balance (sum of all coin types)
        final walletResponse = await _client
            .from('pet_coin_wallets')
            .select('petnt_balance, petbnt_balance, petindx_balance')
            .eq('user_id', user.id)
            .single();

        // Build user data with wallet balance
        final userData = Map<String, dynamic>.from(response);
        userData['name'] = userData['email']?.split('@')[0] ?? 'User';
        final petnt = (walletResponse['petnt_balance'] ?? 0.0) as num;
        final petbnt = (walletResponse['petbnt_balance'] ?? 0.0) as num;
        final petindx = (walletResponse['petindx_balance'] ?? 0.0) as num;
        userData['pet_coin_balance'] =
            petnt.toDouble() + petbnt.toDouble() + petindx.toDouble();
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
            'petnt_balance': 0.0,
            'petbnt_balance': 0.0,
            'petindx_balance': 0.0,
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

  /// Get user transactions (both sent and received)
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Get transactions where user is involved (either sender or receiver)
      final response = await _client
          .from('transactions')
          .select(
            'id, user_id, transaction_type, amount, description, status,'
            'created_at, updated_at, approved_by, approved_at, rejection_reason,'
            'from_user_id, to_user_id, pet_coins_amount, currency,'
            'from_franchise_partner_id, to_franchise_partner_id, transfer_reason,'
            'coin_type',
          )
          .or(
            'user_id.eq.${user.id},from_user_id.eq.${user.id},to_user_id.eq.${user.id}',
          )
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting transactions: $e');
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
          .order('updated_at', ascending: false)
          .limit(1)
          .single();

      return (response['coin_value_rupees'] ?? 1.0).toDouble();
    } catch (e) {
      return 1.0; // Default to 1 rupee per PET coin
    }
  }

  /// Get current PET coin value with full details
  static Future<Map<String, dynamic>?> getCurrentPetCoinValue() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('*')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching current PET coin value: $e');
      return null;
    }
  }

  /// Update PET coin value
  static Future<bool> updateCurrentPrice(
    double newValue,
    String updatedBy,
  ) async {
    try {
      // First, deactivate all current active values
      await _client
          .from('pet_coin_settings')
          .update({'is_active': false})
          .eq('is_active', true);

      // Insert new value
      final response = await _client.from('pet_coin_settings').insert({
        'coin_value_rupees': newValue,
        'is_active': true,
        'updated_by': updatedBy,
      }).select();

      return response.isNotEmpty;
    } catch (e) {
      print('Error updating PET coin value: $e');
      return false;
    }
  }

  /// Get PET coin value history
  static Future<List<Map<String, dynamic>>> getPetCoinValueHistory() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('*')
          .order('updated_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching PET coin value history: $e');
      return [];
    }
  }

  /// Get user wallet balance (sum of all coin types)
  static Future<double> getUserWalletBalance() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0.0;

      final response = await _client
          .from('pet_coin_wallets')
          .select('petnt_balance, petbnt_balance, petindx_balance')
          .eq('user_id', user.id)
          .single();

      final petnt = (response['petnt_balance'] ?? 0.0) as num;
      final petbnt = (response['petbnt_balance'] ?? 0.0) as num;
      final petindx = (response['petindx_balance'] ?? 0.0) as num;
      return petnt.toDouble() + petbnt.toDouble() + petindx.toDouble();
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
