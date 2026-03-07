import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/climbing_gym.dart';

final userPositionProvider = FutureProvider<Position?>((ref) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) return null;
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

Future<List<ClimbingGym>> _searchGooglePlaces({
  required String searchQuery,
  required String apiKey,
  Position? position,
  bool filterByDistance = false,
}) async {
  final queryParams = <String, String>{
    'query': searchQuery,
    'key': apiKey,
    'language': 'ko',
  };

  if (position != null) {
    queryParams['location'] = '${position.latitude},${position.longitude}';
    queryParams['radius'] = '20000';
  }

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/textsearch/json',
    queryParams,
  );

  print('[GymProvider] Places API request: $uri');
  final response = await http.get(uri);
  print('[GymProvider] Places API statusCode: ${response.statusCode}');
  print('[GymProvider] Places API response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');
  if (response.statusCode != 200) return [];

  final body = jsonDecode(response.body);
  print('[GymProvider] Places API status: ${body['status']}, results count: ${(body['results'] as List?)?.length ?? 0}');
  if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') return [];

  final results = (body['results'] as List?) ?? [];

  final gyms = results
      .map((item) {
        final location = item['geometry']?['location'];
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        return ClimbingGym(
          id: null,
          name: item['name'] ?? '',
          address: item['formatted_address'],
          latitude: lat,
          longitude: lng,
          googlePlaceId: item['place_id'],
        );
      })
      .where((gym) =>
          gym.name.isNotEmpty && gym.latitude != null && gym.longitude != null)
      .toList();

  if (position != null) {
    gyms.sort((a, b) {
      final distA = Geolocator.distanceBetween(
          position.latitude, position.longitude, a.latitude!, a.longitude!);
      final distB = Geolocator.distanceBetween(
          position.latitude, position.longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });
    if (filterByDistance) {
      return gyms.where((gym) {
        final dist = Geolocator.distanceBetween(position.latitude,
            position.longitude, gym.latitude!, gym.longitude!);
        return dist <= 20000;
      }).toList();
    }
  }

  return gyms;
}

// 주변 클라이밍장 (GymSelector용 — 위치 기반)
final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;
  print('[GymProvider] nearbyGymsProvider: position=$position');

  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  print('[GymProvider] API key: ${apiKey.isEmpty ? "EMPTY!" : "${apiKey.substring(0, 8)}..."}');
  if (apiKey.isEmpty) return [];

  return _searchGooglePlaces(
    searchQuery: '클라이밍짐',
    apiKey: apiKey,
    position: position,
    filterByDistance: position != null,
  );
});

// 지도 화면용: 검색어 없으면 주변, 있으면 텍스트 검색
final gymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  print('[GymProvider] gymsProvider called, query="$query"');

  if (query.isEmpty) {
    print('[GymProvider] query empty, delegating to nearbyGymsProvider');
    final results = await ref.watch(nearbyGymsProvider.future);
    print('[GymProvider] nearbyGymsProvider returned ${results.length} results');
    return results;
  }

  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;

  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) return [];

  final searchQuery = query.contains('클라이밍') ? query : '$query 클라이밍짐';

  return _searchGooglePlaces(
    searchQuery: searchQuery,
    apiKey: apiKey,
    position: position,
    filterByDistance: false,
  );
});
