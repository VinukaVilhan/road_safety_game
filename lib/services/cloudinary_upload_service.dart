import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Uploads raw image bytes to Cloudinary using an unsigned upload preset.
class CloudinaryUploadService {
  CloudinaryUploadService._();

  /// Returns HTTPS URL on success, or null if misconfigured, network error, or API failure.
  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    String? publicId,
  }) async {
    if (!CloudinaryConfig.isConfigured) return null;
    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = preset;
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final url = decoded['secure_url'];
      if (url is! String || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }
}
