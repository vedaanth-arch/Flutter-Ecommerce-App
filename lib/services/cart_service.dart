/*
 * ============================================================
 * CART SERVICE — Flutter side of Shopping Cart
 * ============================================================
 *
 * WHAT THIS FILE DOES:
 * This is the bridge between Flutter and Django's cart API.
 * It handles:
 *   1. Fetching the user's cart (with all items)
 *   2. Adding products to the cart
 *   3. Updating item quantities
 *   4. Removing items from the cart
 *   5. Placing orders (checkout)
 *   6. Viewing order history
 *
 * HOW THE CART FLOW WORKS IN FLUTTER:
 * ┌─────────────────────────────────────────────────────────┐
 * │ 1. User browses products on HomePage                    │
 * │ 2. Taps "Add to Cart" button on a product               │
 * │ 3. Flutter calls CartService.addToCart(productId)        │
 * │ 4. CartService sends POST /api/cart/add/ to Django       │
 * │    with Authorization: Bearer <access_token> header      │
 * │ 5. Django adds the item, returns updated cart            │
 * │ 6. Flutter updates the cart badge count in the UI        │
 * │ 7. User goes to Cart page to see all items               │
 * │ 8. Taps "Checkout" → Flutter calls checkout()            │
 * │ 9. Django creates Order, clears cart, returns Order      │
 * │ 10. Flutter shows order confirmation                     │
 * └─────────────────────────────────────────────────────────┘
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/services/auth_service.dart';

class CartService {
  // All cart endpoints start from this URL
  static const String baseUrl =
      'https://flutter-ecommerce-app-production.up.railway.app/api/';

  // ============================================================
  // GET CART
  // ============================================================
  // Fetches the current user's cart with all items.
  //
  // Flutter sends: GET /api/cart/
  //                Header: Authorization: Bearer <access_token>
  //
  // Django returns:
  // {
  //   "id": 1,
  //   "total_price": "45.00",
  //   "total_items": 3,
  //   "items": [
  //     {"id": 1, "product": 5, "product_name": "Shoes", "quantity": 2, "subtotal": "20.00"},
  //     {"id": 2, "product": 8, "product_name": "Hat", "quantity": 1, "subtotal": "25.00"}
  //   ]
  // }

  static Future<Map<String, dynamic>?> getCart() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.get(
        Uri.parse('${baseUrl}cart/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired — try refreshing
        final refreshed = await AuthService.refreshAccessToken();
        if (refreshed) {
          final newHeaders = await AuthService.authHeaders();
          final retryResponse = await http.get(
            Uri.parse('${baseUrl}cart/'),
            headers: newHeaders,
          );
          if (retryResponse.statusCode == 200) {
            return jsonDecode(retryResponse.body);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // ADD TO CART
  // ============================================================
  // Adds a product to the cart (or increases quantity if already there).
  //
  // Flutter sends: POST /api/cart/add/
  //                Body: {"product": 5, "quantity": 1}
  //
  // Django returns: updated cart JSON
  //
  // After this call, the cart badge count should be updated.

  static Future<Map<String, dynamic>?> addToCart({
    required int productId,
    int quantity = 1,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.post(
        Uri.parse('${baseUrl}cart/add/'),
        headers: headers,
        body: jsonEncode({
          'product': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshAccessToken();
        if (refreshed) {
          final newHeaders = await AuthService.authHeaders();
          final retryResponse = await http.post(
            Uri.parse('${baseUrl}cart/add/'),
            headers: newHeaders,
            body: jsonEncode({
              'product': productId,
              'quantity': quantity,
            }),
          );
          if (retryResponse.statusCode == 200) {
            return jsonDecode(retryResponse.body);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // UPDATE CART ITEM QUANTITY
  // ============================================================
  // Changes the quantity of a specific cart item.
  //
  // Flutter sends: PUT /api/cart/item/<item_id>/
  //                Body: {"quantity": 5}
  //
  // Use case: user taps +/- buttons in the cart page

  static Future<Map<String, dynamic>?> updateCartItem({
    required int itemId,
    required int quantity,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.put(
        Uri.parse('${baseUrl}cart/item/$itemId/'),
        headers: headers,
        body: jsonEncode({'quantity': quantity}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // REMOVE CART ITEM
  // ============================================================
  // Removes a product from the cart entirely.
  //
  // Flutter sends: DELETE /api/cart/item/<item_id>/

  static Future<Map<String, dynamic>?> removeCartItem({
    required int itemId,
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.delete(
        Uri.parse('${baseUrl}cart/item/$itemId/remove/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // CHECKOUT — Place Order
  // ============================================================
  // Converts the cart into a permanent order.
  //
  // Flutter sends: POST /api/orders/checkout/
  //                Body: {"address": "123 Main St, City"}
  //
  // Django creates Order + OrderItems, clears cart
  // Returns the new Order with all items.

  static Future<Map<String, dynamic>?> checkout({
    String address = '',
  }) async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.post(
        Uri.parse('${baseUrl}orders/checkout/'),
        headers: headers,
        body: jsonEncode({'address': address}),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET ORDERS
  // ============================================================
  // Fetches all orders placed by the current user.
  //
  // Flutter sends: GET /api/orders/
  // Django returns: list of orders with items

  static Future<List<dynamic>?> getOrders() async {
    try {
      final headers = await AuthService.authHeaders();
      final response = await http.get(
        Uri.parse('${baseUrl}orders/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
