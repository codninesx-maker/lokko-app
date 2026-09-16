import 'package:flutter/material.dart';
import 'package:lokko_market/login/verify_otp_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Code sent to $email")),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpScreen(email: email),
          ),
        );
      }
    } on AuthException catch (e) {
      String message = e.message;
      if (message.contains("limit exceeded")) {
        message = "Too many attempts. Please wait 60 seconds.";
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Login"), // Added back a simple title
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1aa332),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
              children: [
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your email to receive a 6-digit login code.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "example@gmail.com",
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1aa332)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1aa332), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332)))
                    : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1aa332),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Send Code",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}