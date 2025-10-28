import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/pet_coin_value_service.dart';
import '../services/coin_types_service.dart';
import '../models/user.dart';
import '../signin.dart';

class CoinValuePage extends StatefulWidget {
  const CoinValuePage({super.key});

  @override
  State<CoinValuePage> createState() => _CoinValuePageState();
}

class _CoinValuePageState extends State<CoinValuePage> {
  User? currentUser;
  bool isLoading = true;
  bool dropdownOpen = false;
  bool isUpdating = false;
  PetCoinValue? currentValue;
  final TextEditingController _newValueController = TextEditingController();
  List<PetCoinValue> valueHistory = [];

  // Multi-coin state
  List<Map<String, dynamic>> coinTypes = [];
  String selectedCoinType = 'petNT';
  Map<String, double> coinPrices = {
    'petNT': 90.00,
    'petBNT': 1.00,
    'petINDX': 0.50,
  };
  Map<String, TextEditingController> priceControllers = {};

  @override
  void initState() {
    super.initState();
    loadUserData();
    _initializeControllers();
    loadCoinTypes();
    loadCurrentValue(); // Keep for backwards compatibility
    loadValueHistory();
  }

  void _initializeControllers() {
    priceControllers['petNT'] = TextEditingController(text: '90.00');
    priceControllers['petBNT'] = TextEditingController(text: '1.00');
    priceControllers['petINDX'] = TextEditingController(text: '0.50');
  }

  @override
  void dispose() {
    _newValueController.dispose();
    priceControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> loadCoinTypes() async {
    try {
      final coins = await CoinTypesService.getActiveCoinTypes();
      setState(() {
        coinTypes = coins;
        for (var coin in coins) {
          final typeName = coin['type_name'] as String;
          final price = (coin['current_price_rupees'] as num).toDouble();
          coinPrices[typeName] = price;
          if (priceControllers[typeName] != null) {
            priceControllers[typeName]!.text = price.toString();
          }
        }
      });
    } catch (e) {
      print('Error loading coin types: $e');
    }
  }

  Future<void> updateCoinPrice(String coinType) async {
    final controller = priceControllers[coinType];
    if (controller == null) return;

    final newValue = double.tryParse(controller.text);
    if (newValue == null || newValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive number'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (currentUser == null) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final result = await CoinTypesService.updateCoinPrice(
        coinType,
        newValue,
        currentUser!.id,
      );
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$coinType price updated to ₹${newValue.toStringAsFixed(2)}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() {
          coinPrices[coinType] = newValue;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating coin price'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
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

  Future<void> loadCurrentValue() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Set default value immediately to prevent loading state
      setState(() {
        currentValue = PetCoinValue(
          id: 'default',
          coinValueRupees: 1.00,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _newValueController.text = '1.00';
        isLoading = false;
      });

      // Then try to fetch real value
      final result = await PetCoinValueService.getCurrentValue();
      if (result.value != null) {
        setState(() {
          currentValue = result.value;
          _newValueController.text = result.value!.coinValueRupees.toString();
        });
      }
    } catch (e) {
      print('Error loading current value: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadValueHistory() async {
    try {
      final result = await PetCoinValueService.getValueHistory();
      setState(() {
        valueHistory = result.values;
      });
    } catch (e) {
      print('Error loading value history: $e');
    }
  }

  Future<void> handleSignOut() async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInPage()),
    );
  }

  Future<void> updatePetCoinValue() async {
    final newValue = double.tryParse(_newValueController.text);
    if (newValue == null || newValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive number'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (currentUser == null) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final result = await PetCoinValueService.updateValue(
        newValue,
        currentUser!.id,
      );
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PET Coin value updated to ${PetCoinValueService.formatCurrency(newValue)}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await loadCurrentValue();
        await loadValueHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating value: ${result.error}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating value: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        isUpdating = false;
      });
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
                'Loading...',
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
                                  'PET Coin Value',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  'Set exchange rate',
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
                          // Multi-Coin Value Cards
                          _buildMultiCoinValueCards(),
                          const SizedBox(height: 24),

                          // Value History Card (keep for now for backwards compatibility)
                          _buildValueHistoryCard(),
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

  Widget _buildMultiCoinValueCards() {
    final colors = {
      'petNT': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      'petBNT': [const Color(0xFF10B981), const Color(0xFF059669)],
      'petINDX': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    };

    final icons = {'petNT': '🔵', 'petBNT': '🟢', 'petINDX': '🟡'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Coin Values',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set exchange rates for all coin types',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        ...coinPrices.entries.map((entry) {
          final coinType = entry.key;
          final price = entry.value;
          final color = colors[coinType] ?? [Colors.grey, Colors.grey[600]!];
          final icon = icons[coinType] ?? '🪙';
          final controller = priceControllers[coinType]!;

          return _buildSingleCoinCard(
            coinType,
            price,
            color[0],
            color[1],
            icon,
            controller,
          );
        }),
      ],
    );
  }

  Widget _buildSingleCoinCard(
    String coinType,
    double currentPrice,
    Color primaryColor,
    Color secondaryColor,
    String icon,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coinType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Current Rate',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Input Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Price (₹)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter new price',
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
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
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUpdating
                        ? null
                        : () => updateCoinPrice(coinType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isUpdating
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
                                'Updating...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.update, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Update Price',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildValueHistoryCard() {
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Value History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recent changes to PET coin value',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    loadCurrentValue();
                    loadValueHistory();
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
            padding: const EdgeInsets.all(16),
            child: valueHistory.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Center(
                            child: Text('📊', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Value changes will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: valueHistory.asMap().entries.map((entry) {
                      final index = entry.key;
                      final historyItem = entry.value;
                      final isActive = historyItem.isActive;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        PetCoinValueService.formatCurrency(
                                          historyItem.coinValueRupees,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    PetCoinValueService.formatDateTime(
                                      historyItem.updatedAt,
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
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Updated by admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
