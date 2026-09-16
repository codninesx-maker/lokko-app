

class DistrictModel {
  final String id;
  final String name;

  DistrictModel({required this.id, required this.name});

  // Use this for BOTH Supabase maps and JSON
  factory DistrictModel.fromMap(Map<String, dynamic> map) {
    return DistrictModel(
      // Checks for 'id' OR 'location_id'
      id: (map['id'] ?? map['location_id'])?.toString() ?? '',
      name: (map['name'] ?? map['location_name'])?.toString() ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() => name; // Useful for dropdowns and logs
}