import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';

class PetCoinWallet {
  final String id;
  final String userId;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userEmail;
  final String? userRole;

  PetCoinWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
    this.userEmail,
    this.userRole,
  });

  factory PetCoinWallet.fromJson(Map<String, dynamic> json) {
    return PetCoinWallet(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      userEmail: json['user']?['email'],
      userRole: json['user']?['role'],
    );
  }
}

class WalletResult {
  final bool success;
  final String? error;
  final PetCoinWallet? wallet;

  WalletResult({
    required this.success,
    this.error,
    this.wallet,
  });
}

class PetCoinWalletService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  /// Get all wallets with user information
  static Future<({List<PetCoinWallet> wallets, String? error})> getAllWallets() async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('''
            id, user_id, balance, created_at, updated_at,
            user:users!pet_coin_wallets_user_id_fkey(email, role)
          ''')
          .order('balance', ascending: false);

      if (response.isEmpty) {
        return (wallets: <PetCoinWallet>[], error: null);
      }

      final wallets = response.map<PetCoinWallet>((json) => PetCoinWallet.fromJson(json)).toList();
      return (wallets: wallets, error: null);
    } catch (e) {
      print('Error fetching wallets: $e');
      return (wallets: <PetCoinWallet>[], error: e.toString());
    }
  }

  /// Get wallet by user ID
  static Future<({PetCoinWallet? wallet, String? error})> getWalletByUserId(String userId) async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('''
            id, user_id, balance, created_at, updated_at,
            user:users!pet_coin_wallets_user_id_fkey(email, role)
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return (wallet: null, error: null);
      }

      final wallet = PetCoinWallet.fromJson(response);
      return (wallet: wallet, error: null);
    } catch (e) {
      print('Error fetching wallet: $e');
      return (wallet: null, error: e.toString());
    }
  }

  /// Update wallet balance
  static Future<WalletResult> updateBalance(String userId, double newBalance) async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .update({
            'balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();

      return WalletResult(
        success: true,
        wallet: PetCoinWallet.fromJson(response),
      );
    } catch (e) {
      print('Error updating balance: $e');
      return WalletResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Add coins to wallet
  static Future<WalletResult> addCoins(String userId, double amount) async {
    try {
      // First get current balance
      final result = await getWalletByUserId(userId);
      if (result.error != null || result.wallet == null) {
        return WalletResult(
          success: false,
          error: 'Wallet not found',
        );
      }

      final newBalance = result.wallet!.balance + amount;
      return await updateBalance(userId, newBalance);
    } catch (e) {
      print('Error adding coins: $e');
      return WalletResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Deduct coins from wallet
  static Future<WalletResult> deductCoins(String userId, double amount) async {
    try {
      // First get current balance
      final result = await getWalletByUserId(userId);
      if (result.error != null || result.wallet == null) {
        return WalletResult(
          success: false,
          error: 'Wallet not found',
        );
      }

      if (result.wallet!.balance < amount) {
        return WalletResult(
          success: false,
          error: 'Insufficient balance',
        );
      }

      final newBalance = result.wallet!.balance - amount;
      return await updateBalance(userId, newBalance);
    } catch (e) {
      print('Error deducting coins: $e');
      return WalletResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Transfer coins between wallets
  static Future<WalletResult> transferCoins(String fromUserId, String toUserId, double amount) async {
    try {
      // Get sender wallet
      final fromResult = await getWalletByUserId(fromUserId);
      if (fromResult.error != null || fromResult.wallet == null) {
        return WalletResult(
          success: false,
          error: 'Sender wallet not found',
        );
      }

      if (fromResult.wallet!.balance < amount) {
        return WalletResult(
          success: false,
          error: 'Insufficient balance',
        );
      }

      // Deduct from sender
      final deductResult = await deductCoins(fromUserId, amount);
      if (!deductResult.success) {
        return deductResult;
      }

      // Add to receiver (or create wallet if doesn't exist)
      final toResult = await getWalletByUserId(toUserId);
      if (toResult.wallet == null) {
        // Create new wallet for receiver
        final createResult = await createWalletForUser(toUserId);
        if (!createResult.success) {
          // Rollback: add back to sender
          await addCoins(fromUserId, amount);
          return createResult;
        }
      }

      final addResult = await addCoins(toUserId, amount);
      if (!addResult.success) {
        // Rollback: add back to sender
        await addCoins(fromUserId, amount);
        return addResult;
      }

      return WalletResult(success: true);
    } catch (e) {
      print('Error transferring coins: $e');
      return WalletResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get total coins in circulation
  static Future<({double total, String? error})> getTotalCoinsInCirculation() async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('balance');

      if (response.isEmpty) {
        return (total: 0.0, error: null);
      }

      double total = 0.0;
      for (var wallet in response) {
        total += (wallet['balance'] ?? 0.0).toDouble();
      }

      return (total: total, error: null);
    } catch (e) {
      print('Error calculating total coins: $e');
      return (total: 0.0, error: e.toString());
    }
  }

  /// Create wallet for user
  static Future<WalletResult> createWalletForUser(String userId) async {
    try {
      // Check if wallet already exists
      final existingResult = await getWalletByUserId(userId);
      if (existingResult.wallet != null) {
        return WalletResult(
          success: true,
          wallet: existingResult.wallet,
        );
      }

      // Create new wallet with 0 balance
      final response = await _client
          .from('pet_coin_wallets')
          .insert({
            'user_id': userId,
            'balance': 0.0,
          })
          .select()
          .single();

      return WalletResult(
        success: true,
        wallet: PetCoinWallet.fromJson(response),
      );
    } catch (e) {
      print('Error creating wallet: $e');
      return WalletResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Format coins for display
  static String formatCoins(double amount) {
    if (amount >= 10000000) { // 1 crore
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) { // 1 lakh
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) { // 1 thousand
      return '${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}
