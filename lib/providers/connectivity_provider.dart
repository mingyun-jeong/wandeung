import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_subscription.dart';
import 'subscription_provider.dart';

/// 네트워크 인터페이스로 Wi-Fi 연결 여부를 직접 확인
/// Android: wlan0, iOS: en0
Future<bool> checkWifiByInterface() async {
  try {
    final interfaces = await NetworkInterface.list();
    final names = interfaces.map((i) => i.name).toList();
    // Android: wlan0, wlan1 등 / iOS: en0
    final hasWifi = interfaces.any(
      (i) => i.name.startsWith('wlan') || i.name == 'en0',
    );
    debugPrint('[Connectivity] interface check: wifi=$hasWifi, interfaces=$names');
    return hasWifi;
  } catch (e) {
    debugPrint('[Connectivity] interface check failed: $e');
    return false;
  }
}

/// connectivity_plus가 wifi를 누락한 경우 NetworkInterface로 보정
Future<List<ConnectivityResult>> _correctResults(
    List<ConnectivityResult> results) async {
  if (results.contains(ConnectivityResult.wifi)) return results;
  if (results.contains(ConnectivityResult.none) || results.isEmpty) {
    return results;
  }
  // connectivity_plus가 wifi를 보고하지 않지만 실제 Wi-Fi 인터페이스가 있으면 보정
  if (await checkWifiByInterface()) {
    return [...results, ConnectivityResult.wifi];
  }
  return results;
}

/// 현재 네트워크 연결 상태 스트림
/// connectivity_plus가 Wi-Fi를 누락하는 경우 NetworkInterface로 보정
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();

  // 현재 상태 emit (보정 포함)
  final initial = await connectivity.checkConnectivity();
  yield await _correctResults(initial);

  // 이후 변경 스트림 (보정 포함)
  await for (final results in connectivity.onConnectivityChanged) {
    yield await _correctResults(results);
  }
});

/// 현재 Wi-Fi 연결 여부
/// 로딩 시 true (초기화 중 업로드 차단 방지), 에러 시 false (안전하게 차단)
final isWifiProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.contains(ConnectivityResult.wifi),
    loading: () => true,
    error: (_, __) => false,
  );
});

/// 클라우드 업로드 활성화 여부 (저장 모드에서 파생)
/// 기존 코드 호환을 위해 유지
final cloudUploadEnabledProvider = Provider<bool>((ref) {
  final mode = ref.watch(storageModeProvider);
  return mode == StorageMode.cloud;
});

/// Wi-Fi 전용 업로드 설정
const _wifiOnlyKey = 'wifi_only_upload';

final wifiOnlyUploadProvider =
    StateNotifierProvider<WifiOnlyUploadNotifier, bool>((ref) {
  return WifiOnlyUploadNotifier();
});

class WifiOnlyUploadNotifier extends StateNotifier<bool> {
  WifiOnlyUploadNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_wifiOnlyKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, state);
  }
}
