import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';

final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  final position = await Geolocator.getCurrentPosition();

  final response =
      await SupabaseConfig.client.from('climbing_gyms').select().order('name');

  final gyms =
      (response as List).map((e) => ClimbingGym.fromMap(e)).toList();

  // 클라이언트 사이드 거리순 정렬
  gyms.sort((a, b) {
    if (a.latitude == null || b.latitude == null) return 0;
    final distA = Geolocator.distanceBetween(
        position.latitude, position.longitude, a.latitude!, a.longitude!);
    final distB = Geolocator.distanceBetween(
        position.latitude, position.longitude, b.latitude!, b.longitude!);
    return distA.compareTo(distB);
  });

  return gyms;
});

final gymSearchProvider =
    FutureProvider.family<List<ClimbingGym>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final response = await SupabaseConfig.client
      .from('climbing_gyms')
      .select()
      .ilike('name', '%$query%')
      .limit(10);
  return (response as List).map((e) => ClimbingGym.fromMap(e)).toList();
});
