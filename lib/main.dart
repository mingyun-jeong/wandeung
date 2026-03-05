import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await SupabaseConfig.initialize();

  // FFmpeg drawtext용 시스템 폰트 디렉토리 등록
  await FFmpegKitConfig.setFontDirectory('/system/fonts');

  final naverMapClientId = dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';
  if (naverMapClientId.isNotEmpty) {
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (ex) => debugPrint('네이버 지도 인증 실패: $ex'),
    );
  }

  runApp(const ProviderScope(child: WandeungApp()));
}
