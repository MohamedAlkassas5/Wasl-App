// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:wasl_app/core/config/api_config.dart';
// import 'package:http/http.dart' as http;
//
// class FlutterOrdersService {
//   static String get baseUrl => WaslApiConfig.baseUrl;
//
//   Future<Map<String, String>> _headers() => WaslApiConfig.authHeaders();
//
//   Future<Map<String, dynamic>> createOrder({
//     required int customerId,
//     required String customerName,
//     required String customerPhone,
//     required String categoryType,
//     String? storeName,
//     required String itemsDescription,
//     required String deliveryAddressText,
//     required double itemsPrice,
//     required double latitude,
//     required double longitude,
//     double? pickupLatitude,
//     double? pickupLongitude,
//     String? pickupAddressText,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/create');
//     try {
//       final response = await http.post(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({
//           'customerId': customerId,
//           'customerName': customerName,
//           'customerPhone': customerPhone,
//           'categoryType': categoryType,
//           'storeName': storeName ?? 'غير محدد',
//           'itemsDescription': itemsDescription,
//           'deliveryAddressText': deliveryAddressText,
//           'itemsPrice': itemsPrice,
//           'latitude': latitude,
//           'longitude': longitude,
//           if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
//           if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
//           if (pickupAddressText != null) 'pickupAddressText': pickupAddressText,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.body.isEmpty) {
//         return {'success': false, 'message': 'لا توجد استجابة من السيرفر'};
//       }
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': decodedData};
//       }
//       return {'success': false, 'message': decodedData['message'] ?? 'فشل إنشاء الطلب'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال، السيرفر بطيء.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ في الاتصال: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> createOrderWithImage({
//     required int customerId,
//     required String customerName,
//     required String customerPhone,
//     required String categoryType,
//     String? storeName,
//     required String itemsDescription,
//     required String deliveryAddressText,
//     double itemsPrice = 0,
//     required double latitude,
//     required double longitude,
//     File? itemsImage,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/create');
//     try {
//       final request = http.MultipartRequest('POST', url);
//       request.fields['customerId'] = customerId.toString();
//       request.fields['customerName'] = customerName;
//       request.fields['customerPhone'] = customerPhone;
//       request.fields['categoryType'] = categoryType;
//       request.fields['storeName'] = storeName ?? 'غير محدد';
//       request.fields['itemsDescription'] = itemsDescription;
//       request.fields['deliveryAddressText'] = deliveryAddressText;
//       request.fields['itemsPrice'] = itemsPrice.toString();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();
//
//       final headers = await _headers();
//       headers.remove('Content-Type');
//       request.headers.addAll(headers);
//
//       if (itemsImage != null && await itemsImage.exists()) {
//         request.files.add(await http.MultipartFile.fromPath('itemsImage', itemsImage.path));
//       }
//
//       final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
//       final response = await http.Response.fromStream(streamedResponse);
//       final decodedData = jsonDecode(response.body);
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': decodedData};
//       }
//       return {'success': false, 'message': decodedData['message'] ?? 'فشل إنشاء الطلب'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال، السيرفر بطيء.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ في الاتصال: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> submitOffer({
//     required int orderId,
//     required int driverId,
//     required double deliveryFee,
//     required int estimatedTime,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/$orderId/submit-offer');
//     try {
//       final response = await http.post(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({
//           'driverId': driverId,
//           'deliveryFee': deliveryFee,
//           'estimatedTime': estimatedTime,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       final decodedData = jsonDecode(response.body);
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': decodedData};
//       }
//       return {'success': false, 'message': decodedData['message'] ?? 'فشل تقديم العرض'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getOrderOffers(int orderId) async {
//     final url = Uri.parse('$baseUrl/orders/$orderId/offers');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
//       if (response.statusCode == 200) {
//         return {'success': true, 'offers': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب العروض'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> acceptOffer({required int orderId, required int offerId}) async {
//     final url = Uri.parse('$baseUrl/orders/$orderId/offers/$offerId/accept');
//     try {
//       final response = await http.post(url, headers: await _headers()).timeout(const Duration(seconds: 15));
//       final decodedData = jsonDecode(response.body);
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final details = await getOrderCustomerDetails(orderId);
//         return {
//           'success': true,
//           'message': 'تم قبول العرض بنجاح',
//           'order': details['success'] == true ? details['data'] : null,
//         };
//       }
//       return {'success': false, 'message': decodedData['message'] ?? 'فشل قبول العرض'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> updateOrderStatus({
//     required int orderId,
//     required String status,
//     double? itemsPrice,
//     String? invoiceImageUrl,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/$orderId/status?status=$status');
//     try {
//       final response = await http.patch(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({
//           if (itemsPrice != null) 'itemsPrice': itemsPrice,
//           if (invoiceImageUrl != null) 'invoiceImageUrl': invoiceImageUrl,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل التحديث'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getAvailableOrders({int? driverId}) async {
//     final url = Uri.parse('$baseUrl/orders/available${driverId != null ? '?driverId=$driverId' : ''}');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب الطلبات'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getCustomerOrders(int customerId) async {
//     final url = Uri.parse('$baseUrl/orders/customer/$customerId');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب طلباتك'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'انتهى وقت الاتصال.'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getDriverOnlineStatus(int driverId) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId/online-status');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
//       if (response.statusCode == 200) {
//         return {'success': true, ...jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب حالة الاتصال'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> setDriverOnlineStatus({
//     required int driverId,
//     required bool isOnline,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId/online-status');
//     try {
//       final response = await http.patch(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({'isOnline': isOnline}),
//       ).timeout(const Duration(seconds: 10));
//
//       final decoded = jsonDecode(response.body);
//       if (response.statusCode == 200) {
//         return {'success': true, ...decoded};
//       }
//       return {'success': false, 'message': decoded['message'] ?? 'فشل تحديث الحالة'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getDriverDashboardStats(int driverId) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId/dashboard-stats');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
//       if (response.statusCode == 200) {
//         return {'success': true, ...jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب إحصائيات اللوحة'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getOrderCustomerDetails(int orderId) async {
//     final url = Uri.parse('$baseUrl/orders/$orderId/customer-details');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 12));
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب تفاصيل الطلب'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> rateDriver({
//     required int driverId,
//     required int rating,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId/rate');
//     try {
//       final response = await http.post(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({'rating': rating}),
//       ).timeout(const Duration(seconds: 10));
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل إرسال التقييم'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> requestDriverTopUp({
//     required int driverId,
//     required double amount,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId/topup-request');
//     try {
//       final response = await http.patch(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({'amount': amount}),
//       ).timeout(const Duration(seconds: 15));
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل طلب الشحن'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> processPaymentWebhook({
//     required int driverId,
//     required double amount,
//   }) async {
//     final url = Uri.parse('$baseUrl/orders/payment/webhook');
//     try {
//       final response = await http.post(
//         url,
//         headers: await _headers(),
//         body: jsonEncode({
//           'driverId': driverId,
//           'amount': amount,
//           'status': 'success',
//         }),
//       ).timeout(const Duration(seconds: 15));
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل تأكيد الشحن'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<Map<String, dynamic>> getUserNotifications(int userId) async {
//     final url = Uri.parse('$baseUrl/orders/user/$userId/notifications');
//     try {
//       final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
//       if (response.statusCode == 200) {
//         return {'success': true, 'data': jsonDecode(response.body)};
//       }
//       return {'success': false, 'message': 'فشل جلب الإشعارات'};
//     } catch (e) {
//       return {'success': false, 'message': 'خطأ: $e'};
//     }
//   }
//
//   Future<bool> deleteNotification(int id) async {
//     final url = Uri.parse('$baseUrl/orders/notifications/$id');
//     try {
//       final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 10));
//       return response.statusCode >= 200 && response.statusCode < 300;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   Future<bool> clearAllNotifications(int userId) async {
//     final url = Uri.parse('$baseUrl/orders/user/$userId/notifications/clear-all');
//     try {
//       final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 10));
//       return response.statusCode >= 200 && response.statusCode < 300;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   Future<bool> deleteDriverAccount(int driverId) async {
//     final url = Uri.parse('$baseUrl/orders/driver/$driverId');
//     try {
//       final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 15));
//       return response.statusCode >= 200 && response.statusCode < 300;
//     } catch (_) {
//       return false;
//     }
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:wasl_app/core/config/api_config.dart';
import 'package:http/http.dart' as http;

