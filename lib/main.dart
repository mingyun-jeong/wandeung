import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/r2_config.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await SupabaseConfig.initialize();
  R2Config.initialize();

  // FFmpeg drawtext용 시스템 폰트 디렉토리 등록 (실패해도 앱 구동에 영향 없음)
  try {
    await FFmpegKitConfig.setFontDirectory('/system/fonts');
  } catch (e) {
    debugPrint('FFmpegKit font directory 설정 실패: $e');
  }

  runApp(const ProviderScope(child: ReclimApp()));
}
