import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../models/climbing_gym.dart';

final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  // 1. 위치 권한 및 현재 위치 (고정밀도)
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) return [];

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );

  // 2. 역지오코딩으로 구/동 이름 추출
  String locationPrefix = '';
  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      // subAdministrativeArea = 구, subLocality = 동
      final district = p.subAdministrativeArea ?? '';
      final neighborhood = p.subLocality ?? '';
      if (neighborhood.isNotEmpty) {
        locationPrefix = '$district $neighborhood';
      } else if (district.isNotEmpty) {
        locationPrefix = district;
      }
    }
  } catch (_) {}

  final query = locationPrefix.isNotEmpty ? '$locationPrefix 클라이밍장' : '클라이밍장';

  // 3. 네이버 지역 검색 API
  final clientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
  final clientSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';

  if (clientId.isEmpty || clientSecret.isEmpty) return [];

  final uri = Uri.https(
    'openapi.naver.com',
    '/v1/search/local.json',
    {'query': query, 'display': '10', 'sort': 'comment'},
  );

  final response = await http.get(uri, headers: {
    'X-Naver-Client-Id': clientId,
    'X-Naver-Client-Secret': clientSecret,
  });

  if (response.statusCode != 200) return [];

  final items = (jsonDecode(response.body)['items'] as List);

  final gyms = items
      .where((item) =>
          item['mapx'] != null &&
          item['mapy'] != null &&
          item['mapx'].toString().isNotEmpty)
      .map((item) {
        // mapx/mapy는 WGS84 좌표 * 1e7
        final lng = double.parse(item['mapx'].toString()) / 1e7;
        final lat = double.parse(item['mapy'].toString()) / 1e7;
        // HTML 태그 제거 (<b>, </b> 등)
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

  // 4. 현재 위치 기준 거리순 정렬 후 20km 이내만 반환
  gyms.sort((a, b) {
    final distA = Geolocator.distanceBetween(
        position.latitude, position.longitude, a.latitude!, a.longitude!);
    final distB = Geolocator.distanceBetween(
        position.latitude, position.longitude, b.latitude!, b.longitude!);
    return distA.compareTo(distB);
  });

  return gyms.where((gym) {
    final dist = Geolocator.distanceBetween(
        position.latitude, position.longitude, gym.latitude!, gym.longitude!);
    return dist <= 20000; // 20km 이내
  }).toList();
});
