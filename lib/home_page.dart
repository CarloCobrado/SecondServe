import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secondserve/food_products_model.dart';
import 'package:secondserve/food_api_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FoodApiService _apiService = FoodApiService();
  
  // Step 2: JSON Array to Product Mapping state
  List<Datum> allProducts = [];
  FoodProducts? foodProducts;
  bool isDataLoaded = false;
  bool isLoading = false;
  String errorMessage = '';

  // Step 4: Search View Filtering state (10 pts)
  List<Datum> filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-role state: Consumer, Organization, Business
  String _localRole = 'Consumer';

  /// Step 1: HTTP GET Request Execution (20 pts)
  /// Executes an asynchronous HTTP GET request using package:http,
  /// verifies status code 200 OK, and handles network exceptions.
  Future<String> fetchRawJson() async {
    return await _apiService.fetchProductsJsonWithFallback();
  }

  /// Step 4: Search View Filtering (10 pts)
  /// Filters products in real-time across name, category, and location.
  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        filteredProducts = List.from(allProducts);
      } else {
        final lowerQuery = _searchQuery.toLowerCase();
        filteredProducts = allProducts.where((product) {
          final nameMatch = product.name.toLowerCase().contains(lowerQuery);
          final categoryMatch = product.category.toLowerCase().contains(lowerQuery);
          final locationMatch = product.location.toLowerCase().contains(lowerQuery);
          return nameMatch || categoryMatch || locationMatch;
        }).toList();
      }
    });
  }

  /// Step 2: JSON Array to Product Mapping (20 pts)
  /// Converts the raw JSON string into a strongly-typed `List<Datum>`
  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // 1. HTTP GET Execution
      final rawJson = await fetchRawJson();

      // 2. JSON Array to Product Mapping
      final List<Datum> mappedProducts = parseProductsFromJson(rawJson);

      setState(() {
        allProducts = mappedProducts;
        foodProducts = FoodProducts(products: mappedProducts);
        _filterProducts(_searchQuery);
        isDataLoaded = true;
        isLoading = false;
      });

      debugPrint(
        '[HomePage] Successfully mapped ${mappedProducts.length} surplus food products from JSON array.',
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isDataLoaded = false;
        isLoading = false;
      });
      debugPrint('[HomePage] Error mapping products: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _localRole = user.displayName!;
    }
    loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;

  void _switchRole(String newRole) async {
    setState(() => _localRole = newRole);
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newRole);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newRole == 'Business'
                    ? Icons.storefront
                    : (newRole == 'Organization' ? Icons.volunteer_activism : Icons.person),
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text('Switched to $newRole mode'),
            ],
          ),
          backgroundColor: const Color(0xFF7081FF),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRoleSwitcherDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Select Active Role',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRoleTile('Consumer', Icons.person_outline, 'Reserve discounted surplus meals'),
              const Divider(),
              _buildRoleTile('Organization', Icons.volunteer_activism_outlined, 'Claim bulk meals for charity/NGO'),
              const Divider(),
              _buildRoleTile('Business', Icons.storefront_outlined, 'List surplus food from your store'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleTile(String role, IconData icon, String subtitle) {
    final isSelected = _localRole == role;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF7081FF) : Colors.grey[700]),
      title: Text(
        role,
        style: GoogleFonts.poppins(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF7081FF) : Colors.black87,
        ),
      ),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF7081FF)) : null,
      onTap: () {
        Navigator.pop(context);
        _switchRole(role);
      },
    );
  }

  void _handleCardAction(Datum product) {
    if (_localRole == 'Business') {
      _showBusinessManageDialog(product);
    } else if (_localRole == 'Organization') {
      _showBulkClaimDialog(product);
    } else {
      _showOrderDialog(product.name, product.location);
    }
  }

  void _showBulkClaimDialog(Datum product) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.volunteer_activism, color: Color(0xFF7081FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulk Claim Reserved',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All available servings of "${product.name}" have been reserved for community redistribution.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup: ${product.location}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Quantity: ${product.availableServings}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('Organization verification code: #SS-NGO-8821', style: TextStyle(fontSize: 11, color: Colors.deepPurple)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7081FF)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Confirm Claim'),
            ),
          ],
        );
      },
    );
  }

  void _showBusinessManageDialog(Datum product) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Manage Listing', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'Listing for "${product.name}" (${product.price}, ${product.availableServings}) is currently active for consumers and organizations.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7081FF)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Listing for ${product.name} updated!'),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Update Status'),
            ),
          ],
        );
      },
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Bakery');
    final priceCtrl = TextEditingController(text: '₱40');
    final servingsCtrl = TextEditingController(text: '5 servings');
    final locationCtrl = TextEditingController(text: 'My Bakery, Quezon City');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_business, color: Color(0xFF7081FF)),
              const SizedBox(width: 8),
              Text('Add Surplus Listing', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Food Name', hintText: 'e.g. Sourdough Loaf'),
                ),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'Bakery, Meals, Produce'),
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Surplus Price', hintText: 'e.g. ₱40'),
                ),
                TextField(
                  controller: servingsCtrl,
                  decoration: const InputDecoration(labelText: 'Available Servings', hintText: 'e.g. 5 servings'),
                ),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Pickup Location'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7081FF)),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final newProduct = Datum(
                  id: DateTime.now().millisecondsSinceEpoch % 100000,
                  name: name,
                  category: catCtrl.text.trim().isEmpty ? 'Bakery' : catCtrl.text.trim(),
                  location: locationCtrl.text.trim().isEmpty ? 'SecondServe Partner' : locationCtrl.text.trim(),
                  price: priceCtrl.text.trim().isEmpty ? '₱50' : priceCtrl.text.trim(),
                  availableServings: servingsCtrl.text.trim().isEmpty ? '1 serving' : servingsCtrl.text.trim(),
                  imageUrl: 'assets/icons/TempLogo.jpg',
                );
                setState(() {
                  allProducts.insert(0, newProduct);
                  _filterProducts(_searchQuery);
                });
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully listed "$name" on SecondServe!'),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Publish Listing'),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDialog(String foodName, String location) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Order placed'),
          content: Text(
            '$foodName is reserved for pickup at $location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _productListingCard(Datum product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              product.isAssetImage
                  ? Image.asset(
                      product.imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.fastfood, size: 48, color: Colors.grey),
                        ),
                      ),
                    )
                  : Image.network(
                      product.imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.fastfood, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7081FF).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.category,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.price,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.availableServings,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7081FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _handleCardAction(product),
                    icon: Icon(
                      _localRole == 'Business'
                          ? Icons.storefront
                          : (_localRole == 'Organization'
                              ? Icons.volunteer_activism
                              : Icons.shopping_bag_outlined),
                      size: 18,
                    ),
                    label: Text(
                      _localRole == 'Business'
                          ? 'Manage Surplus Listing'
                          : (_localRole == 'Organization'
                              ? 'Claim Bulk for Community'
                              : 'Reserve Surplus Food'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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

  /// Step 3: Dynamic Product ListView Presentation (15 pts) & Step 4: Search View Filtering (10 pts)
  /// Displays products dynamically using ListView.builder, handling loading, error, empty, and search states.
  Widget _buildListingsView() {
    if (isLoading && allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF7081FF)),
            const SizedBox(height: 16),
            Text(
              'Loading surplus food listings...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty && allProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 14),
              Text(
                'Failed to load listings',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: loadProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7081FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (allProducts.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadProducts,
        color: const Color(0xFF7081FF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'No surplus food listed currently.',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Search Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Food Listings',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isEmpty
                    ? '${allProducts.length} surplus meals available for rescue'
                    : 'Showing ${filteredProducts.length} of ${allProducts.length} meals matching "$_searchQuery"',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // Step 4: Search View Filtering (10 pts)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterProducts,
                  decoration: InputDecoration(
                    hintText: 'Search food, category, or location...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7081FF)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _filterProducts('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dynamic Product ListView or Search Empty State
        Expanded(
          child: filteredProducts.isEmpty && _searchQuery.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No results found for "$_searchQuery"',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try searching with a different keyword or location',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            _filterProducts('');
                          },
                          icon: const Icon(Icons.clear, color: Color(0xFF7081FF)),
                          label: Text(
                            'Clear search',
                            style: GoogleFonts.poppins(color: const Color(0xFF7081FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadProducts,
                  color: const Color(0xFF7081FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _productListingCard(product),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 246, 225),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'SecondServe',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showRoleSwitcherDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white38),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _localRole,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7081FF),
        foregroundColor: Colors.white,
        elevation: 0,
        
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              showDialog( 
                context: context, builder: (context) {
                  return AlertDialog(
                    title: const Text('Notifications'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No new notifications.'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Settings'),
                    content: const Text(
                      'Account and application settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),

      floatingActionButton: _localRole == 'Business' && _selectedIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7081FF),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text('Add Listing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onPressed: _showAddProductDialog,
            )
          : null,

      drawer: Drawer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color:  Color(0xFF7081FF),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [

                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/icons/TempLogo.jpg',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SecondServe',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        'Serve. Share. Sustain.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Role: $_localRole',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.switch_account_outlined, color: Color(0xFF7081FF)),
              title: Text(
                'Switch Role',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Current: $_localRole', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showRoleSwitcherDialog();
              },
            ),

            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(
                'Dashboard',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);

                setState(() {
                  _selectedIndex = 0;
                });
              },
            ),

            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(
                'Available Food',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);

                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long_outlined,),
              title: Text(
                'My Claims',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);

                setState(() {
                  _selectedIndex = 2;
                });
              },
            ),

            ListTile(
              leading: const Icon(Icons.payments_outlined,),
              title: Text(
                'Transactions',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                'Profile',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: Text(
                'My Impact',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(
                'Help & Support',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
      
        bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Listings',
          ),

          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Claims',
          ),

          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),

      body: <Widget>[
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Welcome, ${user?.email ?? 'User'}!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7081FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _localRole == 'Business'
                              ? Icons.storefront
                              : (_localRole == 'Organization' ? Icons.volunteer_activism : Icons.person),
                          size: 14,
                          color: const Color(0xFF7081FF),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Active Role: $_localRole',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7081FF),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _localRole == 'Business'
                        ? 'Turn your surplus inventory into shared value.'
                        : (_localRole == 'Organization'
                            ? 'Rescue bulk meals for community food distribution.'
                            : 'Rescue surplus. Share more. Waste less.'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.restaurant,
                                size: 34,
                                color: Color(0xFF7081FF),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                allProducts.isNotEmpty ? allProducts.length.toString() : (isLoading ? '...' : '0'),
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Available Food',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _localRole == 'Business'
                                    ? Icons.storefront
                                    : (_localRole == 'Organization' ? Icons.volunteer_activism : Icons.fastfood),
                                size: 34,
                                color: const Color(0xFF7081FF),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _localRole == 'Business'
                                    ? '${allProducts.length}'
                                    : (_localRole == 'Organization' ? '120' : '24'),
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _localRole == 'Business'
                                    ? 'Active Offers'
                                    : (_localRole == 'Organization' ? 'Meals Given' : 'Meals Rescued'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        _buildListingsView(),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'My Claims',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'No active claims yet.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.map,
                size: 60,
                color: Colors.deepPurple,
              ),

              const SizedBox(height: 15),

              Text(
                'Map',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Nearby food locations will appear here.',
              ),
            ],
          ),
        ),
      ][_selectedIndex],
    );
  }
}
