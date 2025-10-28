import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/search_service.dart';
import '../services/transfer_service.dart';
import '../services/coin_types_service.dart';
import '../models/user.dart';
import '../signin.dart';
import '../qr_payment.dart';
import 'transaction_status.dart';

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard({super.key});

  @override
  State<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  User? currentUser;
  bool isLoading = true;
  bool dropdownOpen = false;
  double walletBalance = 0.0; // Legacy, keeping for backwards compatibility
  double currentPrice = 100.0;
  List<Map<String, dynamic>> priceHistory = [];
  List<Map<String, dynamic>> recentTransactions = [];
  int _selectedIndex = 0;

  // Multi-coin balances
  Map<String, double> coinBalances = {
    'petNT': 0.0,
    'petBNT': 0.0,
    'petINDX': 0.0,
  };

  // Coin prices
  Map<String, double> coinPrices = {
    'petNT': 90.00,
    'petBNT': 1.00,
    'petINDX': 0.50,
  };

  // Coin type configurations
  final Map<String, Map<String, dynamic>> coinConfigs = {
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
  }

  Future<void> loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = await AuthService.getCurrentUser();
      // Pass the user to ensure we have the correct user ID
      final dashboardData = await _getCustomerDashboardData(user);

      setState(() {
        currentUser = user;
        walletBalance = dashboardData['walletBalance'] ?? 0.0;
        currentPrice = dashboardData['currentPrice'] ?? 100.0;
        priceHistory = List<Map<String, dynamic>>.from(
          dashboardData['priceHistory'] ?? [],
        );
        recentTransactions = List<Map<String, dynamic>>.from(
          dashboardData['recentTransactions'] ?? [],
        );

        // Set multi-coin balances and prices
        if (dashboardData['coinBalances'] != null) {
          coinBalances = Map<String, double>.from(
            dashboardData['coinBalances'],
          );
        }
        if (dashboardData['coinPrices'] != null) {
          coinPrices = Map<String, double>.from(dashboardData['coinPrices']);
        }

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

  void _handleNavigation(int index) {
    if (index == 1) {
      // PET - Show status page
      _showStatusPage();
      // Reset to dashboard after showing status
      setState(() {
        _selectedIndex = 0;
      });
    } else if (index == 3) {
      // History
      _showTransactionHistory(context);
      // Reset to dashboard after showing history
      setState(() {
        _selectedIndex = 0;
      });
    } else if (index == 4) {
      // Status - Show transaction status page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TransactionStatusPage()),
      ).then((_) {
        // Reload data when returning from status page
        loadUserData();
        setState(() {
          _selectedIndex = 0;
        });
      });
    } else if (index == 2) {
      // Center button - QR Payment
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRPaymentScreen()),
      ).then((_) {
        // Reload data when returning from QR screen
        loadUserData();
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
    // Index 0 stays on dashboard, no action needed
  }

  Future<void> _showStatusPage() async {
    // Fetch pending transactions
    List<Map<String, dynamic>> pendingSent = [];
    List<Map<String, dynamic>> pendingReceived = [];

    if (currentUser != null) {
      try {
        final allTransactions = await SupabaseService.getTransactions();
        pendingSent = allTransactions.where((tx) {
          return tx['from_user_id'] == currentUser!.id &&
              tx['status'] == 'pending';
        }).toList();

        pendingReceived = allTransactions.where((tx) {
          return tx['to_user_id'] == currentUser!.id &&
              tx['status'] == 'pending';
        }).toList();
      } catch (e) {
        print('Error fetching pending transactions: $e');
      }
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(
                          'Account Status',
                          'Active',
                          Icons.check_circle,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusCard(
                          'Wallet Status',
                          'Active',
                          Icons.wallet,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusCard(
                          'Available Balance',
                          '${_formatPetCoins(walletBalance)} 🪙',
                          Icons.account_balance_wallet,
                          const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusCard(
                          'Total Value',
                          '₹${(walletBalance * currentPrice).toStringAsFixed(2)}',
                          Icons.currency_rupee,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusCard(
                          'Current Rate',
                          '₹${currentPrice.toStringAsFixed(2)} per PET',
                          Icons.trending_up,
                          const Color(0xFFF59E0B),
                        ),

                        // Pending Transactions Section
                        if (pendingSent.isNotEmpty ||
                            pendingReceived.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Pending Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Pending Sent
                        if (pendingSent.isNotEmpty) ...[
                          _buildPendingTransactionCard(
                            'Pending Sent',
                            pendingSent.length,
                            Icons.send,
                            const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Pending Received
                        if (pendingReceived.isNotEmpty) ...[
                          _buildPendingTransactionCard(
                            'Pending Received',
                            pendingReceived.length,
                            Icons.call_received,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (pendingSent.isEmpty && pendingReceived.isEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('✅', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Pending Transactions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All clear! No waiting transactions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildPendingTransactionCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count transaction${count > 1 ? 's' : ''} awaiting approval',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalanceCard({
    required String coinType,
    required double balance,
    required double price,
    required double totalValue,
    required Map<String, dynamic> config,
  }) {
    final color = config['color'] as Color;
    final icon = config['icon'] as String;
    final name = config['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  children: [
                    Text(
                      _formatPetCoins(balance),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '≈ ${_formatCurrency(totalValue)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Text(
                  '₹${price.toStringAsFixed(2)} per coin',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({
    required String icon,
    required String name,
    required double price,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '₹${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
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
                            'Business Portal',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // User Profile Dropdown
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        dropdownOpen = !dropdownOpen;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          currentUser?.name.substring(0, 1).toUpperCase() ??
                              'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dropdown Menu
            if (dropdownOpen)
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.email ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentUser?.role ?? 'customer',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    GestureDetector(
                      onTap: handleSignOut,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                    // Customer Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
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
                              child: Text('🏠', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome Back!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your business PET Coin wallet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Wallet Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          // Multi-Coin Wallet Display
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('💰', style: TextStyle(fontSize: 32)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Multi-Coin Wallet',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Your balances across all coin types',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Display all coin balances
                              ...coinConfigs.entries.map((entry) {
                                final coinType = entry.key;
                                final config = entry.value;
                                final balance = coinBalances[coinType] ?? 0.0;
                                final price = coinPrices[coinType] ?? 1.0;
                                final totalValue = balance * price;

                                return _buildCoinBalanceCard(
                                  coinType: coinType,
                                  balance: balance,
                                  price: price,
                                  totalValue: totalValue,
                                  config: config,
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Current Coin Prices Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          const Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: Color(0xFFF59E0B),
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Current Coin Prices',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Display all coin prices
                          ...coinConfigs.entries.map((entry) {
                            final coinType = entry.key;
                            final config = entry.value;
                            final price = coinPrices[coinType] ?? 1.0;

                            return _buildPriceRow(
                              icon: config['icon'] as String,
                              name: config['name'] as String,
                              price: price,
                              color: config['color'] as Color,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Transactions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF06B6D4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text(
                                    '📊',
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
                                      'Recent Transactions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Your latest activity',
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
                          const SizedBox(height: 20),
                          if (recentTransactions.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    '📭',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your transaction history will appear here',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            ...recentTransactions
                                .take(3)
                                .map(
                                  (transaction) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _getTransactionColor(
                                              transaction['type'],
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getTransactionIcon(
                                                transaction['type'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: _getTransactionColor(
                                                  transaction['type'],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getTransactionTypeDisplayName(
                                                  transaction['type'],
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTransactionTime(
                                                  transaction['created_at'],
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${_formatPetCoins(transaction['amount'])} 🪙',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: _getTransactionColor(
                                                  transaction['type'],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (transaction['coin_type'] !=
                                                null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                margin: const EdgeInsets.only(
                                                  bottom: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getCoinTypeColor(
                                                    transaction['coin_type'],
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getCoinTypeDisplayName(
                                                    transaction['coin_type'],
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: _getCoinTypeColor(
                                                      transaction['coin_type'],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              _getTransactionStatusDisplayName(
                                                transaction['status'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  isSelected: _selectedIndex == 0,
                ),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'PET',
                  index: 1,
                  isSelected: _selectedIndex == 1,
                ),
                _buildCenterQRButton(),
                _buildNavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  index: 3,
                  isSelected: _selectedIndex == 3,
                ),
                _buildNavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Status',
                  index: 4,
                  isSelected: _selectedIndex == 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== NAV BAR BUILDERS ====================

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        _handleNavigation(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isSelected ? 28 : 24,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1.0 : 0.7,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 12 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterQRButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = 2;
        });
        _handleNavigation(2);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'send':
        return const Color(0xFFEF4444);
      case 'receive':
        return const Color(0xFF10B981);
      case 'purchase':
        return const Color(0xFF3B82F6);
      case 'refund':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getTransactionIcon(String type) {
    switch (type) {
      case 'send':
        return '📤';
      case 'receive':
        return '📥';
      case 'purchase':
        return '🛒';
      case 'refund':
        return '↩️';
      default:
        return '💰';
    }
  }

  // ==================== HELPER METHODS ====================

  /// Get customer dashboard data
  Future<Map<String, dynamic>> _getCustomerDashboardData(User? user) async {
    try {
      // Ensure we have a valid user ID
      if (user == null || user.id.isEmpty) {
        return {
          'walletBalance': 0.0,
          'currentPrice': 100.0,
          'priceHistory': [],
          'recentTransactions': [],
          'coinBalances': {'petNT': 0.0, 'petBNT': 0.0, 'petINDX': 0.0},
          'coinPrices': {'petNT': 90.0, 'petBNT': 1.0, 'petINDX': 0.5},
        };
      }

      // Load all coin balances with the correct user ID
      Map<String, double> balances = await CoinTypesService.getAllCoinBalances(
        user.id,
      );

      // Load all coin prices
      Map<String, double> prices = {};
      final coinTypes = await CoinTypesService.getActiveCoinTypes();
      for (var coin in coinTypes) {
        final typeName = coin['type_name'] as String;
        final price = (coin['current_price_rupees'] as num).toDouble();
        prices[typeName] = price;
      }

      final walletBalance =
          balances['petNT'] ??
          0.0; // Default to petNT for backwards compatibility
      final currentPrice = prices['petNT'] ?? 100.0;
      final transactionHistory = await SupabaseService.getTransactions();

      // Fetch user emails for transactions
      final userIds = <String>{};
      for (var tx in transactionHistory) {
        if (tx['from_user_id'] != null) userIds.add(tx['from_user_id']);
        if (tx['to_user_id'] != null) userIds.add(tx['to_user_id']);
      }

      // Fetch all users in one query
      Map<String, String> userEmailMap = {};
      if (userIds.isNotEmpty) {
        try {
          final usersResponse = await SupabaseService.client
              .from('users')
              .select('id, email')
              .inFilter('id', userIds.toList());

          for (var user in usersResponse) {
            userEmailMap[user['id']] = user['email'];
          }
        } catch (e) {
          print('Error fetching user emails: $e');
        }
      }

      // Format transaction history for display
      final formattedTransactions = transactionHistory.map((tx) {
        final currentUserId = user.id;
        final isSent = tx['from_user_id'] == currentUserId;
        final isReceived = tx['to_user_id'] == currentUserId;

        String type = 'unknown';
        if (isSent) {
          type = 'send';
        } else if (isReceived) {
          type = 'receive';
        } else if (tx['transaction_type'] != null) {
          type = tx['transaction_type'].toString().replaceAll('_', '');
        }

        // Get recipient/sender email
        String? counterpartEmail;
        String description =
            tx['description'] ?? tx['transfer_reason'] ?? 'Transaction';

        if (isSent && tx['to_user_id'] != null) {
          counterpartEmail = userEmailMap[tx['to_user_id']];
          if (counterpartEmail != null) {
            description = 'To: $counterpartEmail';
          }
        } else if (isReceived && tx['from_user_id'] != null) {
          counterpartEmail = userEmailMap[tx['from_user_id']];
          if (counterpartEmail != null) {
            description = 'From: $counterpartEmail';
          }
        }

        // Safely convert numeric values to double
        double getAmount() {
          if (tx['pet_coins_amount'] != null) {
            return (tx['pet_coins_amount'] as num).toDouble();
          }
          if (tx['amount'] != null) {
            return (tx['amount'] as num).toDouble();
          }
          return 0.0;
        }

        return {
          'amount': getAmount(),
          'description': description,
          'type': type,
          'status': tx['status'] ?? 'unknown',
          'created_at': tx['created_at'],
          'transaction_id': tx['id'],
          'coin_type': tx['coin_type'], // Add coin type field
        };
      }).toList();

      return {
        'walletBalance': walletBalance,
        'currentPrice': currentPrice,
        'priceHistory': [], // Can be added later
        'recentTransactions': formattedTransactions,
        'coinBalances': balances,
        'coinPrices': prices,
      };
    } catch (e) {
      print('Error in _getCustomerDashboardData: $e');
      return {
        'walletBalance': 0.0,
        'currentPrice': 100.0,
        'priceHistory': [],
        'recentTransactions': [],
        'coinBalances': {'petNT': 0.0, 'petBNT': 0.0, 'petINDX': 0.0},
        'coinPrices': {'petNT': 90.0, 'petBNT': 1.0, 'petINDX': 0.5},
      };
    }
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  /// Format Pet Coins
  String _formatPetCoins(double amount) {
    return '${amount.toStringAsFixed(2)} PET';
  }

  /// Get transaction type display name
  String _getTransactionTypeDisplayName(String type) {
    switch (type) {
      case 'send':
        return 'Sent';
      case 'receive':
        return 'Received';
      case 'purchase':
        return 'Purchase';
      case 'refund':
        return 'Refund';
      default:
        return 'Transaction';
    }
  }

  /// Get transaction status display name
  String _getTransactionStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
      case 'approved':
        return 'Completed';
      case 'failed':
      case 'rejected':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  /// Format transaction time
  String _formatTransactionTime(String? dateTime) {
    if (dateTime == null) return 'Recently';

    try {
      final date = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[date.month - 1]} ${date.day}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  /// Show send payment dialog
  // ignore: unused_element
  void _showSendPaymentDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Send Payment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Recipient Email',
                        hintText: 'Enter recipient email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount (PET Coins)',
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Balance: ${_formatPetCoins(walletBalance)} 🪙',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final amount = double.tryParse(amountController.text);

                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter recipient email'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    if (amount > walletBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Insufficient balance'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    // Find user by email
                    final searchResult = await SearchService.searchUsers(email);

                    if (searchResult.users.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recipient not found'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      }
                      return;
                    }

                    final recipient = searchResult.users.first;

                    // Create pending transfer transaction (requires admin approval)
                    final result = await TransferService.createPendingTransfer(
                      fromUserId: currentUser!.id,
                      toUserId: recipient.id,
                      petCoinsAmount: amount,
                      description: 'Transfer to ${recipient.email}',
                    );

                    if (result.success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Transfer request sent! ${_formatPetCoins(amount)} 🪙 pending admin approval',
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                      // Reload data
                      loadUserData();
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Transfer failed: ${result.error}'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show transaction history
  void _showTransactionHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: recentTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📭', style: const TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: recentTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = recentTransactions[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getTransactionColor(
                                      transaction['type'],
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getTransactionIcon(transaction['type']),
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: _getTransactionColor(
                                          transaction['type'],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTransactionTypeDisplayName(
                                          transaction['type'],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        transaction['description'] ??
                                            'No description',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_formatPetCoins(transaction['amount'])} 🪙',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _getTransactionColor(
                                          transaction['type'],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (transaction['coin_type'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getCoinTypeColor(
                                            transaction['coin_type'],
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _getCoinTypeDisplayName(
                                            transaction['coin_type'],
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _getCoinTypeColor(
                                              transaction['coin_type'],
                                            ),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getTransactionColor(
                                          transaction['type'],
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getTransactionStatusDisplayName(
                                          transaction['status'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _getTransactionColor(
                                            transaction['type'],
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get coin type color
  Color _getCoinTypeColor(String? coinType) {
    switch (coinType?.toLowerCase()) {
      case 'petnt':
        return const Color(0xFF3B82F6); // Blue
      case 'petbnt':
        return const Color(0xFF10B981); // Green
      case 'petindx':
        return const Color(0xFFF59E0B); // Yellow/Orange
      default:
        return Colors.grey;
    }
  }

  /// Get coin type display name
  String _getCoinTypeDisplayName(String? coinType) {
    switch (coinType?.toLowerCase()) {
      case 'petnt':
        return 'PET NT';
      case 'petbnt':
        return 'PET BNT';
      case 'petindx':
        return 'PET INDX';
      default:
        return 'PET';
    }
  }
}
