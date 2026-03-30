
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.sync_problem, size: 64, color: SeniorStyles.primaryBlue),
              const SizedBox(height: 16),
              const Text("SeniorSync", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
              const Text("Your Companion in Healthy Aging", style: TextStyle(fontSize: 18, color: Colors.black38)),
              const SizedBox(height: 60),
              Text(_isLogin ? "Welcome Back" : "Join Us", style: SeniorStyles.header),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      if (_isLogin) {
                        await auth.signIn(_emailCtrl.text, _passCtrl.text);
                      } else {
                        await auth.signUp(_emailCtrl.text, _passCtrl.text);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeniorStyles.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isLogin ? "LOG IN" : "CREATE ACCOUNT", style: SeniorStyles.largeButtonText),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In",
                    style: const TextStyle(fontSize: 16, color: SeniorStyles.primaryBlue),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OR")),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await auth.signInWithGoogle();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Google Sign-In failed: $e")),
                    );
                  }
                },
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: const Text("SIGN IN WITH GOOGLE", style: SeniorStyles.largeButtonText),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
