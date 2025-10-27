import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/search_service.dart';
import '../services/transfer_service.dart';
import '../services/user_management_service.dart';
import '../services/pet_coin_value_service.dart';
import '../services/pet_coin_wallet_service.dart';
import '../models/user.dart';
import '../signin.dart';
import '../admin/coinwallets.dart';
import '../admin/coinvalue.dart';
import '../admin/usermanagement.dart';
import '../admin/transfer.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  User? currentUser;
  bool isLoading = true;
  bool dropdownOpen = false;
  int pendingTransfers = 0;
  double petCoinValue = 1.0;
  double totalPendingCoins = 0.0;
  int totalUsers = 0;
  int customerCount = 0;
  int partnerCount = 0;
  int adminCount = 0;
  double companyBalance = 0.0;
  double totalCoinsInCirculation = 0.0;
  int totalWallets = 0;
  
  // Quick search functionality
  String searchQuery = '';
  List<SearchResult> suggestions = [];
  bool showSuggestions = false;
  bool searchLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = await AuthService.getCurrentUser();
      final dashboardData = await _getAdminDashboardData();
      
      setState(() {
        currentUser = user;
        pendingTransfers = dashboardData['pendingTransfers'] ?? 0;
        totalPendingCoins = dashboardData['totalPendingCoins'] ?? 0.0;
        petCoinValue = dashboardData['currentPetCoinPrice'] ?? 1.0;
        totalUsers = dashboardData['totalUsers'] ?? 0;
        customerCount = dashboardData['customerCount'] ?? 0;
        partnerCount = dashboardData['partnerCount'] ?? 0;
        adminCount = dashboardData['adminCount'] ?? 0;
        companyBalance = dashboardData['companyBalance'] ?? 0.0;
        totalCoinsInCirculation = dashboardData['totalCoinsInCirculation'] ?? 0.0;
        totalWallets = dashboardData['totalWallets'] ?? 0;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleSignOut() async {
                await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInPage()),
    );
  }

  Future<void> handleQuickSearch(String query) async {
    setState(() {
      searchQuery = query;
    });

    // Clear suggestions when query is empty
    if (query.trim().isEmpty) {
      setState(() {
        suggestions = [];
        showSuggestions = false;
      });
      return;
    }

    // Fetch suggestions while typing
    if (query.length >= 2) {
      await fetchQuickSearchSuggestions(query);
    }
  }

  Future<void> fetchQuickSearchSuggestions(String query) async {
    try {
      final result = await SearchService.searchUsers(query);
      if (result.error == null && result.users.isNotEmpty) {
        setState(() {
          suggestions = result.users.take(5).toList(); // Limit to 5 suggestions
          showSuggestions = true;
        });
      }
    } catch (e) {
      print('Quick search suggestion error: $e');
      setState(() {
        suggestions = [];
      });
    }
  }

  void handleSuggestionSelect(SearchResult suggestion) {
    setState(() {
      searchQuery = suggestion.email;
      _searchController.text = suggestion.email;
      showSuggestions = false;
    });
    navigateToUserManagementWithSearch(suggestion.email);
  }

  void navigateToUserManagementWithSearch(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserManagementPage(initialSearchQuery: query),
      ),
    ).then((_) {
      // Clear search when returning
      setState(() {
        searchQuery = '';
        _searchController.clear();
        suggestions = [];
        showSuggestions = false;
      });
    });
  }

  void handleQuickSearchSubmit() {
    if (searchQuery.trim().isNotEmpty) {
      navigateToUserManagementWithSearch(searchQuery);
    }
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
                'Loading dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
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
              if (showSuggestions) {
                setState(() {
                  showSuggestions = false;
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
                        // App Logo/Title
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'P',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pet App',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  'Admin Portal',
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      currentUser?.name.substring(0, 1).toUpperCase() ?? 'S',
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
                                  dropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
                          // Admin Header Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '👑',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin Dashboard',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Manage PET Coin system and users',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFE0E7FF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Quick Search Card
                          _buildQuickSearchCard(),
                          const SizedBox(height: 16),

                          // Admin Feature Cards Grid
                          _buildAdminCard(
                            icon: '🪙',
                            title: 'PET Coin Transfers',
                            subtitle: 'Manage pending transfers and approvals',
                            gradient: const [Color(0xFFA855F7), Color(0xFF6366F1)],
                            stats: [
                              {'label': 'Pending Transfers', 'value': '$pendingTransfers'},
                              {'label': 'Total PET Coins', 'value': TransferService.formatCoins(totalPendingCoins)},
                            ],
                            buttonText: 'Manage →',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TransferPage()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),


                          _buildAdminCard(
                            icon: '👥',
                            title: 'User Management',
                            subtitle: 'Add and manage users',
                            gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                            stats: [
                              {'label': 'Total Users', 'value': '$totalUsers'},
                              {'label': 'Customers', 'value': '$customerCount'},
                              {'label': 'Partners', 'value': '$partnerCount'},
                              {'label': 'Admins', 'value': '$adminCount'},
                            ],
                            buttonText: 'Manage Users →',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UserManagementPage()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildAdminCard(
                            icon: '🪙',
                            title: 'PET Coin Value',
                            subtitle: 'Set exchange rate',
                            gradient: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            stats: [
                              {'label': 'Current Rate', 'value': PetCoinValueService.formatCurrency(petCoinValue)},
                              {'label': 'Company Value', 'value': _formatCompanyValue(companyBalance)},
                            ],
                            buttonText: 'Set Value →',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CoinValuePage()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildAdminCard(
                            icon: '🪙',
                            title: 'PET Coin Wallets',
                            subtitle: 'Manage user balances',
                            gradient: const [Color(0xFFA855F7), Color(0xFF6366F1)],
                            stats: [
                              {'label': 'Total Wallets', 'value': '$totalWallets'},
                              {'label': 'Coins in Circulation', 'value': PetCoinWalletService.formatCoins(totalCoinsInCirculation)},
                            ],
                            buttonText: 'Manage Wallets →',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CoinWalletsPage()),
                              );
                            },
                          ),
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
              top: 100, // Adjust based on your header height
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Container(
                        height: 1,
                        color: const Color(0xFFE5E7EB),
                      ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Dashboard
            _buildBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Dashboard',
              isActive: true,
              onTap: () {
                // Already on dashboard, no navigation needed
              },
            ),
            // Users
            _buildBottomNavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              label: 'Users',
              isActive: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserManagementPage()),
                );
              },
            ),
            // Center Elevated Option (Flying Money)
            _buildCenterNavItem(
              icon: Icons.flight_takeoff,
              label: 'Transfer',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransferPage()),
                );
              },
            ),
            // Value
            _buildBottomNavItem(
              icon: Icons.attach_money_outlined,
              activeIcon: Icons.attach_money,
              label: 'Value',
              isActive: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinValuePage()),
                );
              },
            ),
            // Wallets
            _buildBottomNavItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet,
              label: 'Wallets',
              isActive: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinWalletsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAdminCard({
    required String icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required List<Map<String, String>> stats,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...stats.map((stat) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stat['label']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      stat['value']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              )),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradient[0],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  /// Get admin dashboard data
  Future<Map<String, dynamic>> _getAdminDashboardData() async {
    try {
      // Get pending transfers using TransferService
      final pendingTransfersResult = await TransferService.getPendingTransactions();
      final pendingTransfers = pendingTransfersResult.transactions;
      
      // Get user statistics using UserManagementService
      final userStatsResult = await UserManagementService.getUserStatistics();
      
      // Get current PET coin value using PetCoinValueService
      final petCoinValueResult = await PetCoinValueService.getCurrentValue();
      
      // Get wallet statistics using PetCoinWalletService
      final totalCoinsResult = await PetCoinWalletService.getTotalCoinsInCirculation();
      final allWalletsResult = await PetCoinWalletService.getAllWallets();
      
      // Calculate total pending coins from transfer amounts
      double totalPendingCoins = 0.0;
      for (var transfer in pendingTransfers) {
        totalPendingCoins += transfer.petCoinsAmount ?? 0.0;
      }
      
      // Calculate company balance (total coins in circulation * current price)
      double companyBalance = 0.0;
      if (totalCoinsResult.error == null && petCoinValueResult.value != null) {
        companyBalance = totalCoinsResult.total * petCoinValueResult.value!.coinValueRupees;
      }
      
      return {
        'pendingTransfers': pendingTransfers.length,
        'totalPendingCoins': totalPendingCoins,
        'totalUsers': userStatsResult.totalUsers,
        'customerCount': userStatsResult.customerCount,
        'partnerCount': userStatsResult.partnerCount,
        'adminCount': userStatsResult.adminCount,
        'companyBalance': companyBalance,
        'currentPetCoinPrice': petCoinValueResult.value?.coinValueRupees ?? 1.0,
        'totalCoinsInCirculation': totalCoinsResult.total,
        'totalWallets': allWalletsResult.wallets.length,
        'pendingTransfersList': pendingTransfers,
      };
    } catch (e) {
      print('Error loading admin dashboard data: $e');
      return {
        'pendingTransfers': 0,
        'totalPendingCoins': 0.0,
        'totalUsers': 0,
        'customerCount': 0,
        'partnerCount': 0,
        'adminCount': 0,
        'companyBalance': 0.0,
        'currentPetCoinPrice': 1.0,
        'totalCoinsInCirculation': 0.0,
        'totalWallets': 0,
        'pendingTransfersList': [],
      };
    }
  }

  /// Format company value as whole number with Cr suffix
  String _formatCompanyValue(double value) {
    if (value >= 10000000) { // 1 crore
      return '${(value / 10000000).toStringAsFixed(0)}Cr';
    } else if (value >= 100000) { // 1 lakh
      return '${(value / 100000).toStringAsFixed(0)}L';
    } else if (value >= 1000) { // 1 thousand
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  /// Build bottom navigation item
  Widget _buildBottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build center elevated navigation item
  Widget _buildCenterNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Search',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Find users instantly',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: handleQuickSearch,
            onTap: () {
              if (suggestions.isNotEmpty) {
                setState(() {
                  showSuggestions = true;
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Search all users...',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
              suffixIcon: Container(
                margin: const EdgeInsets.all(8),
                child: ElevatedButton(
                  onPressed: handleQuickSearchSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          // Suggestions within the card
          if (showSuggestions && suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: suggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () => handleSuggestionSelect(suggestion),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: SearchService.getRoleColors(suggestion.role),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                suggestion.email.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.email,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  SearchService.formatRole(suggestion.role),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: SearchService.getRoleColors(suggestion.role)[0].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              SearchService.formatRole(suggestion.role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: SearchService.getRoleColors(suggestion.role)[0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

