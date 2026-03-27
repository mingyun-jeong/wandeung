import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Google Place ID로 사진 URL 목록 조회
final gymPhotoProvider =
    FutureProvider.family<List<String>, String>((ref, placeId) async {
  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) return [];

  try {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'photos',
      'key': apiKey,
      'language': 'ko',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body);
    if (body['status'] != 'OK') return [];

    final photos = body['result']?['photos'] as List? ?? [];
    return photos.take(5).map<String>((photo) {
      final ref = photo['photo_reference'] as String;
      return Uri.https('maps.googleapis.com', '/maps/api/place/photo', {
        'maxwidth': '800',
        'photo_reference': ref,
        'key': apiKey,
      }).toString();
    }).toList();
  } catch (e) {
    debugPrint('[gymPhotoProvider] error: $e');
    return [];
  }
});
