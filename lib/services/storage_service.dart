import 'dart:typed_data';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  Future<String?> uploadImage(
    Uint8List fileBytes,
    String extension, {
    String? folder,
  }) async {
    try {
      final base64File = base64Encode(fileBytes);
      final response = await Supabase.instance.client.functions.invoke(
        'upload-image',
        body: {
          'file': base64File,
          'ext': extension,
          if (folder != null) 'folder': folder,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String?;
      } else {
        print('Edge Function Upload Error: ${response.status} - ${response.data}');
        return null;
      }
    } catch (e) {
      print('StorageService Error: $e');
      return null;
    }
  }
}
