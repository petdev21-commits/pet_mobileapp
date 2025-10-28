import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/pet_coin_wallet_service.dart';
import '../models/user.dart';
import '../signin.dart';

class CoinWalletsPage extends StatefulWidget {
  const CoinWalletsPage({super.key});

  @override
  State<CoinWalletsPage> createState() => _CoinWalletsPageState();
}

class _CoinWalletsPageState extends State<CoinWalletsPage> {
  User? currentUser;
  bool isLoading = true;
  bool dropdownOpen = false;
  List<PetCoinWallet> wallets = [];
  double totalCoins = 0.0;
  bool showTransferForm = false;
  String transferAmount = '';
  String selectedUserId = '';
  bool isTransferring = false;
  String userSearchQuery = '';
  String selectedCoinType = 'petNT'; // Default coin type
  final TextEditingController _transferAmountController =
      TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();

  // Coin type configurations
  final Map<String, Map<String, dynamic>> coinTypes = {
    'petNT': {'name': 'PET NT', 'icon': '🔵', 'color': const Color(0xFF3B82F6)},
    'petBNT': {
      'name': 'PET BNT',
      'icon': '🟢',
      'color': const Color(0xFF10B981),
    },
    'petINDX': {
      'name': 'PET INDX',
      'icon': '🟡',
      'color': const Color(0xFFF59E0B),
    },
  };

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadWallets();
    loadTotalCoins();
  }

  @override
  void dispose() {
    _transferAmountController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        currentUser = user;
      });
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> loadWallets() async {
    setState(() {
      isLoading = true;
    });

    try {
      // First, get all users to ensure we have wallets for everyone
      final allUsers = await SupabaseService.getAllUsers();

      // Ensure all users have wallets
      for (var user in allUsers) {
        await PetCoinWalletService.createWalletForUser(user['id']);
      }

      // Now fetch all wallets
      final result = await PetCoinWalletService.getAllWallets();

      setState(() {
        wallets = result.wallets;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading wallets: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadTotalCoins() async {
    try {
      final result = await PetCoinWalletService.getTotalCoinsInCirculation();
      setState(() {
        totalCoins = result.total;
      });
    } catch (e) {
      print('Error loading total coins: $e');
    }
  }

  Future<void> handleSignOut() async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInPage()),
    );
  }

  Future<void> handleTransfer() async {
    final amount = double.tryParse(_transferAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive amount'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (selectedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user to transfer to'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isTransferring = true;
    });

    try {
      // Get company wallet
      final companyWallet = wallets.firstWhere(
        (w) => w.userRole == 'company',
        orElse: () => wallets.first,
      );

      // Transfer using the selected coin type
      final result = await PetCoinWalletService.transferCoinsByType(
        companyWallet.userId,
        selectedUserId,
        amount,
        selectedCoinType,
      );

      if (result.success) {
        final coinName = coinTypes[selectedCoinType]!['name'] as String;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully transferred ${PetCoinWalletService.formatCoins(amount)} $coinName!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _transferAmountController.clear();
        setState(() {
          selectedUserId = '';
          userSearchQuery = '';
          _userSearchController.clear();
          showTransferForm = false;
          selectedCoinType = 'petNT'; // Reset to default
        });
        // Refresh data
        loadWallets();
        loadTotalCoins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: ${result.error}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        isTransferring = false;
      });
    }
  }

  List<PetCoinWallet> get allUserWallets {
    // Return all users except company wallet
    return wallets.where((w) => w.userRole != 'company').toList();
  }

  List<PetCoinWallet> get filteredUsers {
    if (userSearchQuery.trim().isEmpty) return allUserWallets;

    final query = userSearchQuery.toLowerCase();
    return allUserWallets.where((wallet) {
      return (wallet.userEmail?.toLowerCase().contains(query) ?? false) ||
          (wallet.userRole?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading wallet data...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main content
          GestureDetector(
            onTap: () {
              if (dropdownOpen) {
                setState(() {
                  dropdownOpen = false;
                });
              }
            },
            child: SafeArea(
              child: Column(
                children: [
                  // Top App Bar with User Profile
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button and title
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF6B7280),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PET Coin Wallets',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  'Manage user balances',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // User Profile Rectangle with Circle and Dropdown
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              dropdownOpen = !dropdownOpen;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      currentUser?.name
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          'S',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  dropdownOpen
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF6B7280),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Stats Cards Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatsCard(
                                  icon: '👥',
                                  title: 'Wallets',
                                  value: wallets.length.toString(),
                                  bgColor: const Color(0xFFF3E8FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatsCard(
                                  icon: '🪙',
                                  title: 'Total',
                                  value: PetCoinWalletService.formatCoins(
                                    totalCoins,
                                  ),
                                  bgColor: const Color(0xFFDCFCE7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatsCard(
                                  icon: '🏢',
                                  title: 'Company',
                                  value: PetCoinWalletService.formatCoins(
                                    wallets
                                        .firstWhere(
                                          (w) => w.userRole == 'company',
                                          orElse: () => PetCoinWallet(
                                            id: '',
                                            userId: '',
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                          ),
                                        )
                                        .totalBalance,
                                  ),
                                  bgColor: const Color(0xFFDBEAFE),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Transfer Coins Section
                          _buildTransferCoinsSection(),
                          const SizedBox(height: 24),

                          // Wallets List
                          _buildWalletsList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dropdown Menu Overlay
          if (dropdownOpen)
            Positioned(
              top: 100,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Email
                      Text(
                        currentUser?.email ?? 'user@example.com',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentUser?.role ?? 'admin',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Divider
                      Container(height: 1, color: const Color(0xFFE5E7EB)),
                      const SizedBox(height: 12),
                      // Sign Out Button
                      GestureDetector(
                        onTap: handleSignOut,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout,
                              color: Color(0xFFEF4444),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String icon,
    required String title,
    required String value,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCoinsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transfer Coins',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Send coins from company to any user',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showTransferForm = !showTransferForm;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: showTransferForm
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  showTransferForm ? 'Cancel' : 'Transfer',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (showTransferForm) ...[
            const SizedBox(height: 16),
            _buildTransferForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Search and Selection
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search & Select User',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    loadWallets();
                    setState(() {
                      selectedUserId = '';
                      userSearchQuery = '';
                      _userSearchController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🔄 Refresh',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search Input
            TextField(
              controller: _userSearchController,
              onChanged: (value) {
                setState(() {
                  userSearchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText:
                    'Search by email or role (e.g., franchise, channel_partner)',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // User Selection List
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  '👤',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userSearchQuery.isNotEmpty
                                  ? 'No users found matching your search'
                                  : 'No users available',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (userSearchQuery.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    userSearchQuery = '';
                                    _userSearchController.clear();
                                  });
                                },
                                child: const Text(
                                  'Clear search',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final wallet = filteredUsers[index];
                        final isSelected = selectedUserId == wallet.userId;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedUserId = wallet.userId;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFEEF2FF)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFC7D2FE)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              wallet.userEmail ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1F2937),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 60,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(
                                                wallet.userRole ?? 'customer',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getRoleDisplayName(
                                                wallet.userRole ?? 'customer',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Flexible(
                                            flex: 1,
                                            child: Text(
                                              'ID: ${wallet.id.substring(0, 5)}',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            flex: 1,
                                            child: Text(
                                              '${PetCoinWalletService.formatCoins(wallet.totalBalance)} 🪙',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF374151),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check,
                                    color: Color(0xFF6366F1),
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Selected User Display
            if (selectedUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: ${filteredUsers.firstWhere((w) => w.userId == selectedUserId).userEmail}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Coin Type Selection
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Coin Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: coinTypes.entries.map((entry) {
                final coinType = entry.key;
                final config = entry.value;
                final isSelected = selectedCoinType == coinType;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCoinType = coinType;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        right: coinType == coinTypes.keys.last ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? config['color'] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? config['color'] as Color
                              : const Color(0xFFD1D5DB),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            config['icon'] as String,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            config['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Amount Input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount (${coinTypes[selectedCoinType]!['name'] as String})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _transferAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixIcon: Icon(
                  Icons.account_balance_wallet,
                  color: coinTypes[selectedCoinType]!['color'] as Color,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: coinTypes[selectedCoinType]!['color'] as Color,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isTransferring ? null : handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isTransferring
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Transferring...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Transfer Coins',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    showTransferForm = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletsList() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Wallets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${wallets.length} wallet${wallets.length != 1 ? 's' : ''} in the system',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    loadWallets();
                    loadTotalCoins();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔄', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Loading wallets...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : wallets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: Text('🪙', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No wallets found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Wallets will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: wallets
                        .map((wallet) => _buildWalletCard(wallet))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(PetCoinWallet wallet) {
    final isCompany = wallet.userRole == 'company';
    final hasBalance = wallet.totalBalance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: isCompany
                  ? const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                    )
                  : hasBalance
                  ? const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isCompany
                    ? '🏢'
                    : (wallet.userEmail?.substring(0, 1).toUpperCase() ?? 'U'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Wallet Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        wallet.userEmail ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(wallet.userRole ?? 'customer'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getRoleDisplayName(wallet.userRole ?? 'customer'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${wallet.id.substring(0, 8)}...',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${PetCoinWalletService.formatCoins(wallet.totalBalance)} 🪙',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            hasBalance ? 'Active' : 'Empty',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            alignment: WrapAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'NT: ${PetCoinWalletService.formatCoins(wallet.petntBalance)}',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF1F2937),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'BNT: ${PetCoinWalletService.formatCoins(wallet.petbntBalance)}',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF1F2937),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'INDX: ${PetCoinWalletService.formatCoins(wallet.petindxBalance)}',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF1F2937),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'company':
        return const Color(0xFFF59E0B);
      case 'customer':
        return const Color(0xFF3B82F6);
      case 'franchise':
        return const Color(0xFF10B981);
      case 'sub-franchise':
        return const Color(0xFF8B5CF6);
      case 'channel_partner':
        return const Color(0xFFF59E0B);
      case 'admin':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'channel_partner':
        return 'Channel';
      case 'sub-franchise':
        return 'Sub-Franchise';
      case 'company':
        return 'Company';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }
}
