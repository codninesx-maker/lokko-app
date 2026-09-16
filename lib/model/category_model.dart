import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;


class CategoryModel {
  final String id; // Change this from int to String
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      // Use .toString() to force whatever comes from the DB into a String
      id: map['id'].toString(),
      name: map['name'].toString(),
    );
  }
}

class DistrictModel {
  final String id; // MUST be String
  final String name;

  DistrictModel({required this.id, required this.name});

  factory DistrictModel.fromMap(Map<String, dynamic> map) {
    return DistrictModel(
      id: map['id'].toString(),
      name: map['name'].toString(),
    );
  }
}