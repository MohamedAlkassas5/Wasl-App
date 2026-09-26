import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/network/image_upload.dart';
import 'package:wasl_app/services/wallet_service.dart';

/// رفع صورة التحويل.
///
/// الباج اللي الاختبارات دي بتمنع رجوعه: `MultipartFile.fromPath` بتبعت
/// `application/octet-stream`، والسيرفر بيقارن النوع المعلَن بـ JPEG/PNG/WebP
/// فبيرفض **أي** سكرين شوت سليم برسالة
/// "Only JPEG, PNG, and WebP image uploads are allowed."
///
/// اللي بيتأكد هنا إن التطبيق بيعلن النوع الحقيقي المقروء من بايتات الملف —
/// **من غير** ما يضعّف تحقق السيرفر: الملف المزيّف بيترفض هنا كمان.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // أصغر ملف صالح من كل نوع، بالتوقيع الحقيقي بتاعه.
  final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
  final jpegBytes = base64Decode(
      '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
      'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
      'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==');
  // RIFF....WEBP — الترويسة كافية للتوقيع.
  final webpBytes = <int>[
    0x52, 0x49, 0x46, 0x46, 0x1a, 0x00, 0x00, 0x00, // RIFF + size
    0x57, 0x45, 0x42, 0x50, // WEBP
    ...List<int>.filled(20, 0),
  ];

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wasl-upload');
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'user_id': 20,
    });
    WaslAuthedHttp.onSignedOut = null;
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<File> write(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  group('قراءة نوع الصورة من البايتات', () {
    test('بيعرف PNG و JPEG و WebP', () {
      expect(WaslImageUpload.sniffImageType(pngBytes), 'image/png');
      expect(WaslImageUpload.sniffImageType(jpegBytes), 'image/jpeg');
      expect(WaslImageUpload.sniffImageType(webpBytes), 'image/webp');
    });

    test('بيرفض اللي مش صورة', () {
      expect(WaslImageUpload.sniffImageType(utf8.encode('<html>hi</html>')),
          isNull);
      expect(WaslImageUpload.sniffImageType(utf8.encode('%PDF-1.7')), isNull);
      expect(WaslImageUpload.sniffImageType(const []), isNull);
      // ملف قصير أوي ما ينفعش يتقرا توقيعه.
      expect(WaslImageUpload.sniffImageType(const [0xFF, 0xD8]), isNull);
    });

    test('الامتداد ما بيغيّرش الحكم — البايتات هي اللي بتقرر', () async {
      // ده بالظبط اللي بيحصل مع الجاليري: اسم ملف بامتداد مالوش علاقة.
      final file = await write('screenshot.png', utf8.encode('<html>no</html>'));
      await expectLater(
        WaslImageUpload.multipartFile('proofImage', file),
        throwsA(isA<WaslImageUploadException>()),
      );
    });
  });

  group('تجهيز الملف للرفع', () {
    test('سكرين شوت PNG بيتبعت بنوع image/png', () async {
      final file = await write('Screenshot_2026.png', pngBytes);
      final part = await WaslImageUpload.multipartFile('proofImage', file);

      expect(part.field, 'proofImage');
      // ده جوهر الإصلاح: مش application/octet-stream.
      expect(part.contentType.mimeType, 'image/png');
      expect(part.length, pngBytes.length);
    });

    test('JPEG بيتبعت بنوع image/jpeg', () async {
      final file = await write('IMG_0042.jpg', jpegBytes);
      final part = await WaslImageUpload.multipartFile('proofImage', file);
      expect(part.contentType.mimeType, 'image/jpeg');
    });

    test('WebP بيتبعت بنوع image/webp', () async {
      final file = await write('shot.webp', webpBytes);
      final part = await WaslImageUpload.multipartFile('proofImage', file);
      expect(part.contentType.mimeType, 'image/webp');
    });

    test('اسم الملف بيتولّد بامتداد مطابق للنوع الحقيقي', () async {
      // الملف اتسمّى .png بس جواه JPEG — زي ما `ImagePicker` بيعمل لما
      // بيعيد الترميز. الاسم المتبعت لازم يتبع البايتات.
      final file = await write('mislabelled.png', jpegBytes);
      final part = await WaslImageUpload.multipartFile('proofImage', file);

      expect(part.contentType.mimeType, 'image/jpeg');
      expect(part.filename, 'upload.jpg');
    });

    test('ملف مش صورة بيترفض برسالة عربية واضحة', () async {
      final file = await write('notes.txt', utf8.encode('مش صورة'));
      await expectLater(
        WaslImageUpload.multipartFile('proofImage', file),
        throwsA(isA<WaslImageUploadException>().having(
            (e) => e.message, 'message', contains('مش صورة صالحة'))),
      );
    });

    test('ملف أكبر من 10 ميجا بيترفض قبل ما يتبعت', () async {
      final huge = <int>[...pngBytes, ...List<int>.filled(11 * 1024 * 1024, 0)];
      final file = await write('huge.png', huge);

      await expectLater(
        WaslImageUpload.multipartFile('proofImage', file),
        throwsA(isA<WaslImageUploadException>()
            .having((e) => e.message, 'message', contains('10 ميجا'))),
      );
    });

    test('ملف فاضي بيترفض', () async {
      final file = await write('empty.png', const []);
      await expectLater(
        WaslImageUpload.multipartFile('proofImage', file),
        throwsA(isA<WaslImageUploadException>()),
      );
    });

    test('ملف مش موجود بيترفض', () async {
      await expectLater(
        WaslImageUpload.multipartFile(
            'proofImage', File('${tempDir.path}/ghost.png')),
        throwsA(isA<WaslImageUploadException>()),
      );
    });
  });

  group('طلب الشحن بيبعت النوع الصح فعلاً', () {
    test('الـ multipart فيه Content-Type: image/png مش octet-stream', () async {
      String? body;
      WaslAuthedHttp.instance = WaslAuthedHttp(
        client: MockClient((request) async {
          // `request.body` بيفك الترميز UTF-8 وبيرمي استثناء على بايتات صورة
          // خام. `latin1` بتخلي كل بايت حرف، فالترويسات النصية تفضل مقروءة.
          body = latin1.decode(request.bodyBytes);
          return http.Response(
            jsonEncode({'success': true, 'request': {}}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final file = await write('Screenshot_transfer.png', pngBytes);
      final result = await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.instapay,
        proofImage: file,
      );

      expect(result['success'], isTrue);
      expect(body, contains('name="proofImage"'));
      expect(body, contains('content-type: image/png'));
      expect(body, isNot(contains('application/octet-stream')));
    });

    test('صورة غير صالحة بتوقف قبل الشبكة، والسبب بيوصل للكابتن', () async {
      var reachedServer = false;
      WaslAuthedHttp.instance = WaslAuthedHttp(
        client: MockClient((request) async {
          reachedServer = true;
          return http.Response('{}', 201);
        }),
      );

      final file = await write('fake.png', utf8.encode('<html>nope</html>'));
      final result = await WaslWalletService().submitTopUp(
        amount: 100,
        method: WaslTopUpMethod.vodafoneCash,
        proofImage: file,
      );

      expect(result['success'], isFalse);
      expect(result['message'], contains('صورة صالحة'));
      // ما اتبعتش أصلاً — بيوفر على الكابتن رسالة خطأ إنجليزية من السيرفر.
      expect(reachedServer, isFalse);
    });
  });
}
