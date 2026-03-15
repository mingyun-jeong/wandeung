import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 현재 네트워크 연결 상태 스트림
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
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

/// 클라우드 업로드 설정
const _cloudUploadKey = 'cloud_upload_enabled';

final cloudUploadEnabledProvider =
    StateNotifierProvider<CloudUploadEnabledNotifier, bool>((ref) {
  return CloudUploadEnabledNotifier();
});

class CloudUploadEnabledNotifier extends StateNotifier<bool> {
  bool _loaded = false;

  CloudUploadEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_cloudUploadKey) ?? true;
    _loaded = true;
  }

  /// SharedPreferences에서 직접 읽어 확실한 값 반환
  Future<bool> getValue() async {
    if (_loaded) return state;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cloudUploadKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudUploadKey, state);
  }
}

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
