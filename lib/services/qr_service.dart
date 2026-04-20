import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrService {
  static final _supabase = Supabase.instance.client;

  /// Generates a QR code image, uploads it to Supabase Storage, and syncs with DB.
  /// Returns the public URL of the uploaded QR image.
  static Future<String?> generateAndUploadQr(
      String orderId, {
        Function(String)? onProgress,
        bool forceRecreate = false,
      }) async {
    try {
      onProgress?.call('Step 1: Checking...');
      // 1. Check if verification record already exists
      // Adding a timeout to prevent hanging on network issues
      final existing = await _supabase
          .from('order_verifications')
          .select()
          .eq('order_id', orderId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      String? token;
      if (existing != null) {
        token = existing['verification_token'];
        if (!forceRecreate && existing['qr_url'] != null) return existing['qr_url'];
      } else {
        // 2. Create new record
        final inserted = await _supabase
            .from('order_verifications')
            .insert({'order_id': orderId})
            .select()
            .single()
            .timeout(const Duration(seconds: 10));
        token = inserted['verification_token'];
      }

      if (token == null) {
        debugPrint('QR Error: Token was null after DB init');
        return null;
      }

      // 3. Generate QR Payload
      final payload = '{"order_id": "$orderId", "token": "$token"}';
      onProgress?.call('Step 2: Rendering QR Image...');

      // 4. Create QR Image bytes
      final qrValidationResult = QrValidator.validate(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        return null;
      }

      final painter = QrPainter.withQr(
        qr: qrValidationResult.qrCode!,
        color: Colors.black, // Color changed to black
        emptyColor: Colors.white,
        gapless: true,
      );

      // Rendering can sometimes be slow, wrap in a timeout or handle failure
      final ui.Image image = await painter.toImage(512);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('QR Error: ByteData is null');
        return null;
      }
      final Uint8List bytes = byteData.buffer.asUint8List();

      // 5. Upload to Supabase Storage
      final fileName = 'qr_$orderId.png';
      final path = 'qr/$fileName';
      onProgress?.call('Step 3: Uploading Qr Codes...');

      await _supabase.storage.from('qrcodes').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
      ).timeout(const Duration(seconds: 20));

      // 6. Get Public URL
      final qrUrl = _supabase.storage.from('qrcodes').getPublicUrl(path);

      // 7. Update DB with the URL
      onProgress?.call('Step 4: Finalizing...');
      await _supabase
          .from('order_verifications')
          .update({'qr_url': qrUrl})
          .eq('order_id', orderId)
          .timeout(const Duration(seconds: 10));

      return qrUrl;
    } catch (e) {
      debugPrint('QR Service Exception: $e');
      return null;
    }
  }

  /// Fetches existing QR info or returns null
  static Future<Map<String, dynamic>?> getVerificationStatus(String orderId) async {
    try {
      return await _supabase
          .from('order_verifications')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }
}