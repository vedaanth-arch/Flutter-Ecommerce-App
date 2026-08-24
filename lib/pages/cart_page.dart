/*
 * ============================================================
 * CART PAGE — Shopping Cart UI
 * ============================================================
 *
 * WHAT THIS PAGE SHOWS:
 * 1. List of all items in the cart (product name, price, quantity)
 * 2. +/- buttons to change quantity
 * 3. Delete button to remove items
 * 4. Total price at the bottom
 * 5. "Checkout" button to place the order
 *
 * DATA FLOW:
 * ┌──────────────────────────────────────────────────────────┐
 * │ Page loads                                               │
 * │     ↓                                                    │
 * │ CartService.getCart() → Django returns cart JSON          │
 * │     ↓                                                    │
 * │ Display items in a ListView                              │
 * │     ↓                                                    │
 * │ User taps +/- → CartService.updateCartItem()             │
 * │     ↓                                                    │
 * │ Cart refreshes with new quantities/totals                │
 * │     ↓                                                    │
 * │ User taps "Checkout" → CartService.checkout()            │
 * │     ↓                                                    │
 * │ Order placed → show confirmation → navigate away         │
 * └──────────────────────────────────────────────────────────┘
 */

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/cart_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // ============================================================
  // STATE
  // ============================================================
  Map<String, dynamic>? _cart;       // the cart data from Django
  bool _isLoading = true;            // show spinner while loading
  String? _error;                    // error message if something fails

  @override
  void initState() {
    super.initState();
    _loadCart();  // fetch cart when page loads
  }

  // ============================================================
  // LOAD CART
  // ============================================================
  // Calls Django's GET /api/cart/ endpoint.
  // Django returns: {id, total_price, total_items, items: [...]}

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cart = await CartService.getCart();

    if (mounted) {
      setState(() {
        _cart = cart;
        _isLoading = false;
        if (cart == null) {
          _error = 'Failed to load cart';
        }
      });
    }
  }

  // ============================================================
  // UPDATE QUANTITY
  // ============================================================
  // Called when user taps + or - buttons.
  // Sends PUT /api/cart/item/<id>/ to Django.
  // Django updates the quantity and returns the updated cart.

  Future<void> _updateQuantity(int itemId, int newQuantity) async {
    final updatedCart = await CartService.updateCartItem(
      itemId: itemId,
      quantity: newQuantity,
    );

    if (mounted && updatedCart != null) {
      setState(() {
        _cart = updatedCart;
      });
    }
  }

  // ============================================================
  // REMOVE ITEM
  // ============================================================
  // Called when user taps the delete button.
  // Sends DELETE /api/cart/item/<id>/ to Django.

  Future<void> _removeItem(int itemId) async {
    final updatedCart = await CartService.removeCartItem(itemId: itemId);

    if (mounted && updatedCart != null) {
      setState(() {
        _cart = updatedCart;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed from cart')),
      );
    }
  }

  // ============================================================
  // CHECKOUT
  // ============================================================
  // Called when user taps "Checkout".
  // Sends POST /api/orders/checkout/ to Django.
  // Django creates Order, clears cart, returns Order.

  Future<void> _checkout() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final order = await CartService.checkout(
      address: 'Default Address',  // In real app, let user enter address
    );

    if (!mounted) return;
    Navigator.pop(context);  // close loading dialog

    if (order != null) {
      // Success! Show order confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Placed! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: #${order['id']}'),
              Text('Total: \$${order['total_price']}'),
              Text('Status: ${order['status_display']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);  // close dialog
                Navigator.pop(context);  // go back to home
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Refresh cart (should be empty now)
      _loadCart();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout failed. Please try again.')),
      );
    }
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // LOADING
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ERROR
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCart,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // EMPTY CART
    final items = _cart?['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // CART ITEMS
    return Column(
      children: [
        // ITEMS LIST (scrollable)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildCartItem(item);
            },
          ),
        ),

        // CHECKOUT BAR (fixed at bottom)
        _buildCheckoutBar(),
      ],
    );
  }

  // ============================================================
  // BUILD A SINGLE CART ITEM
  // ============================================================
  // Each item shows: product name, price, quantity controls, delete

  Widget _buildCartItem(Map<String, dynamic> item) {
    final itemName = item['product_name'] ?? 'Unknown';
    final itemPrice = double.parse(item['product_price'] ?? '0');
    final quantity = item['quantity'] ?? 1;
    final subtotal = double.parse(item['subtotal'] ?? '0');
    final itemId = item['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // PRODUCT INFO (left side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${itemPrice.toStringAsFixed(2)} each',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal: \$${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // QUANTITY CONTROLS (right side)
            Column(
              children: [
                // + button
                IconButton(
                  onPressed: () {
                    _updateQuantity(itemId, quantity + 1);
                  },
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),

                // Quantity number
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // - button (deletes if quantity becomes 0)
                IconButton(
                  onPressed: () {
                    if (quantity <= 1) {
                      _removeItem(itemId);
                    } else {
                      _updateQuantity(itemId, quantity - 1);
                    }
                  },
                  icon: Icon(
                    quantity <= 1
                        ? Icons.delete
                        : Icons.remove_circle,
                    color: quantity <= 1 ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CHECKOUT BAR — Total + Checkout Button
  // ============================================================

  Widget _buildCheckoutBar() {
    final totalPrice = _cart?['total_price'] ?? '0.00';
    final totalItems = _cart?['total_items'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ($totalItems items):',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '\$$totalPrice',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Checkout',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
