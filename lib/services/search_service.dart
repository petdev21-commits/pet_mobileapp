import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';

class SearchResult {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;

  SearchResult({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class SearchService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  /// Search users by query (email or role)
  static Future<({List<SearchResult> users, String? error})> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) {
        return (users: <SearchResult>[], error: null);
      }

      final response = await _client
          .from('users')
          .select('id, email, role, created_at')
          .or('email.ilike.%$query%,role.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      if (response.isEmpty) {
        return (users: <SearchResult>[], error: null);
      }

      final users = response.map((user) => SearchResult.fromJson(user)).toList();
      return (users: users, error: null);
    } catch (e) {
      print('Error searching users: $e');
      return (
        users: <SearchResult>[],
        error: e.toString()
      );
    }
  }

  /// Search users by specific role
  static Future<({List<SearchResult> users, String? error})> searchByRole(String role) async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, created_at')
          .eq('role', role)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return (users: <SearchResult>[], error: null);
      }

      final users = response.map((user) => SearchResult.fromJson(user)).toList();
      return (users: users, error: null);
    } catch (e) {
      print('Error searching users by role: $e');
      return (
        users: <SearchResult>[],
        error: e.toString()
      );
    }
  }

  /// Get all users (for initial load)
  static Future<({List<SearchResult> users, String? error})> getAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, created_at')
          .order('created_at', ascending: false)
          .limit(50);

      if (response.isEmpty) {
        return (users: <SearchResult>[], error: null);
      }

      final users = response.map((user) => SearchResult.fromJson(user)).toList();
      return (users: users, error: null);
    } catch (e) {
      print('Error getting all users: $e');
      return (
        users: <SearchResult>[],
        error: e.toString()
      );
    }
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

  /// Get role colors for UI
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

  /// Format date for display
  static String formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
