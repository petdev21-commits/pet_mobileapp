import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';

class PetCoinValue {
  final String id;
  final double coinValueRupees;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;

  PetCoinValue({
    required this.id,
    required this.coinValueRupees,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
  });

  factory PetCoinValue.fromJson(Map<String, dynamic> json) {
    return PetCoinValue(
      id: json['id'] ?? '',
      coinValueRupees: (json['coin_value_rupees'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coin_value_rupees': coinValueRupees,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }
}

class PetCoinValueResult {
  final bool success;
  final String? error;
  final PetCoinValue? value;

  PetCoinValueResult({
    required this.success,
    this.error,
    this.value,
  });
}

class PetCoinValueService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  /// Get current PET coin value
  static Future<({PetCoinValue? value, String? error})> getCurrentValue() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('*')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return (value: null, error: null);
      }

      final value = PetCoinValue.fromJson(response);
      return (value: value, error: null);
    } catch (e) {
      print('Error fetching current PET coin value: $e');
      return (value: null, error: e.toString());
    }
  }

  /// Update PET coin value
  static Future<PetCoinValueResult> updateValue(double newValue, String updatedBy) async {
    try {
      // First, deactivate all current active values
      await _client
          .from('pet_coin_settings')
          .update({'is_active': false})
          .eq('is_active', true);

      // Insert new value
      final response = await _client
          .from('pet_coin_settings')
          .insert({
            'coin_value_rupees': newValue,
            'is_active': true,
            'updated_by': updatedBy,
          })
          .select()
          .single();

      return PetCoinValueResult(
        success: true,
        value: PetCoinValue.fromJson(response),
      );
    } catch (e) {
      print('Error updating PET coin value: $e');
      return PetCoinValueResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get PET coin value history
  static Future<({List<PetCoinValue> values, String? error})> getValueHistory() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('*')
          .order('updated_at', ascending: false)
          .limit(20);

      if (response.isEmpty) {
        return (values: <PetCoinValue>[], error: null);
      }

      final values = response.map<PetCoinValue>((json) => PetCoinValue.fromJson(json)).toList();
      return (values: values, error: null);
    } catch (e) {
      print('Error fetching PET coin value history: $e');
      return (values: <PetCoinValue>[], error: e.toString());
    }
  }

  /// Get current price (simple method for backward compatibility)
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
      print('Error fetching current price: $e');
      return 1.0; // Default to 1 rupee per PET coin
    }
  }

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Format date time for display
  static String formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final year = dateTime.year;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    
    return '$month/$day/$year, ${displayHour.toString().padLeft(2, '0')}:$minute:$second $period';
  }

  /// Create default value if none exists
  static Future<PetCoinValueResult> createDefaultValue() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .insert({
            'coin_value_rupees': 1.0,
            'is_active': true,
            'updated_by': 'system',
          })
          .select()
          .single();

      return PetCoinValueResult(
        success: true,
        value: PetCoinValue.fromJson(response),
      );
    } catch (e) {
      print('Error creating default value: $e');
      return PetCoinValueResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get value statistics
  static Future<({double totalChanges, DateTime? firstChange, DateTime? lastChange, String? error})> getValueStatistics() async {
    try {
      final response = await _client
          .from('pet_coin_settings')
          .select('created_at, updated_at')
          .order('created_at', ascending: true);

      if (response.isEmpty) {
        return (totalChanges: 0.0, firstChange: null, lastChange: null, error: null);
      }

      final totalChanges = response.length.toDouble();
      final firstChange = DateTime.parse(response.first['created_at']);
      final lastChange = DateTime.parse(response.last['updated_at']);

      return (
        totalChanges: totalChanges,
        firstChange: firstChange,
        lastChange: lastChange,
        error: null
      );
    } catch (e) {
      print('Error fetching value statistics: $e');
      return (
        totalChanges: 0.0,
        firstChange: null,
        lastChange: null,
        error: e.toString()
      );
    }
  }
}
