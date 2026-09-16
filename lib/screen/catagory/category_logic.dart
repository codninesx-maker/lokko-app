import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  // Fetch id, name, and icon_url from the categories table
  final data = await supabase.from('categories').select('id, name, icon_url');
  return data as List<Map<String, dynamic>>;
});