import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/supabase_config.dart';

class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String description;
  final String status;
  final String transactionType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? userEmail;
  // PET Coin Transfer fields
  final String? fromUserId;
  final String? toUserId;
  final double? petCoinsAmount;
  final String? fromFranchisePartnerId;
  final String? toFranchisePartnerId;
  final String? transferReason;
  final String? fromUserEmail;
  final String? toUserEmail;
  final String? fromFranchisePartnerName;
  final String? toFranchisePartnerName;

  Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.description,
    required this.status,
    required this.transactionType,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.userEmail,
    this.fromUserId,
    this.toUserId,
    this.petCoinsAmount,
    this.fromFranchisePartnerId,
    this.toFranchisePartnerId,
    this.transferReason,
    this.fromUserEmail,
    this.toUserEmail,
    this.fromFranchisePartnerName,
    this.toFranchisePartnerName,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'],
      description: json['description'],
      status: json['status'],
      transactionType: json['transaction_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at']) : null,
      rejectionReason: json['rejection_reason'],
      userEmail: json['user_email'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      petCoinsAmount: json['pet_coins_amount'] != null ? (json['pet_coins_amount'] as num).toDouble() : null,
      fromFranchisePartnerId: json['from_franchise_partner_id'],
      toFranchisePartnerId: json['to_franchise_partner_id'],
      transferReason: json['transfer_reason'],
      fromUserEmail: json['from_user_email'],
      toUserEmail: json['to_user_email'],
      fromFranchisePartnerName: json['from_franchise_partner_name'],
      toFranchisePartnerName: json['to_franchise_partner_name'],
    );
  }
}

class TransferService {
  static supabase.SupabaseClient get _client => SupabaseConfig.client;

  /// Get pending PET coin transfer transactions
  static Future<({List<Transaction> transactions, String? error})> getPendingTransactions() async {
    try {
      // Get only PET coin transfer transactions
      final response = await _client
          .from('transactions')
          .select('*')
          .eq('status', 'pending')
          .eq('transaction_type', 'pet_coin_transfer')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return (transactions: <Transaction>[], error: null);
      }

      // Get all unique user IDs from transactions
      final allUserIds = <String>{};
      final allFranchiseIds = <String>{};
      
      for (var transaction in response) {
        if (transaction['user_id'] != null) allUserIds.add(transaction['user_id']);
        if (transaction['from_user_id'] != null) allUserIds.add(transaction['from_user_id']);
        if (transaction['to_user_id'] != null) allUserIds.add(transaction['to_user_id']);
        if (transaction['from_franchise_partner_id'] != null) allFranchiseIds.add(transaction['from_franchise_partner_id']);
        if (transaction['to_franchise_partner_id'] != null) allFranchiseIds.add(transaction['to_franchise_partner_id']);
      }

      // Fetch all users in one query
      Map<String, String> userEmailMap = {};
      if (allUserIds.isNotEmpty) {
        try {
          final usersResponse = await _client
              .from('users')
              .select('id, email')
              .inFilter('id', allUserIds.toList());
          
          for (var user in usersResponse) {
            userEmailMap[user['id']] = user['email'];
          }
        } catch (e) {
          print('Error fetching users: $e');
        }
      }

      // Fetch all franchise partners in one query
      Map<String, String> franchiseNameMap = {};
      if (allFranchiseIds.isNotEmpty) {
        try {
          final franchiseResponse = await _client
              .from('franchise_partners')
              .select('id, name')
              .inFilter('id', allFranchiseIds.toList());
          
          for (var partner in franchiseResponse) {
            franchiseNameMap[partner['id']] = partner['name'];
          }
        } catch (e) {
          print('Error fetching franchise partners: $e');
        }
      }

      // Combine transactions with all related data
      final transactionsWithData = response.map((transaction) {
        final transactionData = Map<String, dynamic>.from(transaction);
        transactionData['user_email'] = userEmailMap[transaction['user_id']] ?? 'Unknown';
        transactionData['from_user_email'] = transaction['from_user_id'] != null 
            ? userEmailMap[transaction['from_user_id']] ?? 'Unknown' 
            : null;
        transactionData['to_user_email'] = transaction['to_user_id'] != null 
            ? userEmailMap[transaction['to_user_id']] ?? 'Unknown' 
            : null;
        transactionData['from_franchise_partner_name'] = transaction['from_franchise_partner_id'] != null 
            ? franchiseNameMap[transaction['from_franchise_partner_id']] ?? 'Unknown' 
            : null;
        transactionData['to_franchise_partner_name'] = transaction['to_franchise_partner_id'] != null 
            ? franchiseNameMap[transaction['to_franchise_partner_id']] ?? 'Unknown' 
            : null;
        
        return Transaction.fromJson(transactionData);
      }).toList();

      return (transactions: transactionsWithData, error: null);
    } catch (e) {
      print('Error fetching pending transactions: $e');
      return (
        transactions: <Transaction>[],
        error: e.toString()
      );
    }
  }

  /// Approve a transaction
  static Future<({bool success, String? error})> approveTransaction(String transactionId, String adminUserId) async {
    try {
      // Use the database function to atomically transfer coins and approve transaction
      final response = await _client.rpc('transfer_pet_coins_and_approve', params: {
        'transaction_id': transactionId,
        'admin_user_id': adminUserId,
      });

      if (response == null) {
        return (success: false, error: 'Transaction approval failed - no data returned');
      }

      return (success: true, error: null);
    } catch (e) {
      print('Error approving transaction: $e');
      return (
        success: false,
        error: e.toString()
      );
    }
  }

  /// Reject a transaction
  static Future<({bool success, String? error})> rejectTransaction(String transactionId, String reason) async {
    try {
      final response = await _client
          .from('transactions')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId)
          .select();

      if (response.isEmpty) {
        return (success: false, error: 'Transaction not found');
      }

      return (success: true, error: null);
    } catch (e) {
      print('Error rejecting transaction: $e');
      return (
        success: false,
        error: e.toString()
      );
    }
  }

  /// Get wallet balance for a user
  static Future<({double balance, String? error})> getWalletBalance(String userId) async {
    try {
      final response = await _client
          .from('pet_coin_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return (balance: 0.0, error: null);
      }

      return (balance: (response['balance'] as num).toDouble(), error: null);
    } catch (e) {
      print('Error fetching wallet balance: $e');
      return (
        balance: 0.0,
        error: e.toString()
      );
    }
  }

  /// Format coins for display
  static String formatCoins(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Format date for display
  static String formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }
  }
}
