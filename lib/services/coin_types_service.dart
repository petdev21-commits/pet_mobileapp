import 'package:supabase_flutter/supabase_flutter.dart';

class CoinTypesService {
  static final _client = Supabase.instance.client;

  /// Get all active coin types
  static Future<List<Map<String, dynamic>>> getActiveCoinTypes() async {
    try {
      final response = await _client
          .from('coin_types')
          .select('*')
          .eq('is_active', true)
          .order('type_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching coin types: $e');
      return [];
    }
  }

  /// Get specific coin type details
  static Future<Map<String, dynamic>?> getCoinType(String typeName) async {
    try {
      final response = await _client
          .from('coin_types')
          .select('*')
          .eq('type_name', typeName)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching coin type: $e');
      return null;
    }
  }

  /// Update coin type price
  static Future<bool> updateCoinPrice(
    String typeName,
    double newPrice,
    String updatedBy,
  ) async {
    try {
      final response = await _client
          .from('coin_types')
          .update({
            'current_price_rupees': newPrice,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': updatedBy,
          })
          .eq('type_name', typeName)
          .select();

      return response.isNotEmpty;
    } catch (e) {
      print('Error updating coin price: $e');
      return false;
    }
  }

  /// Get coin type price history
  static Future<List<Map<String, dynamic>>> getPriceHistory(
    String typeName,
  ) async {
    try {
      // Note: We'll need to track price history in a separate table if needed
      // For now, return current price
      final coin = await getCoinType(typeName);
      if (coin != null) {
        return [coin];
      }
      return [];
    } catch (e) {
      print('Error fetching price history: $e');
      return [];
    }
  }

  /// Get user wallet balance for specific coin type
  static Future<double> getUserCoinBalance(
    String userId,
    String coinType,
  ) async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return 0.0;

      switch (coinType) {
        case 'petNT':
          return (response['petnt_balance'] as num?)?.toDouble() ?? 0.0;
        case 'petBNT':
          return (response['petbnt_balance'] as num?)?.toDouble() ?? 0.0;
        case 'petINDX':
          return (response['petindx_balance'] as num?)?.toDouble() ?? 0.0;
        default:
          return (response['balance'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error fetching coin balance: $e');
      return 0.0;
    }
  }

  /// Get all coin balances for a user
  static Future<Map<String, double>> getAllCoinBalances(String userId) async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return {'petNT': 0.0, 'petBNT': 0.0, 'petINDX': 0.0};
      }

      // Get new coin-specific balances
      double petntBalance =
          (response['petnt_balance'] as num?)?.toDouble() ?? 0.0;
      double petbntBalance =
          (response['petbnt_balance'] as num?)?.toDouble() ?? 0.0;
      double petindxBalance =
          (response['petindx_balance'] as num?)?.toDouble() ?? 0.0;

      // For backward compatibility: if petNT balance is 0 but legacy 'balance' exists,
      // use the legacy balance as petNT balance
      double legacyBalance = (response['balance'] as num?)?.toDouble() ?? 0.0;
      if (petntBalance == 0.0 && legacyBalance > 0.0) {
        petntBalance = legacyBalance;
      }

      return {
        'petNT': petntBalance,
        'petBNT': petbntBalance,
        'petINDX': petindxBalance,
      };
    } catch (e) {
      print('Error fetching coin balances: $e');
      return {'petNT': 0.0, 'petBNT': 0.0, 'petINDX': 0.0};
    }
  }
}
