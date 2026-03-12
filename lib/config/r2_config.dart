import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class R2Config {
  static late final String _endpoint;
  static late final String _accessKey;
  static late final String _secretKey;
  static late final String _bucket;
  static late final String _host;
  static late final String _region;

  static void initialize() {
    _endpoint = dotenv.env['R2_ENDPOINT']!;
    _accessKey = dotenv.env['R2_ACCESS_KEY_ID']!;
    _secretKey = dotenv.env['R2_SECRET_ACCESS_KEY']!;
    _bucket = dotenv.env['R2_BUCKET_NAME']!;

    final uri = Uri.parse(_endpoint);
    _host = uri.host;
    _region = 'auto';
  }

  /// S3 PUT 업로드
  static Future<void> uploadFile({
    required String objectKey,
    required File file,
    String? contentType,
  }) async {
    final bytes = await file.readAsBytes();
    final now = DateTime.now().toUtc();
    final uri = Uri.https(_host, '/$_bucket/$objectKey');

    final headers = _signRequest(
      method: 'PUT',
      uri: uri,
      headers: {
        'Host': _host,
        if (contentType != null) 'Content-Type': contentType,
        'x-amz-content-sha256': sha256.convert(bytes).toString(),
        'x-amz-date': _amzDateFormat(now),
      },
      payload: bytes,
      dateTime: now,
    );

    debugPrint('[R2] PUT $uri');
    debugPrint('[R2] Headers: ${headers.keys.join(', ')}');
    debugPrint('[R2] Body size: ${bytes.length} bytes');

    final response = await http.put(uri, headers: headers, body: bytes);
    debugPrint('[R2] Response: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('[R2] Response body: ${response.body}');
      throw Exception('R2 업로드 실패 (${response.statusCode}): ${response.body}');
    }
  }

  /// S3 DELETE
  static Future<void> deleteFile(String objectKey) async {
    final now = DateTime.now().toUtc();
    final uri = Uri.https(_host, '/$_bucket/$objectKey');
    final emptyHash = sha256.convert([]).toString();

    final headers = _signRequest(
      method: 'DELETE',
      uri: uri,
      headers: {
        'Host': _host,
        'x-amz-content-sha256': emptyHash,
        'x-amz-date': _amzDateFormat(now),
      },
      payload: Uint8List(0),
      dateTime: now,
    );

    final response = await http.delete(uri, headers: headers);
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw Exception('R2 삭제 실패 (${response.statusCode}): ${response.body}');
    }
  }

  /// S3 LIST (특정 prefix 아래 오브젝트 목록)
  static Future<List<String>> listObjects(String prefix) async {
    final now = DateTime.now().toUtc();
    final uri = Uri.https(_host, '/$_bucket/', {'prefix': prefix, 'list-type': '2'});
    final emptyHash = sha256.convert([]).toString();

    final headers = _signRequest(
      method: 'GET',
      uri: uri,
      headers: {
        'Host': _host,
        'x-amz-content-sha256': emptyHash,
        'x-amz-date': _amzDateFormat(now),
      },
      payload: Uint8List(0),
      dateTime: now,
    );

    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('R2 목록 조회 실패 (${response.statusCode})');
    }

    // XML 파싱 (간단한 Key 추출)
    final keys = <String>[];
    final keyPattern = RegExp(r'<Key>(.*?)</Key>');
    for (final match in keyPattern.allMatches(response.body)) {
      keys.add(match.group(1)!);
    }
    return keys;
  }

  /// Presigned URL 생성 (GET용, 기본 1시간)
  static String getPresignedUrl(String objectKey, {int expireSeconds = 3600}) {
    final now = DateTime.now().toUtc();
    final dateStamp = _dateStampFormat(now);
    final amzDate = _amzDateFormat(now);
    final credential = '$_accessKey/$dateStamp/$_region/s3/aws4_request';

    final uri = Uri.https(_host, '/$_bucket/$objectKey');

    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expireSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedQuery = (queryParams.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final canonicalRequest = [
      'GET',
      '/$_bucket/${objectKey.split('/').map(Uri.encodeComponent).join('/')}',
      sortedQuery,
      'host:$_host',
      '',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      '$dateStamp/$_region/s3/aws4_request',
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(dateStamp);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    final presignedUrl = '${uri.toString()}?$sortedQuery&X-Amz-Signature=$signature';
    debugPrint('[R2] Presigned URL for "$objectKey": $presignedUrl');
    return presignedUrl;
  }

  // --- S3v4 서명 ---

  static Map<String, String> _signRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required List<int> payload,
    required DateTime dateTime,
  }) {
    final dateStamp = _dateStampFormat(dateTime);
    final payloadHash = headers['x-amz-content-sha256'] ??
        sha256.convert(payload).toString();

    final signedHeaderKeys = (headers.keys.map((k) => k.toLowerCase()).toList()
          ..sort())
        .join(';');

    final canonicalHeaders = (headers.entries.toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())))
        .map((e) => '${e.key.toLowerCase()}:${e.value.trim()}')
        .join('\n');

    final canonicalQueryString = (uri.queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final canonicalRequest = [
      method,
      uri.path.isEmpty ? '/' : uri.path,
      canonicalQueryString,
      '$canonicalHeaders\n',
      signedHeaderKeys,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      _amzDateFormat(dateTime),
      '$dateStamp/$_region/s3/aws4_request',
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(dateStamp);
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    return {
      ...headers,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$_accessKey/$dateStamp/$_region/s3/aws4_request, '
          'SignedHeaders=$signedHeaderKeys, '
          'Signature=$signature',
    };
  }

  static List<int> _getSignatureKey(String dateStamp) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$_secretKey'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion =
        Hmac(sha256, kDate).convert(utf8.encode(_region)).bytes;
    final kService =
        Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    return Hmac(sha256, kService)
        .convert(utf8.encode('aws4_request'))
        .bytes;
  }

  static String _amzDateFormat(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}'
      'T'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}'
      'Z';

  static String _dateStampFormat(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';
}
