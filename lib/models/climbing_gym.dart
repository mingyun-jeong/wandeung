class ClimbingGym {
  final String? id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  ClimbingGym({
    this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory ClimbingGym.fromMap(Map<String, dynamic> map) => ClimbingGym(
        id: map['id'],
        name: map['name'],
        address: map['address'],
        latitude: map['latitude'] != null
            ? (map['latitude'] as num).toDouble()
            : null,
        longitude: map['longitude'] != null
            ? (map['longitude'] as num).toDouble()
            : null,
      );
}
