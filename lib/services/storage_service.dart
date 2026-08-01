import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageService {
  static String get _accountId => dotenv.env['R2_ACCOUNT_ID'] ?? '';
  static String get _accessKeyId => dotenv.env['R2_ACCESS_KEY_ID'] ?? '';
  static String get _secretAccessKey =>
      dotenv.env['R2_SECRET_ACCESS_KEY'] ?? '';
  static String get _bucketName =>
      dotenv.env['R2_BUCKET_NAME'] ?? 'street-eats-images';
  static String get _publicBaseUrl => dotenv.env['R2_PUBLIC_URL'] ?? '';

  static String get _endpoint => 'https://$_accountId.r2.cloudflarestorage.com';

  Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      final ext = path.extension(file.path);
      final fileName = '${const Uuid().v4()}$ext';
      final objectKey = folder != null ? '$folder/$fileName' : fileName;

      final fileBytes = await file.readAsBytes();
      final contentType = _getContentType(ext);

      final headers = await _buildHeaders(
        objectKey: objectKey,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      final url = Uri.parse('$_endpoint/$_bucketName/$objectKey');
      final response = await http.put(
        url,
        headers: headers,
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        return '$_publicBaseUrl/$objectKey';
      } else {
        print('R2 Upload Error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('StorageService Error: $e');
      return null;
    }
  }

  Future<bool> deleteImage(String publicUrl) async {
    try {
      final objectKey = publicUrl.replaceFirst('$_publicBaseUrl/', '');
      final headers = await _buildHeaders(
        objectKey: objectKey,
        fileBytes: Uint8List(0),
        contentType: 'application/octet-stream',
        method: 'DELETE',
      );

      final url = Uri.parse('$_endpoint/$_bucketName/$objectKey');
      final response = await http.delete(url, headers: headers);
      return response.statusCode == 204;
    } catch (e) {
      print('Delete Error: $e');
      return false;
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required String objectKey,
    required List<int> fileBytes,
    required String contentType,
    String method = 'PUT',
  }) async {
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatAmzDate(now);

    final payloadHash = sha256.convert(fileBytes).toString();

    final headers = <String, String>{
      'content-type': contentType,
      'host': '$_accountId.r2.cloudflarestorage.com',
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };

    final canonicalHeaders =
        '${headers.entries.map((e) => '${e.key}:${e.value}').join('\n')}\n';

    final signedHeaders = headers.keys.join(';');

    final canonicalRequest = [
      method,
      '/$_bucketName/$objectKey',
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/auto/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSigningKey(dateStamp);
    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    headers['authorization'] =
        'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    return headers;
  }

  List<int> _getSigningKey(String dateStamp) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$_secretAccessKey'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode('auto')).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _formatAmzDate(DateTime dt) =>
      '${_formatDate(dt)}T${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}Z';

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
