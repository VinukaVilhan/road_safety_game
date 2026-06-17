import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/cloudinary_config.dart';

/// Uploads raw image bytes to Cloudinary using an unsigned upload preset.
class CloudinaryUploadService {
  CloudinaryUploadService._();

  /// Returns HTTPS URL on success, or null if misconfigured, network error, or API failure.
  ///
  /// [folder] and [publicId] are optional Cloudinary API fields; the unsigned preset
  /// must allow them in the Cloudinary console or the upload may fail (caller gets null).
  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    String? folder,
    String? publicId,
  }) async {
    if (!CloudinaryConfig.isConfigured) return null;
    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = preset;
    final f = folder?.trim();
    if (f != null && f.isNotEmpty) {
      request.fields['folder'] = f;
    }
    final pid = publicId?.trim();
    if (pid != null && pid.isNotEmpty) {
      request.fields['public_id'] = pid;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('image', 'png'),
      ),
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
