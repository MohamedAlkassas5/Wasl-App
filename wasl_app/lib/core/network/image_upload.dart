import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// بناء ملف الصورة اللي بيتبعت في الـ multipart، بنوع محتوى صحيح.
///
/// ## المشكلة اللي الملف ده بيحلها
///
/// `http.MultipartFile.fromPath` من غير `contentType` بتبعت
/// `application/octet-stream` — دي القيمة الافتراضية في الحزمة، مش استنتاج من
/// امتداد الملف. والسيرفر (`imageUploadPolicy.fileFilter`) بيقارن الـ mimetype
/// المُعلَن بـ JPEG/PNG/WebP، فبيرفض **أي** صورة سليمة بالرسالة:
///
///   "Only JPEG, PNG, and WebP image uploads are allowed."
///
/// يعني سكرين شوت عادي من الجاليري كان بيترفض، والغلط في التطبيق مش في
/// السيرفر. الحل إن التطبيق يعلن النوع الصح.
///
/// ## ليه بنقرا البايتات مش الامتداد
///
/// الامتداد اللي بييجي من الجاليري ممكن يكون غلط أو ناقص، و`ImagePicker`
/// بيعيد ترميز الصورة أصلاً لما `imageQuality` يتحدد — فـ PNG ممكن يرجع JPEG.
/// فبنستنتج النوع من التوقيع في أول بايتات الملف، بنفس منطق `sniffImageType`
/// على السيرفر. النتيجة إن اللي بنعلنه دايماً بيطابق اللي جوه الملف.
///
/// ## ده مش إضعاف للتحقق
///
/// السيرفر لسه بيقرا البايتات بنفسه ويرفض أي ملف مش صورة — الكلام ده بيخلي
/// الطلب السليم يعدّي، مش بيخلي الطلب الوحش يعدّي. ملف مزيّف هيترفض هنا
/// (قبل ما يتبعت أصلاً) وهيترفض على السيرفر كمان لو حد عدّى على التطبيق.
class WaslImageUpload {
  /// نفس الحد الموجود في `imageUploadPolicy` على السيرفر (10 ميجا).
  static const int maxBytes = 10 * 1024 * 1024;

  /// الأنواع اللي السيرفر بيقبلها، والامتداد بتاع كل واحد.
  static const Map<String, String> _extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// نوع الصورة الحقيقي من توقيع البايتات، أو null لو مش نوع مدعوم.
  ///
  /// مطابق لـ `sniffImageType` في `src/common/upload-policy.ts`.
  static String? sniffImageType(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length >= 8) {
      var match = true;
      for (var i = 0; i < png.length; i++) {
        if (bytes[i] != png[i]) {
          match = false;
          break;
        }
      }
      if (match) return 'image/png';
    }

    // RIFF....WEBP
    if (bytes.length >= 12) {
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      final webp = String.fromCharCodes(bytes.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') return 'image/webp';
    }

    return null;
  }

  /// بيجهّز الصورة للرفع، أو بيرمي [WaslImageUploadException] برسالة عربية
  /// واضحة لو الملف مش صالح — عشان الكابتن يعرف السبب بدل ما الطلب يفشل
  /// برسالة إنجليزية من السيرفر.
  static Future<http.MultipartFile> multipartFile(
    String field,
    File file,
  ) async {
    if (!await file.exists()) {
      throw const WaslImageUploadException('الملف المختار غير موجود');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const WaslImageUploadException('الملف المختار فاضي');
    }
    if (bytes.length > maxBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw WaslImageUploadException(
        'حجم الصورة $mb ميجا، والحد الأقصى 10 ميجا. جرّب صورة أصغر.',
      );
    }

    final contentType = sniffImageType(bytes);
    if (contentType == null) {
      throw const WaslImageUploadException(
        'الملف المختار مش صورة صالحة. اختار صورة JPG أو PNG أو WebP.',
      );
    }

    final parts = contentType.split('/');
    return http.MultipartFile.fromBytes(
      field,
      bytes,
      // الاسم بيتولّد هنا؛ السيرفر بيتجاهله ويولّد اسمه بنفسه، بس اسم فيه
      // امتداد صحيح بيمنع أي وسيط في النص يخمّن نوع تاني.
      filename: 'upload.${_extensions[contentType]}',
      contentType: MediaType(parts[0], parts[1]),
    );
  }
}

/// سبب رفض الصورة قبل ما تتبعت، برسالة جاهزة للعرض.
class WaslImageUploadException implements Exception {
  const WaslImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
