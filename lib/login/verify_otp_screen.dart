import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  bool _isLoading = false;

  Future<void> _verifyOtp(String pin) async {
    setState(() => _isLoading = true);
    try {
      // 1. Change type to .email (this is for 6-digit codes)
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: pin,
        type: OtpType.email, // Standard for 6-digit email codes
      );

      if (response.session != null && mounted) {
        // 2. SUCCESS! Show the small green bar you liked
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Verified Successfully!", textAlign: TextAlign.center),
            backgroundColor: const Color(0xFF1aa332),
            behavior: SnackBarBehavior.floating,
            width: 200,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // 3. Navigate to the main screen (Check if your route is '/' or '/dashboard')
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        _showError("Verification failed. Please try again.");
      }
    } catch (e) {
      debugPrint("OTP Error: $e");
      _showError("Invalid code or expired.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// Helper to keep code clean
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 55,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Verify OTP", style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView( // Added to prevent overflow on small screens
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text("Verification", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Enter the 6-digit code sent to\n${widget.email}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
            Pinput(
              length: 6,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyDecorationWith(
                border: Border.all(color: const Color(0xFF1aa332)), // LOKKO Green
              ),
              onCompleted: _verifyOtp,
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF1aa332))
            else
              TextButton(
                onPressed: () {
                  // Re-trigger the email send logic from the previous screen
                  Supabase.instance.client.auth.signInWithOtp(email: widget.email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Code resent successfully")),
                  );
                },
                child: const Text("Resend Code", style: TextStyle(color: Color(0xFF1aa332))),
              ),
          ],
        ),
      ),
    );
  }
}