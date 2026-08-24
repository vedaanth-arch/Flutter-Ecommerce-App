/*
 * ============================================================
 * AUTH SERVICE — Flutter side of JWT Authentication
 * ============================================================
 *
 * WHAT THIS FILE DOES:
 * This is the bridge between Flutter and Django's auth API.
 * It handles:
 *   1. Storing JWT tokens securely on the device
 *   2. Sending login/register requests to Django
 *   3. Attaching the JWT token to every API request
 *   4. Refreshing expired tokens
 *
 * HOW JWT WORKS IN FLUTTER:
 * ┌─────────────────────────────────────────────────────────┐
 * │ 1. User opens app → sees Login page                     │
 * │ 2. User enters username + password                      │
 * │ 3. Flutter sends POST /api/auth/login/ to Django        │
 * │ 4. Django returns: {tokens: {access, refresh}, user}    │
 * │ 5. Flutter stores tokens locally (SharedPreferences)    │
 * │ 6. For EVERY future API call, Flutter adds header:      │
 * │      Authorization: Bearer <access_token>               │
 * │ 7. Django reads this header, identifies the user        │
 * │ 8. When access_token expires (30 min), Flutter uses     │
 * │    the refresh_token to get a new one automatically     │
 * └─────────────────────────────────────────────────────────┘
 *
 * API BASE URL:
 *   All requests go to: https://flutter-ecommerce-app-production.up.railway.app/api/
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ============================================================
  // BASE URL — where our Django server lives
  // ============================================================
  // All API calls start from this URL.
  // Example: baseUrl + "auth/login/" → full login URL
  static const String baseUrl =
      'https://flutter-ecommerce-app-production.up.railway.app/api/';

  // ============================================================
  // TOKEN KEYS — keys used to store tokens in SharedPreferences
  // ============================================================
  // SharedPreferences is Flutter's way of storing data persistently
  // on the device (like localStorage in web browsers).
  // We store tokens here so the user stays logged in after closing the app.
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  // ============================================================
  // GET STORED TOKENS
  // ============================================================
  // Reads tokens from device storage.
  // Returns null if no token exists (user not logged in).

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // ============================================================
  // CHECK IF USER IS LOGGED IN
  // ============================================================
  // Simple check: do we have an access token stored?

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================================
  // BUILD AUTH HEADERS
  // ============================================================
  // This is the KEY function that makes JWT work.
  // It creates the HTTP headers that Django expects.
  //
  // Django's JWTAuthentication middleware looks for:
  //   Authorization: Bearer <access_token>
  //
  // Example output:
  //   {
  //     "Content-Type": "application/json",
  //     "Authorization": "Bearer eyJ0eXAiOiJKV1QiLCJhbGci..."
  //   }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // REGISTER
  // ============================================================
  // Sends registration data to Django.
  //
  // Flutter sends:  POST /api/auth/register/
  //                 Body: {"username", "email", "password"}
  //
  // Django returns: {"tokens": {"access", "refresh"}, "user": {...}}
  //
  // On success: stores tokens + user info, returns true
  // On failure: returns false

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        // Success! Parse the response and store tokens
        final data = jsonDecode(response.body);
        await _storeTokens(data['tokens']);
        await _storeUserInfo(data['user']);
        return {'success': true, 'user': data['user']};
      } else {
        // Registration failed — return the error messages
        final errors = jsonDecode(response.body);
        return {'success': false, 'errors': errors};
      }
    } catch (e) {
      return {'success': false, 'errors': {'network': e.toString()}};
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================
  // Sends credentials to Django, gets back JWT tokens.
  //
  // Flutter sends:  POST /api/auth/login/
  //                 Body: {"username", "password"}
  //
  // Django returns: {"tokens": {"access", "refresh"}, "user": {...}}
  //
  // This is the core of JWT auth — after this call, every API request
  // will include the access token in the Authorization header.

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storeTokens(data['tokens']);
        await _storeUserInfo(data['user']);
        return {'success': true, 'user': data['user']};
      } else {
        final errors = jsonDecode(response.body);
        return {'success': false, 'errors': errors};
      }
    } catch (e) {
      return {'success': false, 'errors': {'network': e.toString()}};
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  // Clears all stored tokens and user info.
  // After this, isLoggedIn() returns false and all API calls
  // will fail with 401 Unauthorized (which forces re-login).

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }

  // ============================================================
  // REFRESH TOKEN
  // ============================================================
  // When the access token expires (after 30 minutes), Flutter uses
  // the refresh token to get a new access token WITHOUT re-login.
  //
  // Flutter sends:  POST /api/auth/refresh/
  //                 Body: {"refresh": "<refresh_token>"}
  //
  // Django returns: {"access": "<new_access_token>"}
  //
  // If the refresh token is also expired (after 7 days),
  // user must log in again.

  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, data['access']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET USER PROFILE
  // ============================================================
  // Fetches the current user's profile from Django.
  //
  // Flutter sends:  GET /api/auth/profile/
  //                 Header: Authorization: Bearer <access_token>
  //
  // Django identifies the user from the token and returns their data.

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('${baseUrl}auth/profile/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired — try refreshing
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          // Retry with new token
          final newHeaders = await authHeaders();
          final retryResponse = await http.get(
            Uri.parse('${baseUrl}auth/profile/'),
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
  // PRIVATE HELPER: Store tokens in SharedPreferences
  // ============================================================

  static Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, tokens['access']);
    await prefs.setString(_refreshTokenKey, tokens['refresh']);
  }

  static Future<void> _storeUserInfo(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user['id']);
    await prefs.setString(_usernameKey, user['username']);
  }
}
