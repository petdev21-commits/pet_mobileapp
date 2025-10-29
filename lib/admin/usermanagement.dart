import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_management_service.dart';
import '../services/search_service.dart';
import '../models/user.dart';
import '../signin.dart';

class UserManagementPage extends StatefulWidget {
  final String? initialSearchQuery;

  const UserManagementPage({super.key, this.initialSearchQuery});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  User? currentUser;
  bool isLoading = true;
  bool dropdownOpen = false;
  List<Map<String, dynamic>> users = [];
  int totalUsers = 0;
  int customerCount = 0;
  int partnerCount = 0;

  // Search functionality
  String searchQuery = '';
  List<SearchResult> searchResults = [];
  List<SearchResult> suggestions = [];
  bool searchLoading = false;
  bool showSearchResults = false;
  bool showSuggestions = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadUsers();

    // If there's an initial search query, perform the search
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      handleSearch(widget.initialSearchQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> loadUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('Loading users...');
      final result = await UserManagementService.getAllUsers();
      print(
        'Users result: ${result.users.length} users, error: ${result.error}',
      );

      if (result.error != null) {
        print('Error loading users: ${result.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${result.error}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get user statistics
      print('Loading user statistics...');
      final stats = await UserManagementService.getUserStatistics();
      print(
        'Stats: total=${stats.totalUsers}, customers=${stats.customerCount}, partners=${stats.partnerCount}',
      );

      setState(() {
        users = result.users;
        totalUsers = stats.totalUsers;
        customerCount = stats.customerCount;
        partnerCount = stats.partnerCount;
        isLoading = false;
      });

      print('State updated: ${users.length} users loaded');
      print(
        'Statistics updated: total=$totalUsers, customers=$customerCount, partners=$partnerCount',
      );

      // If no users found, show a message
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No users found in database. Try adding a new user.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleSearch(String query) async {
    setState(() {
      searchQuery = query;
    });

    // Clear results immediately when query is empty
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        showSearchResults = false;
        suggestions = [];
        showSuggestions = false;
      });
      return;
    }

    // Fetch suggestions while typing
    if (query.length >= 2) {
      await fetchSuggestions(query);
    }

    // Debounce search by 300ms
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (searchQuery == query) {
        // Only proceed if query hasn't changed
        setState(() {
          searchLoading = true;
        });

        try {
          final result = await SearchService.searchUsers(query);
          if (result.error != null) {
            print('Search error: ${result.error}');
            setState(() {
              searchResults = [];
              showSearchResults = true;
            });
          } else {
            setState(() {
              searchResults = result.users;
              showSearchResults = true;
            });
          }
        } catch (e) {
          print('Search error: $e');
          setState(() {
            searchResults = [];
            showSearchResults = true;
          });
        } finally {
          setState(() {
            searchLoading = false;
          });
        }
      }
    });
  }

  Future<void> fetchSuggestions(String query) async {
    try {
      final result = await SearchService.searchUsers(query);
      if (result.error == null && result.users.isNotEmpty) {
        setState(() {
          suggestions = result.users.take(5).toList(); // Limit to 5 suggestions
          showSuggestions = true;
        });
      }
    } catch (e) {
      print('Suggestion error: $e');
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
    handleSearch(suggestion.email);
  }

  Future<void> handleRoleFilter(String role) async {
    setState(() {
      searchLoading = true;
      searchQuery = '';
      _searchController.clear();
    });

    try {
      final result = await SearchService.searchByRole(role);
      if (result.error != null) {
        print('Role filter error: ${result.error}');
        setState(() {
          searchResults = [];
          showSearchResults = true;
        });
      } else {
        setState(() {
          searchResults = result.users;
          showSearchResults = true;
        });
      }
    } catch (e) {
      print('Role filter error: $e');
      setState(() {
        searchResults = [];
        showSearchResults = true;
      });
    } finally {
      setState(() {
        searchLoading = false;
      });
    }
  }

  void clearSearchResults() {
    setState(() {
      searchQuery = '';
      _searchController.clear();
      searchResults = [];
      showSearchResults = false;
      suggestions = [];
      showSuggestions = false;
    });
  }

  Future<void> _showChangeRoleDialog(
    Map<String, dynamic> user,
    String currentRole,
  ) async {
    // Default to franchise if current role is not one of the allowed roles
    final allowedRoles = ['franchise', 'sub-franchise', 'channel_partner'];
    String selectedRole = allowedRoles.contains(currentRole)
        ? currentRole
        : 'franchise';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Change User Role'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['email'] ?? 'No email',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Role: ${UserManagementService.formatRole(currentRole)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Role selector
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Select New Role',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'franchise',
                      child: Text('Franchise'),
                    ),
                    DropdownMenuItem(
                      value: 'sub-franchise',
                      child: Text('Sub-Franchise'),
                    ),
                    DropdownMenuItem(
                      value: 'channel_partner',
                      child: Text('Channel Partner'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRole = value ?? currentRole;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRole != currentRole) {
                  await _handleRoleChange(
                    user['id'],
                    user['email'],
                    selectedRole,
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRoleChange(
    String userId,
    String userEmail,
    String newRole,
  ) async {
    try {
      setState(() {
        isLoading = true;
      });

      print('Updating role for email: $userEmail to $newRole');

      // Update user role by email
      final result = await UserManagementService.updateUserRoleByEmail(
        userEmail,
        newRole,
      );

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Role updated for $userEmail to ${UserManagementService.formatRole(newRole)}!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        // Refresh users list
        await loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: ${result.error}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildSearchResultsCard() {
    return Container(
      width: double.infinity,
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
        children: [
          // Results Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${searchResults.length} user${searchResults.length != 1 ? 's' : ''} found',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: clearSearchResults,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Clear Results',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: searchResults.isEmpty
                ? _buildEmptySearchResults()
                : _buildSearchResultsList(),
          ),
        ],
      ),
    );
  }

  Future<void> handleSignOut() async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                  'User Management',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  'Add and manage users',
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
                          // Summary Cards Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.people,
                                  title: 'Total',
                                  count: totalUsers,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.person,
                                  title: 'Customers',
                                  count: customerCount,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.handshake,
                                  title: 'Partners',
                                  count: partnerCount,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Debug Info
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  'Total: $totalUsers',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Customers: $customerCount',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Partners: $partnerCount',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Users: ${users.length}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Search Users Card
                          _buildSearchUsersCard(),
                          const SizedBox(height: 16),

                          // Conditional Content: Show search results OR all users
                          if (showSearchResults)
                            _buildSearchResultsCard()
                          else
                            _buildAllUsersCard(),
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

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    print('Building summary card: $title = $count');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllUsersCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalUsers users in the system',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        print('Testing Supabase connection...');
                        try {
                          final result =
                              await UserManagementService.getAllUsers();
                          final stats =
                              await UserManagementService.getUserStatistics();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Supabase Test: ${result.users.length} users, Stats: ${stats.totalUsers} total',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Supabase Error: $e'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.bug_report,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: loadUsers,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: const Color(0xFFE5E7EB)),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading ? _buildLoadingState() : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading users...',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    print('Building users list: ${users.length} users');

    if (users.isEmpty) {
      return Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here when they register',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: loadUsers,
                child: const Text('Refresh'),
              ),
              ElevatedButton(
                onPressed: () async {
                  print('Testing service directly...');
                  try {
                    final result = await UserManagementService.getAllUsers();
                    print(
                      'Direct service test: ${result.users.length} users, error: ${result.error}',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Service test: ${result.users.length} users found',
                        ),
                        backgroundColor: result.error != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    );
                  } catch (e) {
                    print('Service test error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Service test error: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
                child: const Text('Test Service'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: users.map((user) {
        print(
          'Building user item: ${user['name'] ?? 'No name'} (${user['email'] ?? 'No email'})',
        );
        return _buildUserItem(user);
      }).toList(),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final role = user['role'] ?? 'customer';
    final name = user['name'] ?? 'Unknown User';
    final email = user['email'] ?? 'No email';

    print('Building user item for: $name ($email) - Role: $role');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // User Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _getRoleColors(role)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Role Badge (now clickable)
          GestureDetector(
            onTap: () => _showChangeRoleDialog(user, role),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColors(role)[0].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRoleColors(role)[0].withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      UserManagementService.formatRole(role),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColors(role)[0],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 12, color: _getRoleColors(role)[0]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRoleColors(String role) {
    return UserManagementService.getRoleColors(role);
  }

  Widget _buildSearchUsersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Users',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Find and filter users by role or email',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Role Filter Buttons - 2x2 Grid
          _buildRoleFilterButtons(),
          const SizedBox(height: 24),

          // Search Bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildRoleFilterButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Role',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                icon: '👤',
                label: 'Customers',
                color: const Color(0xFF3B82F6),
                onTap: () => handleRoleFilter('customer'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRoleButton(
                icon: '🏢',
                label: 'Franchise',
                color: const Color(0xFF10B981),
                onTap: () => handleRoleFilter('franchise'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                icon: '🏪',
                label: 'Sub-Franchise',
                color: const Color(0xFF8B5CF6),
                onTap: () => handleRoleFilter('sub-franchise'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRoleButton(
                icon: '🤝',
                label: 'Channel Partners',
                color: const Color(0xFFF59E0B),
                onTap: () => handleRoleFilter('channel_partner'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleButton({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Users',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            TextField(
              controller: _searchController,
              onChanged: handleSearch,
              onTap: () {
                if (suggestions.isNotEmpty) {
                  setState(() {
                    showSuggestions = true;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by email or role...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                suffixIcon: searchLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      )
                    : null,
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
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            // Suggestions Dropdown
            if (showSuggestions && suggestions.isNotEmpty)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                                      colors: SearchService.getRoleColors(
                                        suggestion.role,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      suggestion.email
                                          .substring(0, 1)
                                          .toUpperCase(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        SearchService.formatRole(
                                          suggestion.role,
                                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SearchService.getRoleColors(
                                      suggestion.role,
                                    )[0].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    SearchService.formatRole(suggestion.role),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: SearchService.getRoleColors(
                                        suggestion.role,
                                      )[0],
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
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptySearchResults() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Text('🔍', style: TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No users found',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Try a different search term',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    return Column(
      children: searchResults
          .map((result) => _buildSearchResultItem(result))
          .toList(),
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: SearchService.getRoleColors(result.role),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    result.email.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          SearchService.formatRole(result.role),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SearchService.getRoleColors(
                              result.role,
                            )[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SearchService.getRoleColors(
                                result.role,
                              )[0].withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            SearchService.formatRole(result.role),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: SearchService.getRoleColors(
                                result.role,
                              )[0],
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
          const SizedBox(height: 12),

          // Member since info
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Member since ${SearchService.formatDate(result.createdAt)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // View User Details Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('View details for ${result.email}'),
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'View User Details',
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
    );
  }
}
