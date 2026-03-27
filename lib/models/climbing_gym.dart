class ClimbingGym {
  final String? id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId;
  final String? brandName;
  final String? instagramUrl;

  ClimbingGym({
    this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.brandName,
    this.instagramUrl,
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
        googlePlaceId: map['google_place_id'],
        brandName: map['brand_name'],
        instagramUrl: map['instagram_url'],
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        if (address != null) 'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (googlePlaceId != null) 'google_place_id': googlePlaceId,
        if (brandName != null) 'brand_name': brandName,
        if (instagramUrl != null) 'instagram_url': instagramUrl,
      };
}
