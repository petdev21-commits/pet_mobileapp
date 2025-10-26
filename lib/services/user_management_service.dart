import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';
import 'pet_coin_wallet_service.dart';

class NewUser {
  final String email;
  final String password;
  final String role;

  NewUser({
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'role': role,
    };
  }
}

class UserManagementResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? user;

  UserManagementResult({
    required this.success,
    this.error,
    this.user,
  });
}

class UserManagementService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  /// Create a new user
  static Future<UserManagementResult> createUser(NewUser userData) async {
    try {
      // Generate a unique ID for the user
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final response = await _client
          .from('users')
          .insert({
            'id': userId,
            'email': userData.email,
            'role': userData.role,
            'password': userData.password, // Store password directly (for demo purposes)
            'name': userData.email.split('@')[0], // Generate name from email
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id, email, role, name, created_at')
          .single();

      // Create a PET coin wallet for the new user
      final walletResult = await PetCoinWalletService.createWalletForUser(userId);
      
      if (walletResult.error != null) {
        print('Error creating wallet for new user: ${walletResult.error}');
        // Don't fail user creation if wallet creation fails, just log the error
      }

      return UserManagementResult(
        success: true,
        user: response,
      );
    } catch (e) {
      print('Error creating user: $e');
      return UserManagementResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get all users
  static Future<({List<Map<String, dynamic>> users, String? error})> getAllUsers() async {
    try {
      print('Fetching all users from Supabase public.users table...');
      
      // Get users from public.users table (where your actual data is stored)
      final response = await _client
          .from('users')
          .select('id, email, role, created_at')
          .order('created_at', ascending: false);

      print('Raw users response from public.users: $response');

      if (response.isEmpty) {
        print('No users found in public.users table');
        return (users: <Map<String, dynamic>>[], error: null);
      }

      // Convert to our format with name generated from email
      final users = response.map((user) {
        return {
          'id': user['id'] ?? '',
          'email': user['email'] ?? '',
          'role': user['role'] ?? 'customer',
          'name': (user['email'] ?? '').split('@')[0], // Generate name from email
          'created_at': user['created_at'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      print('Processed ${users.length} users from public.users table');
      
      return (users: users, error: null);
    } catch (e) {
      print('Error fetching users from public.users: $e');
      return (users: <Map<String, dynamic>>[], error: e.toString());
    }
  }

  /// Delete a user
  static Future<UserManagementResult> deleteUser(String userId) async {
    try {
      await _client
          .from('users')
          .delete()
          .eq('id', userId);

      return UserManagementResult(success: true);
    } catch (e) {
      print('Error deleting user: $e');
      return UserManagementResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Update user role
  static Future<UserManagementResult> updateUserRole(String userId, String newRole) async {
    try {
      final response = await _client
          .from('users')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select('id, email, role, name, updated_at')
          .single();

      return UserManagementResult(
        success: true,
        user: response,
      );
    } catch (e) {
      print('Error updating user role: $e');
      return UserManagementResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get user by ID
  static Future<({Map<String, dynamic>? user, String? error})> getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, name, created_at, updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return (user: null, error: null);
      }

      return (user: response, error: null);
    } catch (e) {
      print('Error fetching user: $e');
      return (user: null, error: e.toString());
    }
  }

  /// Get users by role
  static Future<({List<Map<String, dynamic>> users, String? error})> getUsersByRole(String role) async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, name, created_at')
          .eq('role', role)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return (users: <Map<String, dynamic>>[], error: null);
      }

      return (users: List<Map<String, dynamic>>.from(response), error: null);
    } catch (e) {
      print('Error fetching users by role: $e');
      return (users: <Map<String, dynamic>>[], error: e.toString());
    }
  }

  /// Get user statistics
  static Future<({int totalUsers, int customerCount, int partnerCount, int adminCount, String? error})> getUserStatistics() async {
    try {
      print('Fetching user statistics from Supabase public.users table...');
      
      // Get users from public.users table (where your actual data is stored)
      final response = await _client
          .from('users')
          .select('role');

      print('Raw response from public.users: $response');

      if (response.isEmpty) {
        print('No users found in public.users table');
        return (totalUsers: 0, customerCount: 0, partnerCount: 0, adminCount: 0, error: null);
      }

      int totalUsers = response.length;
      int customerCount = 0;
      int partnerCount = 0;
      int adminCount = 0;

      for (var user in response) {
        final role = user['role']?.toString().toLowerCase() ?? 'customer';
        print('Processing user with role: $role');
        switch (role) {
          case 'customer':
            customerCount++;
            break;
          case 'merchant':
          case 'partner':
          case 'franchise':
          case 'sub-franchise':
          case 'channel_partner':
            partnerCount++;
            break;
          case 'admin':
            adminCount++;
            break;
        }
      }

      print('Statistics calculated: total=$totalUsers, customers=$customerCount, partners=$partnerCount, admins=$adminCount');

      return (
        totalUsers: totalUsers,
        customerCount: customerCount,
        partnerCount: partnerCount,
        adminCount: adminCount,
        error: null
      );
    } catch (e) {
      print('Error fetching user statistics from public.users: $e');
      return (
        totalUsers: 0,
        customerCount: 0,
        partnerCount: 0,
        adminCount: 0,
        error: e.toString()
      );
    }
  }

  /// Search users
  static Future<({List<Map<String, dynamic>> users, String? error})> searchUsers(String query) async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, name, created_at')
          .or('email.ilike.%$query%,name.ilike.%$query%,role.ilike.%$query%')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return (users: <Map<String, dynamic>>[], error: null);
      }

      return (users: List<Map<String, dynamic>>.from(response), error: null);
    } catch (e) {
      print('Error searching users: $e');
      return (users: <Map<String, dynamic>>[], error: e.toString());
    }
  }

  /// Validate user data
  static String? validateUserData(NewUser userData) {
    if (userData.email.isEmpty) {
      return 'Email is required';
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(userData.email)) {
      return 'Please enter a valid email address';
    }
    
    if (userData.password.isEmpty) {
      return 'Password is required';
    }
    
    if (userData.password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    if (userData.role.isEmpty) {
      return 'Role is required';
    }
    
    final validRoles = ['admin', 'customer', 'merchant', 'partner', 'franchise', 'sub-franchise', 'channel_partner', 'bank'];
    if (!validRoles.contains(userData.role.toLowerCase())) {
      return 'Please select a valid role';
    }
    
    return null;
  }

  /// Format role for display
  static String formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'channel_partner':
        return 'Channel Partner';
      case 'sub-franchise':
        return 'Sub-Franchise';
      case 'merchant':
        return 'Merchant';
      case 'partner':
        return 'Partner';
      case 'franchise':
        return 'Franchise';
      case 'admin':
        return 'Admin';
      case 'customer':
        return 'Customer';
      case 'bank':
        return 'Bank';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }

  /// Get role color
  static List<Color> getRoleColors(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
      case 'merchant':
      case 'partner':
        return [const Color(0xFFF59E0B), const Color(0xFFEA580C)];
      case 'franchise':
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case 'sub-franchise':
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
      case 'channel_partner':
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case 'bank':
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      default:
        return [const Color(0xFF3B82F6), const Color(0xFF06B6D4)];
    }
  }
}
