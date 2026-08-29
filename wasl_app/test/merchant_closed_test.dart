import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_app/customer_screen/restaurants/WaslRestaurantDetailsScreen.dart';
import 'package:wasl_app/customer_screen/restaurants/data/cart_controller.dart';
import 'package:wasl_app/customer_screen/restaurants/data/menu_repository.dart';
import 'package:wasl_app/customer_screen/restaurants/data/restaurant_models.dart';

/// CP-D — حالة المتجر المقفول عند العميل.
///
/// السيرفر بيرفض الطلب من متجر مقفول أصلاً (`assertMerchantCanTakeOrders`)،
/// فالاختبارات دي مش بتثبت أمان — بتثبت إن العميل **بيعرف** إن المتجر مقفول
/// قبل ما يضيّع وقته في بناء سلة هتترفض عند الدفع.
class _FakeMenuRepository implements MenuRepository {
  @override
  bool get isPlaceholderData => false;

  @override
  Future<List<MenuSection>> getSections(int merchantId) async =>
      const [MenuSection(id: 1, name: 'وجبات')];

  @override
  Future<List<Product>> getProducts(int merchantId) async => [
        Product(
          id: 1,
          merchantId: merchantId,
          sectionId: 1,
          name: 'ساندويتش دجاج',
          basePrice: 65,
          isPopular: true,
        ),
      ];
}

Future<void> _pumpStore(WidgetTester tester, {required bool accepting}) async {
  await tester.pumpWidget(MaterialApp(
    home: WaslRestaurantDetailsScreen(
      merchantId: 1,
      merchantName: 'مطعم الاختبار',
      isAcceptingOrders: accepting,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MenuRepository.instance = _FakeMenuRepository();
    // السلة singleton بتعيش بين الاختبارات — لو فضلت متعبّية، شريط السلة
    // بيظهر ويغيّر الشجرة تحت الاختبار.
    CartController.instance.clear();
  });

  testWidgets('المتجر المقفول بيعرض شريط تنبيه', (tester) async {
    await _pumpStore(tester, accepting: false);

    expect(
      find.textContaining('المتجر مقفول دلوقتي ومش بيستقبل طلبات'),
      findsOneWidget,
    );
  });

  testWidgets('المتجر المفتوح مابيعرضش الشريط', (tester) async {
    await _pumpStore(tester, accepting: true);

    expect(
      find.textContaining('المتجر مقفول دلوقتي'),
      findsNothing,
    );
  });

  testWidgets('القائمة بتفضل باينة والمتجر مقفول', (tester) async {
    await _pumpStore(tester, accepting: false);

    // الأصناف والأسعار بتفضل مقروءة — المتجر بيتصفّح، اللي بيتمنع هو الطلب.
    // إخفاء القائمة كان هيخلي المتجر يتقري «مابقاش موجود».
    expect(find.text('ساندويتش دجاج'), findsOneWidget);
  });

  testWidgets('الضغط على صنف في متجر مقفول مابيفتحش صفحة الصنف',
      (tester) async {
    await _pumpStore(tester, accepting: false);

    await tester.tap(find.text('ساندويتش دجاج'));
    await tester.pump(); // يظهر الـ SnackBar

    // رسالة واضحة بدل لمسة بتروح في الفراغ.
    expect(find.byType(SnackBar), findsOneWidget);
    // والسلة فضلت فاضية — مفيش صنف اتضاف.
    expect(CartController.instance.isEmpty, isTrue);
  });

  testWidgets('الضغط على صنف في متجر مفتوح بيفتح صفحة الصنف', (tester) async {
    await _pumpStore(tester, accepting: true);

    await tester.tap(find.text('ساندويتش دجاج'));
    await tester.pumpAndSettle();

    // مفيش رسالة منع، والشيت اتفتح.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
