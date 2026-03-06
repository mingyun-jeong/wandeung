import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../models/climbing_gym.dart';

// 현재 위치 (공유)
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

// 지도 검색어
final searchQueryProvider = StateProvider<String>((ref) => '');

// 네이버 지역 검색 API 호출 (내부 헬퍼)
Future<List<ClimbingGym>> _searchNaverGyms({
  required String searchQuery,
  required String sort,
  required String clientId,
  required String clientSecret,
  Position? position,
  bool filterByDistance = false,
}) async {
  final uri = Uri.https(
    'openapi.naver.com',
    '/v1/search/local.json',
    {'query': searchQuery, 'display': '20', 'sort': sort},
  );
  final response = await http.get(uri, headers: {
    'X-Naver-Client-Id': clientId,
    'X-Naver-Client-Secret': clientSecret,
  });
  if (response.statusCode != 200) return [];

  final items = jsonDecode(response.body)['items'] as List;
  final gyms = items
      .where((item) =>
          item['mapx'] != null &&
          item['mapy'] != null &&
          item['mapx'].toString().isNotEmpty)
      .map((item) {
        final lng = double.parse(item['mapx'].toString()) / 1e7;
        final lat = double.parse(item['mapy'].toString()) / 1e7;
        final name =
            (item['title'] as String).replaceAll(RegExp(r'<[^>]*>'), '');
        return ClimbingGym(
          id: null,
          name: name,
          address: (item['roadAddress'] as String?)?.isNotEmpty == true
              ? item['roadAddress']
              : item['address'],
          latitude: lat,
          longitude: lng,
        );
      })
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
        final dist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            gym.latitude!, gym.longitude!);
        return dist <= 20000;
      }).toList();
    }
  }

  return gyms;
}

Future<String> _reverseGeocodePrefix(Position position) async {
  try {
    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final district = p.subAdministrativeArea ?? '';
      final neighborhood = p.subLocality ?? '';
      if (neighborhood.isNotEmpty) return '$district $neighborhood';
      if (district.isNotEmpty) return district;
    }
  } catch (_) {}
  return '';
}

// 주변 클라이밍장 (GymSelector용 — 위치 기반, 위치 없어도 검색)
final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;

  final clientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
  final clientSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
  if (clientId.isEmpty || clientSecret.isEmpty) return [];

  String searchQuery = '클라이밍짐';
  if (position != null) {
    final prefix = await _reverseGeocodePrefix(position);
    if (prefix.isNotEmpty) searchQuery = '$prefix 클라이밍짐';
  }

  return _searchNaverGyms(
    searchQuery: searchQuery,
    sort: 'comment',
    clientId: clientId,
    clientSecret: clientSecret,
    position: position,
    filterByDistance: position != null,
  );
});

// 지도 화면용: 검색어 없으면 주변, 있으면 텍스트 검색
final gymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return await ref.watch(nearbyGymsProvider.future);
  }

  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;

  final clientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
  final clientSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
  if (clientId.isEmpty || clientSecret.isEmpty) return [];

  final searchQuery = query.contains('클라이밍') ? query : '$query 클라이밍짐';

  return _searchNaverGyms(
    searchQuery: searchQuery,
    sort: 'random',
    clientId: clientId,
    clientSecret: clientSecret,
    position: position,
    filterByDistance: false,
  );
});
