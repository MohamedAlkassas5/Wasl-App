import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/config/api_config.dart';

/// Calls against the NestJS backend for everything account-related.
///
/// Phone verification is **not** here — it lives in [WhatsappOtpService],
/// which talks to `/auth/otp/*`. Firebase phone auth used to sit in this file;
/// it was client-side only, so the server had no way to tell a verified phone
/// from an invented one. The server now owns that decision and `/auth/register`
/// rejects any phone that hasn't passed a WhatsApp code.
class FlutterAuthService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  // 🎯 1️⃣ دالة ترحيل البيانات ورفع المستندات إلى سيرفر NestJS الرئيسي
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    File? idFront,
    File? idBack,
    File? storeLogo,
    String? storeName,
    String? storeType,
    File? vehicleImage,
    String? vehicleType,
    String? firebaseUid,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    print("📡 [WASL DEBUG] ترحيل البيانات وحفظ الحساب اللوجستي في الـ NestJS عبر: $url");

    try {
      var request = http.MultipartRequest('POST', url);
      final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();

      request.fields['name'] = name.trim();
      request.fields['phone'] = cleanPhone;
      request.fields['password'] = password;
      request.fields['role'] = role.trim();
      if (firebaseUid != null) request.fields['firebaseUid'] = firebaseUid;

      if (storeName != null && storeName.isNotEmpty) request.fields['storeName'] = storeName.trim();
      if (storeType != null && storeType.isNotEmpty) request.fields['storeType'] = storeType.trim();
      if (vehicleType != null && vehicleType.isNotEmpty) request.fields['vehicleType'] = vehicleType.trim();

      request.headers.addAll({
        'Accept': 'application/json',
      });

      if (idFront != null && await idFront.exists()) {
        request.files.add(await http.MultipartFile.fromPath('idFront', idFront.path));
      }
      if (idBack != null && await idBack.exists()) {
        request.files.add(await http.MultipartFile.fromPath('idBack', idBack.path));
      }
      if (storeLogo != null && await storeLogo.exists()) {
        request.files.add(await http.MultipartFile.fromPath('storeLogo', storeLogo.path));
      }
      if (vehicleImage != null && await vehicleImage.exists()) {
        request.files.add(await http.MultipartFile.fromPath('vehicleImage', vehicleImage.path));
      }

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      final decodedData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 🔐 السيرفر بيرجّع توكن مع التسجيل — لازم يتخزن هنا، لأن شاشة الانتظار
        // (المندوب/المتجر) بتسأل /users/status وده مسار محمي بالتوكن.
        final String token = decodedData['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
        }
        return {'success': true, 'data': decodedData};
      } else {
        return {'success': false, 'message': _firstMessage(decodedData) ?? 'فشل حفظ البيانات والمستندات في السيرفر الرئيسي'};
      }
    } catch (e) {
      print("💥 [WASL DEBUG] عطل أثناء رفع المستندات: $e");
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر الرئيسي: $e'};
    }
  }

  // 🎯 2️⃣ دالة تسجيل الدخول (Login) تضرب الـ NestJS مباشرة
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': cleanPhone,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final decodedData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': decodedData};
      } else {
        return {'success': false, 'message': _firstMessage(decodedData) ?? 'بيانات الدخول غير صحيحة'};
      }
    } catch (e) {
      return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
    }
  }

  /// Nest's validation pipe returns `message` as a list of strings; everything
  /// else returns a plain string. Flatten both so the UI always has one line.
  static String? _firstMessage(dynamic decoded) {
    if (decoded is! Map) return null;
    final message = decoded['message'];
    if (message is List && message.isNotEmpty) return message.first.toString();
    if (message is String) return message;
    return null;
  }

  // 🗑️ `socialLoginCheck` اتشالت مع الراوت بتاعها: /auth/social-check كان بيدّي
  // توكن صالح لأي حساب بمجرد معرفة الإيميل، والتطبيق كان بيبعت إيميل ثابت
  // متكتوب في الكود. لو الدخول الاجتماعي رجع، لازم يتحقق من Firebase ID token
  // على السيرفر (firebase-admin verifyIdToken).

  // 🎯 3️⃣ دالة سحب التصنيفات الحقيقية من السيرفر لصالح شاشة الرئيسية
  Future<Map<String, dynamic>> getCategories() async {
    final url = Uri.parse('$baseUrl/categories');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      final decodedData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': decodedData};
      }
      return {'success': false, 'message': 'فشل جلب التصنيفات'};
    } catch (e) {
      return {'success': false, 'message': 'عطل في الاتصال: $e'};
    }
  }

  // 🎯 4️⃣ دالة جلب المتاجر القريبة الفردية بالـ GPS وفرز الأقرب تصاعدياً
  // 🏪 السيرفر بيرجّع المتاجر الحقيقية المعتمدة من الأدمن بس؛ لو مفيش، بترجع مصفوفة فاضية.
  Future<Map<String, dynamic>> getNearbyStores({required double lat, required double lng}) async {
    final url = Uri.parse('$baseUrl/stores/nearby?lat=$lat&lng=$lng');
    try {
      final response = await http.get(
        url,
        headers: await WaslApiConfig.authHeaders(),
      ).timeout(const Duration(seconds: 12));

      final decodedData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // 🎯 [تحديث مصلح]: بما أن السيرفر يرجع كائن يحتوي على { success: true, data: [...] }
        // وإحنا بنجيب البيانات بـ getRawMany()، الـ decodedData['data'] هو اللي جواه المصفوفة مباشرة.
        return {'success': true, 'data': decodedData['data'] ?? decodedData};
      }
      return {'success': false, 'message': 'فشل جلب المتاجر القريبة'};
    } catch (e) {
      return {'success': false, 'message': 'عطل في الاتصال بالشبكة: $e'};
    }
  }

  // 🎯 5️⃣ الفحص اللحظي لحالة الحساب (لصالح شاشة الانتظار)
  // 🔐 الحساب بيتحدد من التوكن نفسه، مش من رقم الهاتف في الرابط —
  // الرابط القديم كان بيسمح لأي حد يستعلم عن بيانات أي رقم.
  Future<Map<String, dynamic>> checkUserStatus(String phone) async {
    final url = Uri.parse('$baseUrl/users/status');

    try {
      final response = await http.get(
        url,
        headers: await WaslApiConfig.authHeaders(),
      ).timeout(const Duration(seconds: 15));

      final decodedData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': decodedData['status'],
          'role': decodedData['role'] ?? 'customer',
          'name': decodedData['name'] ?? '',
          'id': decodedData['id'],
          'adminNotes': decodedData['adminNotes'] ?? '',
        };
      } else {
        return {'success': false, 'message': decodedData['message'] ?? 'فشل تحديث الحالة'};
      }
    } catch (e) {
      return {'success': false, 'message': 'عطل في الشبكة: $e'};
    }
  }

  // 🎯 6️⃣ دالة حذف الحساب نهائياً
  Future<Map<String, dynamic>> deleteUserAccount(String phone) async {
    final cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
    final url = Uri.parse('$baseUrl/auth/$cleanPhone');

    try {
      // 🔐 السيرفر بيحذف صاحب التوكن نفسه؛ الرقم في الرابط بقى للتوافق بس.
      final response = await http.delete(
        url,
        headers: await WaslApiConfig.authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'تم حذف الحساب وبياناتك نهائياً من السيرفر.'
        };
      } else {
        final decodedData = jsonDecode(response.body);
        return {
          'success': false,
          'message': decodedData['message'] ?? 'فشلت عملية حذف الحساب من السيرفر'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'حدث خطأ أثناء الاتصال بالشبكة: $e'
      };
    }
  }
}





// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart'; // 🎯 استيراد حزمة الفايربيز المعتمدة للـ OTP
//
// class FlutterAuthService {
//   // 💡 لو شغال على محاكي أندرويد افتراضي سيب الـ IP زي ما هو 10.0.2.2
//   // لو شغال على سيرفر Railway لايف، استخدم الرابط السحابي الأسفل مباشرة.
//   static const String baseUrl = 'http://10.0.2.2:3000';
//   // static const String baseUrl = 'https://wasl-backend-production-97ef.up.railway.app';
//
//   final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
//
//   // 🎯 1️⃣ دالة طلب وإرسال الـ OTP عبر Firebase لأي رقم هاتف في العالم مجاناً لايف
//   Future<void> sendFirebaseOtp({
//     required String phone,
//     required Function(String verificationId) onCodeSent,
//     required Function(FirebaseAuthException e) onFailed,
//   }) async {
//     print("📡 [WASL DEBUG] جاري طلب كود OTP من فايربيز للرقم: $phone");
//     try {
//       await _firebaseAuth.verifyPhoneNumber(
//         phoneNumber: phone,
//         timeout: const Duration(seconds: 60),
//         verificationCompleted: (PhoneAuthCredential credential) async {},
//         verificationFailed: (FirebaseAuthException e) {
//           print("❌ [WASL DEBUG] فشل إرسال الـ OTP من فايربيز: ${e.message}");
//           onFailed(e);
//         },
//         codeSent: (String verificationId, int? resendToken) {
//           print("📥 [WASL DEBUG] تم إرسال الكود بنجاح! الـ VerificationId هو: $verificationId");
//           onCodeSent(verificationId);
//         },
//         codeAutoRetrievalTimeout: (String verificationId) {},
//       );
//     } catch (e) {
//       print("💥 [WASL DEBUG] عطل مفاجئ أثناء الاتصال بفايربيز: $e");
//     }
//   }
//
//   // 🎯 2️⃣ دالة التحقق من الـ OTP عبر فايربيز، وتخزين الحساب في NestJS بعد النجاح فوراً
//   Future<Map<String, dynamic>> verifyOtpAndRegisterInNest({
//     required String verificationId,
//     required String smsCode,
//     required String name,
//     required String phone,
//     required String password,
//     required String role,
//     File? idFront,
//     File? idBack,
//     File? storeLogo,
//     String? storeName,
//     String? storeType,
//     File? vehicleImage,
//     String? vehicleType,
//   }) async {
//     try {
//       print("🔐 [WASL DEBUG] جاري التحقق من كود الـ OTP ($smsCode) عبر سيرفرات فايربيز...");
//
//       PhoneAuthCredential credential = PhoneAuthProvider.credential(
//         verificationId: verificationId,
//         smsCode: smsCode.trim(),
//       );
//
//       UserCredential userCred = await _firebaseAuth.signInWithCredential(credential);
//       String? firebaseUid = userCred.user?.uid;
//
//       if (firebaseUid == null) {
//         return {'success': false, 'message': 'فشل التحقق من الهوية عبر فايربيز.'};
//       }
//
//       print("✅ [WASL DEBUG] تم التحقق بنجاح من فايربيز! الـ UID هو: $firebaseUid");
//
//       return await register(
//         name: name,
//         phone: phone,
//         password: password,
//         role: role,
//         idFront: idFront,
//         idBack: idBack,
//         storeLogo: storeLogo,
//         storeName: storeName,
//         storeType: storeType,
//         vehicleImage: vehicleImage,
//         vehicleType: vehicleType,
//         firebaseUid: firebaseUid,
//       );
//
//     } on FirebaseAuthException catch (fbError) {
//       print("❌ [WASL DEBUG] خطأ فايربيز: ${fbError.code} - ${fbError.message}");
//       return {
//         'success': false,
//         'message': fbError.code == 'invalid-verification-code' ? 'كود التحقق غير صحيح، يرجى المحاولة مرة أخرى' : 'فشل التحقق: ${fbError.message}'
//       };
//     } catch (e) {
//       print("💥 [WASL DEBUG] عطل غير متوقع: $e");
//       return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
//     }
//   }
//
//   // 🎯 3️⃣ دالة ترحيل البيانات ورفع المستندات إلى سيرفر NestJS الرئيسي
//   Future<Map<String, dynamic>> register({
//     required String name,
//     required String phone,
//     required String password,
//     required String role,
//     File? idFront,
//     File? idBack,
//     File? storeLogo,
//     String? storeName,
//     String? storeType,
//     File? vehicleImage,
//     String? vehicleType,
//     String? firebaseUid,
//   }) async {
//     final url = Uri.parse('$baseUrl/auth/register');
//     print("📡 [WASL DEBUG] ترحيل البيانات وحفظ الحساب اللوجستي في الـ NestJS عبر: $url");
//
//     try {
//       var request = http.MultipartRequest('POST', url);
//       final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//
//       request.fields['name'] = name.trim();
//       request.fields['phone'] = cleanPhone;
//       request.fields['password'] = password;
//       request.fields['role'] = role.trim();
//       if (firebaseUid != null) request.fields['firebaseUid'] = firebaseUid;
//
//       if (storeName != null && storeName.isNotEmpty) request.fields['storeName'] = storeName.trim();
//       if (storeType != null && storeType.isNotEmpty) request.fields['storeType'] = storeType.trim();
//       if (vehicleType != null && vehicleType.isNotEmpty) request.fields['vehicleType'] = vehicleType.trim();
//
//       request.headers.addAll({
//         'Accept': 'application/json',
//       });
//
//       if (idFront != null && await idFront.exists()) {
//         request.files.add(await http.MultipartFile.fromPath('idFront', idFront.path));
//       }
//       if (idBack != null && await idBack.exists()) {
//         request.files.add(await http.MultipartFile.fromPath('idBack', idBack.path));
//       }
//       if (storeLogo != null && await storeLogo.exists()) {
//         request.files.add(await http.MultipartFile.fromPath('storeLogo', storeLogo.path));
//       }
//       if (vehicleImage != null && await vehicleImage.exists()) {
//         request.files.add(await http.MultipartFile.fromPath('vehicleImage', vehicleImage.path));
//       }
//
//       var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
//       var response = await http.Response.fromStream(streamedResponse);
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 201 || response.statusCode == 200) {
//         return {'success': true, 'data': decodedData};
//       } else {
//         return {'success': false, 'message': decodedData['message'] ?? 'فشل حفظ البيانات والمستندات في السيرفر الرئيسي'};
//       }
//     } catch (e) {
//       print("💥 [WASL DEBUG] عطل أثناء رفع المستندات: $e");
//       return {'success': false, 'message': 'فشل الاتصال بالسيرفر الرئيسي: $e'};
//     }
//   }
//
//   // 🎯 4️⃣ دالة تسجيل الدخول (Login) تضرب الـ NestJS مباشرة
//   Future<Map<String, dynamic>> login({
//     required String phone,
//     required String password,
//   }) async {
//     final url = Uri.parse('$baseUrl/auth/login');
//     final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode({
//           'phone': cleanPhone,
//           'password': password,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 201 || response.statusCode == 200) {
//         return {'success': true, 'data': decodedData};
//       } else {
//         return {'success': false, 'message': decodedData['message'] ?? 'بيانات الدخول غير صحيحة'};
//       }
//     } catch (e) {
//       return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
//     }
//   }
//
//   // 🎯 5️⃣ [جديد ولايف] دالة سحب التصنيفات الحقيقية من السيرفر لصالح شاشة الرئيسية
//   Future<Map<String, dynamic>> getCategories() async {
//     final url = Uri.parse('$baseUrl/categories');
//     try {
//       final response = await http.get(url, headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//       }).timeout(const Duration(seconds: 10));
//
//       final decodedData = jsonDecode(response.body);
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': decodedData};
//       }
//       return {'success': false, 'message': 'فشل جلب التصنيفات'};
//     } catch (e) {
//       return {'success': false, 'message': 'عطل في الاتصال: $e'};
//     }
//   }
//
//   // 🎯 6️⃣ [جديد ولايف] دالة جلب المتاجر القريبة الفردية بالـ GPS وفرز الأقرب تصاعدياً
//   Future<Map<String, dynamic>> getNearbyStores({required double lat, required double lng}) async {
//     final url = Uri.parse('$baseUrl/stores/nearby?lat=$lat&lng=$lng');
//     try {
//       final response = await http.get(url, headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//       }).timeout(const Duration(seconds: 12));
//
//       final decodedData = jsonDecode(response.body);
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': decodedData};
//       }
//       return {'success': false, 'message': 'فشل جلب المتاجر القريبة'};
//     } catch (e) {
//       return {'success': false, 'message': 'عطل في الاتصال بالشبكة: $e'};
//     }
//   }
//
//   // 🎯 7️⃣ الفحص اللحظي لحالة الحساب (لصالح شاشة الانتظار)
//   Future<Map<String, dynamic>> checkUserStatus(String phone) async {
//     final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//     final url = Uri.parse('$baseUrl/users/status?phone=$cleanPhone');
//
//     try {
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//       ).timeout(const Duration(seconds: 15));
//
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'status': decodedData['status'],
//           'adminNotes': decodedData['adminNotes'] ?? '',
//         };
//       } else {
//         return {'success': false, 'message': decodedData['message'] ?? 'فشل تحديث الحالة'};
//       }
//     } catch (e) {
//       return {'success': false, 'message': 'عطل في الشبكة: $e'};
//     }
//   }
//
//   // 🎯 8️⃣ دالة حذف الحساب
//   Future<Map<String, dynamic>> deleteUserAccount(String phone) async {
//     final cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//     final url = Uri.parse('$baseUrl/auth/$cleanPhone');
//
//     try {
//       final response = await http.delete(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200 || response.statusCode == 204) {
//         return {
//           'success': true,
//           'message': 'تم حذف الحساب وبياناتك نهائياً من السيرفر.'
//         };
//       } else {
//         final decodedData = jsonDecode(response.body);
//         return {
//           'success': false,
//           'message': decodedData['message'] ?? 'فشلت عملية حذف الحساب من السيرفر'
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'message': 'حدث خطأ أثناء الاتصال بالشبكة: $e'
//       };
//     }
//   }
// }




































//
// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
//
// class FlutterAuthService {
//   // 🚀 الرابط العالمي المعتمد على Railway (بدون سلاش نهائي في الآخر)
//   static const String baseUrl = 'https://wasl-backend-production-97ef.up.railway.app';
//
//   // 1️⃣ دالة تسجيل الحسابات الشاملة (عميل، مندوب، متجر)
//   Future<Map<String, dynamic>> register({
//     required String name,
//     required String phone,
//     required String password,
//     required String role,
//     File? idFront,
//     File? idBack,
//     File? storeLogo,
//     String? storeName,
//     String? storeType,
//     File? vehicleImage,
//     String? vehicleType,
//   }) async {
//     final url = Uri.parse('$baseUrl/auth/register');
//     print("🚀 [WASL DEBUG] جاري تحضير طلب التسجيل إلى: $url");
//
//     var request = http.MultipartRequest('POST', url);
//
//     // 🛡️ الحل السحري: تنظيف رقم الهاتف من أي علامات تعطل الـ Boundary في الـ Emulator
//     final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//
//     // إضافة الحقول النصية الأساسية بعد التنظيف
//     request.fields['name'] = name.trim();
//     request.fields['phone'] = cleanPhone;
//     request.fields['password'] = password;
//     request.fields['role'] = role.trim();
//
//     // إضافة الحقول الإضافية بناءً على نوع الحساب
//     if (storeName != null && storeName.isNotEmpty) request.fields['storeName'] = storeName.trim();
//     if (storeType != null && storeType.isNotEmpty) request.fields['storeType'] = storeType.trim();
//     if (vehicleType != null && vehicleType.isNotEmpty) request.fields['vehicleType'] = vehicleType.trim();
//
//     // تأمين الـ Headers للـ Multipart لضمان قبول السيرفر السحابي للطلب
//     request.headers.addAll({
//       'Accept': 'application/json',
//     });
//
//     print("📝 [WASL DEBUG] الحقول النصية المرسلة: ${request.fields}");
//
//     // إرفاق ملفات الصور بشكل آمن وديناميكي
//     try {
//       if (idFront != null && await idFront.exists()) {
//         print("📸 [WASL DEBUG] جاري إرفاق صورة الهوية أمامي: ${idFront.path}");
//         request.files.add(await http.MultipartFile.fromPath('idFront', idFront.path));
//       }
//       if (idBack != null && await idBack.exists()) {
//         print("📸 [WASL DEBUG] جاري إرفاق صورة الهوية خلفي: ${idBack.path}");
//         request.files.add(await http.MultipartFile.fromPath('idBack', idBack.path));
//       }
//       if (storeLogo != null && await storeLogo.exists()) {
//         print("📸 [WASL DEBUG] جاري إرفاق لوجو المتجر: ${storeLogo.path}");
//         request.files.add(await http.MultipartFile.fromPath('storeLogo', storeLogo.path));
//       }
//       if (vehicleImage != null && await vehicleImage.exists()) {
//         print("📸 [WASL DEBUG] جاري إرفاق صورة المركبة: ${vehicleImage.path}");
//         request.files.add(await http.MultipartFile.fromPath('vehicleImage', vehicleImage.path));
//       }
//     } catch (fileError) {
//       print("❌ [WASL DEBUG] خطأ أثناء قراءة ملفات الصور: $fileError");
//       return {'success': false, 'message': 'خطأ في معالجة ملفات الصور الجاري رفعها'};
//     }
//
//     try {
//       print("📡 [WASL DEBUG] جاري إرسال الـ Multipart Request للسيرفر... (انتظر الرد)");
//
//       // إرسال الطلب واستقبال الـ Stream مع مهلة 30 ثانية حماية
//       var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
//       print("📥 [WASL DEBUG] السيرفر استجاب فوراً بـ statusCode: ${streamedResponse.statusCode}");
//
//       // تحويل الـ Stream إلى Response عادي لقراءة الـ Body
//       var response = await http.Response.fromStream(streamedResponse);
//       print("📄 [WASL DEBUG] نص الـ Response القادم من السيرفر: ${response.body}");
//
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 201 || response.statusCode == 200) {
//         print("✅ [WASL DEBUG] تم التسجيل بنجاح في قاعدة البيانات السحابية!");
//         return {'success': true, 'data': decodedData};
//       } else {
//         print("⚠️ [WASL DEBUG] السيرفر رفض الطلب لسبب منطقي. كود: ${response.statusCode}");
//         return {
//           'success': false,
//           'message': decodedData is Map ? (decodedData['message'] ?? 'حدث خطأ في البيانات المرسلة') : 'رفض السيرفر إتمام العملية'
//         };
//       }
//     } catch (e) {
//       print("💥 [WASL DEBUG] حدث خطأ أو تعليق شبكة أثناء الإرسال: $e");
//       return {'success': false, 'message': 'فشل الاتصال بالسيرفر، تأكد من الشبكة: $e'};
//     }
//   }
//
//   // 2️⃣ دالة تسجيل الدخول (Login)
//   Future<Map<String, dynamic>> login({
//     required String phone,
//     required String password,
//   }) async {
//     final url = Uri.parse('$baseUrl/auth/login');
//     print("🚀 [WASL DEBUG] جاري محاولة تسجيل الدخول إلى: $url");
//
//     // تنظيف رقم الهاتف أيضاً في تسجيل الدخول لتطابق البيانات المرسلة عند التسجيل
//     final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//         body: jsonEncode({
//           'phone': cleanPhone,
//           'password': password,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       print("📥 [WASL DEBUG] استجابة الدخول statusCode: ${response.statusCode}");
//       print("📄 [WASL DEBUG] محتوى استجابة الدخول: ${response.body}");
//
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         print("✅ [WASL DEBUG] تسجيل الدخول ناجح!");
//         return {'success': true, 'data': decodedData};
//       } else {
//         return {
//           'success': false,
//           'message': decodedData is Map ? (decodedData['message'] ?? 'بيانات الدخول غير صحيحة') : 'فشل تسجيل الدخول'
//         };
//       }
//     } catch (e) {
//       print("💥 [WASL DEBUG] خطأ في اتصال تسجيل الدخول: $e");
//       return {'success': false, 'message': 'فشل الاتصال بالسيرفر: $e'};
//     }
//   }
//
//   // 3️⃣ الفحص اللحظي لحالة الحساب (لصالح شاشة الانتظار)
//   Future<Map<String, dynamic>> checkUserStatus(String phone) async {
//     final String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').trim();
//     final url = Uri.parse('$baseUrl/users/status?phone=$cleanPhone');
//     print("🚀 [WASL DEBUG] جاري فحص حالة الحساب من المسار: $url");
//
//     try {
//       final response = await http.get(
//         url,
//         headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       ).timeout(const Duration(seconds: 15));
//
//       print("📥 [WASL DEBUG] استجابة فحص الحالة statusCode: ${response.statusCode}");
//
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'status': decodedData['status'], // active, pending, rejected
//           'adminNotes': decodedData['adminNotes'] ?? '',
//         };
//       } else {
//         return {
//           'success': false,
//           'message': decodedData is Map ? (decodedData['message'] ?? 'فشل تحديث الحالة') : 'خطأ في جلب البيانات'
//         };
//       }
//     } catch (e) {
//       print("💥 [WASL DEBUG] خطأ شبكة أثناء فحص الحالة: $e");
//       return {'success': false, 'message': 'عطل في الشبكة: $e'};
//     }
//   }
// }