class FlutterOrdersService {
  static String get baseUrl => WaslApiConfig.baseUrl;

  Future<Map<String, String>> _headers() => WaslApiConfig.authHeaders();

  // 🎯 1️⃣ إنشاء طلب جديد (نصوص وبدونات صور)
  Future<Map<String, dynamic>> createOrder({
    required int customerId,
    required String customerName,
    required String customerPhone,
    required String categoryType,
    String? storeName,
    required String itemsDescription,
    required String deliveryAddressText,
    required double itemsPrice,
    required double latitude,
    required double longitude,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupAddressText,
  }) async {
    final url = Uri.parse('$baseUrl/orders/create');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'customerId': customerId,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'categoryType': categoryType,
          'storeName': storeName ?? 'غير محدد',
          'itemsDescription': itemsDescription,
          'deliveryAddressText': deliveryAddressText,
          'itemsPrice': itemsPrice,
          'latitude': latitude,
          'longitude': longitude,
          if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
          if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
          if (pickupAddressText != null) 'pickupAddressText': pickupAddressText,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'لا توجد استجابة من السيرفر'};
      }
      final decodedData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decodedData};
      }
      return {'success': false, 'message': decodedData['message'] ?? 'فشل إنشاء الطلب'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، السيرفر بطيء.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// Cancels the customer's own order. The server only allows this while the
  /// order is still waiting for offers.
  Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/cancel');
    try {
      final response = await http
          .patch(url, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      final decoded = response.body.isEmpty ? {} : jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'تعذّر إلغاء الطلب',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، حاول مرة أخرى'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // 🎯 2️⃣ إنشاء طلب يحتوي على صورة المشتريات/الفاتورة
  Future<Map<String, dynamic>> createOrderWithImage({
    required int customerId,
    required String customerName,
    required String customerPhone,
    required String categoryType,
    String? storeName,
    required String itemsDescription,
    required String deliveryAddressText,
    double itemsPrice = 0,
    required double latitude,
    required double longitude,
    File? itemsImage,
  }) async {
    final url = Uri.parse('$baseUrl/orders/create');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['customerId'] = customerId.toString();
      request.fields['customerName'] = customerName;
      request.fields['customerPhone'] = customerPhone;
      request.fields['categoryType'] = categoryType;
      request.fields['storeName'] = storeName ?? 'غير محدد';
      request.fields['itemsDescription'] = itemsDescription;
      request.fields['deliveryAddressText'] = deliveryAddressText;
      request.fields['itemsPrice'] = itemsPrice.toString();
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      final headers = await _headers();
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      if (itemsImage != null && await itemsImage.exists()) {
        request.files.add(await http.MultipartFile.fromPath('itemsImage', itemsImage.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final decodedData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decodedData};
      }
      return {'success': false, 'message': decodedData['message'] ?? 'فشل إنشاء الطلب'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال، السيرفر بطيء.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // 🎯 3️⃣ تقديم عرض سعر من الكابتن للطلب
  Future<Map<String, dynamic>> submitOffer({
    required int orderId,
    required int driverId,
    required double deliveryFee,
    required int estimatedTime,
  }) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/submit-offer');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'driverId': driverId,
          'deliveryFee': deliveryFee,
          'estimatedTime': estimatedTime,
        }),
      ).timeout(const Duration(seconds: 15));

      final decodedData = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decodedData};
      }
      return {'success': false, 'message': decodedData['message'] ?? 'فشل تقديم العرض'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 4️⃣ جلب كافة العروض المتاحة لطلب محدد
  Future<Map<String, dynamic>> getOrderOffers(int orderId) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/offers');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return {'success': true, 'offers': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب العروض'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 5️⃣ قبول عرض الكابتن من قبل العميل
  Future<Map<String, dynamic>> acceptOffer({required int orderId, required int offerId}) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/offers/$offerId/accept');
    try {
      final response = await http.post(url, headers: await _headers()).timeout(const Duration(seconds: 15));
      final decodedData = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final details = await getOrderCustomerDetails(orderId);
        return {
          'success': true,
          'message': 'تم قبول العرض بنجاح',
          'order': details['success'] == true ? details['data'] : null,
        };
      }
      return {'success': false, 'message': decodedData['message'] ?? 'فشل قبول العرض'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 6️⃣ الميثود التي كانت مفقودة: جلب كافة طلبات الكابتن (النشطة والمكتملة)
  Future<Map<String, dynamic>> getDriverOrders(int driverId) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 12));
      final decodedData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'orders': decodedData['orders'] ?? decodedData['data'] ?? decodedData,
        };
      }
      return {
        'success': false,
        'message': decodedData['message'] ?? 'فشل جلب طلبات الكابتن',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال بالسيرفر.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  // 🎯 7️⃣ تحديث حالة الطلب (ACCEPTED, PICKED_UP, DELIVERED, CANCELLED)
  Future<Map<String, dynamic>> updateOrderStatus({
    required int orderId,
    required String status,
    double? itemsPrice,
    String? invoiceImageUrl,
  }) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/status?status=$status');
    try {
      final response = await http.patch(
        url,
        headers: await _headers(),
        body: jsonEncode({
          if (itemsPrice != null) 'itemsPrice': itemsPrice,
          if (invoiceImageUrl != null) 'invoiceImageUrl': invoiceImageUrl,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل التحديث'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 8️⃣ جلب الطلبات المتاحة في الساحة للكباتن
  Future<Map<String, dynamic>> getAvailableOrders({int? driverId}) async {
    final url = Uri.parse('$baseUrl/orders/available${driverId != null ? '?driverId=$driverId' : ''}');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب الطلبات'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 9️⃣ جلب الطلبات الخاصة بالعميل
  Future<Map<String, dynamic>> getCustomerOrders(int customerId) async {
    final url = Uri.parse('$baseUrl/orders/customer/$customerId');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب طلباتك'};
    } on TimeoutException {
      return {'success': false, 'message': 'انتهى وقت الاتصال.'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 10️⃣ جلب حالة اتصال الكابتن (Online/Offline)
  Future<Map<String, dynamic>> getDriverOnlineStatus(int driverId) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId/online-status');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب حالة الاتصال'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 11️⃣ تحديث حالة اتصال الكابتن (Online/Offline)
  Future<Map<String, dynamic>> setDriverOnlineStatus({
    required int driverId,
    required bool isOnline,
  }) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId/online-status');
    try {
      final response = await http.patch(
        url,
        headers: await _headers(),
        body: jsonEncode({'isOnline': isOnline}),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, ...decoded};
      }
      return {'success': false, 'message': decoded['message'] ?? 'فشل تحديث الحالة'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 12️⃣ جلب إحصائيات لوحة أداء الكابتن
  Future<Map<String, dynamic>> getDriverDashboardStats(int driverId) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId/dashboard-stats');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب إحصائيات اللوحة'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 13️⃣ جلب تفاصيل بيانات العميل الخاصة بالطلب
  Future<Map<String, dynamic>> getOrderCustomerDetails(int orderId) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/customer-details');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب تفاصيل الطلب'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 14️⃣ تقييم الكابتن من قبل العميل
  Future<Map<String, dynamic>> rateDriver({
    required int driverId,
    required int rating,
  }) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId/rate');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({'rating': rating}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل إرسال التقييم'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 15️⃣ طلب شحن المحفظة
  Future<Map<String, dynamic>> requestDriverTopUp({
    required int driverId,
    required double amount,
  }) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId/topup-request');
    try {
      final response = await http.patch(
        url,
        headers: await _headers(),
        body: jsonEncode({'amount': amount}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل طلب الشحن'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 16️⃣ معالجة الـ Webhook لتأكيد دفع المحفظة
  Future<Map<String, dynamic>> processPaymentWebhook({
    required int driverId,
    required double amount,
  }) async {
    final url = Uri.parse('$baseUrl/orders/payment/webhook');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'driverId': driverId,
          'amount': amount,
          'status': 'success',
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل تأكيد الشحن'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 17️⃣ جلب إشعارات المستخدم
  Future<Map<String, dynamic>> getUserNotifications(int userId) async {
    final url = Uri.parse('$baseUrl/orders/user/$userId/notifications');
    try {
      final response = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'فشل جلب الإشعارات'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ: $e'};
    }
  }

  // 🎯 18️⃣ حذف إشعار فردي
  Future<bool> deleteNotification(int id) async {
    final url = Uri.parse('$baseUrl/orders/notifications/$id');
    try {
      final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // 🎯 19️⃣ مسح كافة الإشعارات
  Future<bool> clearAllNotifications(int userId) async {
    final url = Uri.parse('$baseUrl/orders/user/$userId/notifications/clear-all');
    try {
      final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // 🎯 20️⃣ حذف حساب كابتن التوصيل
  Future<bool> deleteDriverAccount(int driverId) async {
    final url = Uri.parse('$baseUrl/orders/driver/$driverId');
    try {
      final response = await http.delete(url, headers: await _headers()).timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}