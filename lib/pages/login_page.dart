/*
 * ============================================================
 * LOGIN PAGE — JWT Authentication
 * ============================================================
 *
 * WHAT CHANGED FROM THE OLD VERSION:
 * OLD: Hardcoded check — if username == "admin" && password == "admin"
 * NEW: Real JWT auth — sends credentials to Django, gets tokens back
 *
 * HOW IT WORKS:
 * 1. User types username + password
 * 2. Taps "Login" button
 * 3. Flutter calls AuthService.login() → sends POST to Django
 * 4. Django validates credentials against the database
 * 5. If valid: Django returns JWT tokens → Flutter stores them → navigates to home
 * 6. If invalid: Django returns error → Flutter shows error message
 *
 * ALSO ADDED: Registration mode toggle
 * User can switch between Login and Register without leaving the page
 */

import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/home_page.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // STATE VARIABLES
  // ============================================================
  // Controllers hold the text input from the user
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Toggle between Login and Register mode
  bool _isRegisterMode = false;

  // Show loading spinner while API call is in progress
  bool _isLoading = false;

  // Error message to display
  String? _errorMessage;

  // ============================================================
  // CHECK IF ALREADY LOGGED IN
  // ============================================================
  // When the page loads, check if we already have a stored token.
  // If yes, skip login and go straight to home page.

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  // ============================================================
  // LOGIN HANDLER
  // ============================================================
  // This is called when the user taps "Login".
  //
  // Flow:
  // 1. Set _isLoading = true → shows spinner, disables button
  // 2. Call AuthService.login() → sends HTTP POST to Django
  // 3. If success: navigate to HomePage
  // 4. If failure: show error message
  // 5. Set _isLoading = false → hides spinner

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (result['success']) {
      // Login successful — go to home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // Login failed — show error
      setState(() {
        _errorMessage = _extractError(result['errors']);
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // REGISTER HANDLER
  // ============================================================
  // Similar to login, but calls AuthService.register() instead.

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (result['success']) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      setState(() {
        _errorMessage = _extractError(result['errors']);
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // HELPER: Extract readable error from Django's response
  // ============================================================
  // Django returns errors like: {"username": ["Username already taken."]}
  // This converts it to a readable string.

  String _extractError(dynamic errors) {
    if (errors is Map) {
      final messages = <String>[];
      errors.forEach((key, value) {
        if (value is List) {
          messages.addAll(value.map((e) => e.toString()));
        } else {
          messages.add(value.toString());
        }
      });
      return messages.join('\n');
    }
    return 'An error occurred';
  }

  // ============================================================
  // BUILD THE UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 149, 149, 247),
      appBar: AppBar(
        title: Text(_isRegisterMode ? "Register" : "Login"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TITLE
              Text(
                _isRegisterMode ? "Create Account" : "Welcome Back",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              // USERNAME FIELD
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 16),

              // EMAIL FIELD (only shown in register mode)
              if (_isRegisterMode) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // PASSWORD FIELD
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              const SizedBox(height: 8),

              // ERROR MESSAGE
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 16),

              // LOGIN / REGISTER BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_isRegisterMode ? _handleRegister : _handleLogin),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegisterMode ? "Register" : "Login"),
                ),
              ),

              const SizedBox(height: 16),

              // TOGGLE LOGIN/REGISTER
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegisterMode = !_isRegisterMode;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isRegisterMode
                      ? "Already have an account? Login"
                      : "Don't have an account? Register",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
