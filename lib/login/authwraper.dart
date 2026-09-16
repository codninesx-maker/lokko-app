import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/screen/dashboard_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/login/login_screen.dart';
import 'package:lokko_market/screen/dashboard_logic.dart';

// 1. Define the authStateProvider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class LOKKOApp extends StatelessWidget {
  const LOKKOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'LOKKO',
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Watch the provider defined above
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (data) {
        if (data.session != null) {
          return const DashboardView(); // Updated from MainBottomBar to DashboardView
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Auth Error: $e')),
      ),
    );
  }
}