import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl(this.url, this.expiresAt);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class R2Config {
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// presigned URL 캐시 (objectKey → 캐싱된 URL)
  /// 만료 10분 전에 갱신하도록 여유를 둠
  static final Map<String, _CachedUrl> _urlCache = {};

  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('로그인이 필요합니다');
    }
    if (session.isExpired) {
      final refreshed = await _supabase.auth.refreshSession();
      session = refreshed.session;
      if (session == null) throw Exception('세션 갱신 실패');
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    final accessToken = session.accessToken;

    debugPrint('[R2] calling edge function with token: ${accessToken.substring(0, 20)}...');

    final response = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/r2'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'apikey': anonKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      debugPrint('[R2] error ${response.statusCode}: ${response.body}');
      throw Exception('R2 Edge Function 오류 (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// R2에 파일 업로드 (presigned URL 경유)
  static Future<void> uploadFile({
    required String objectKey,
    required File file,
    String? contentType,
    String? cacheControl,
  }) async {
    final bytes = await file.readAsBytes();
    final result = await _invoke({
      'action': 'presign-upload',
      'objectKey': objectKey,
      'contentType': contentType,
    });
    final presignedUrl = result['url'] as String;

    debugPrint('[R2] PUT $objectKey (${bytes.length} bytes)');
    final response = await http.put(
      Uri.parse(presignedUrl),
      headers: {
        if (contentType != null) 'Content-Type': contentType,
        if (cacheControl != null) 'Cache-Control': cacheControl,
      },
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception('R2 업로드 실패 (${response.statusCode}): ${response.body}');
    }
  }

  /// R2에서 파일 삭제
  static Future<void> deleteFile(String objectKey) async {
    await _invoke({'action': 'delete', 'objectKey': objectKey});
    _urlCache.remove(objectKey);
  }

  /// R2에서 prefix 아래 모든 파일 삭제
  static Future<void> deleteAllFiles(String prefix) async {
    await _invoke({'action': 'delete-all', 'prefix': prefix});
    _urlCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Presigned download URL 생성 (캐싱 — 만료 10분 전까지 재사용)
  static Future<String> getPresignedUrl(String objectKey, {int expireSeconds = 3600}) async {
    final cached = _urlCache[objectKey];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    final result = await _invoke({
      'action': 'presign-download',
      'objectKey': objectKey,
    });
    final url = result['url'] as String;

    // 만료 10분 전까지 캐시 유효
    _urlCache[objectKey] = _CachedUrl(
      url,
      DateTime.now().add(Duration(seconds: expireSeconds - 600)),
    );

    return url;
  }

  /// 캐시 초기화 (로그아웃 시 호출)
  static void clearCache() {
    _urlCache.clear();
  }
}
