import 'package:flutter/painting.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/video_upload_service.dart';
import '../utils/cache_cleanup.dart';
import 'camera_settings_provider.dart';
import 'record_provider.dart';
import 'upload_queue_provider.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref _ref;
  final _supabase = SupabaseConfig.client;

  void _init() {
    final currentUser = _supabase.auth.currentUser;
    state = AsyncValue.data(currentUser);

    _supabase.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']!;

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google ID Token is null');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _ref.read(uploadQueueProvider.notifier).clearAll();
    await GoogleSignIn().signOut();
    await _supabase.auth.signOut();
    await _clearAllCache();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    final userId = _supabase.auth.currentUser!.id;

    // R2 스토리지 영상/썸네일 삭제
    await VideoUploadService.deleteAllUserFiles(userId);
    await _ref.read(uploadQueueProvider.notifier).clearAll();

    // 등반 기록 삭제
    await _supabase.from('climbing_records').delete().eq('user_id', userId);

    // 사용자가 생성한 암장 삭제
    await _supabase.from('climbing_gyms').delete().eq('created_by', userId);

    // auth.users에서 계정 삭제 (SECURITY DEFINER 함수)
    await _supabase.rpc('delete_own_user');

    await GoogleSignIn().signOut();
    await _clearAllCache();
    state = const AsyncValue.data(null);
  }

  /// 앱 캐시 + 이미지 캐시 + Riverpod 데이터 캐시 전체 삭제
  Future<void> _clearAllCache() async {
    await CacheCleanup.clearAppCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _resetUiState();
  }

  /// 필터·UI 상태 초기화 (데이터 provider는 authProvider watch로 자동 갱신)
  void _resetUiState() {
    _ref.read(selectedColorFilterProvider.notifier).state = null;
    _ref.read(selectedStatusFilterProvider.notifier).state = null;
    _ref.read(selectedTagFilterProvider.notifier).state = null;
    _ref.read(selectedGymFilterProvider.notifier).state = null;
    _ref.read(bottomNavIndexProvider.notifier).state = 0;
  }
}
