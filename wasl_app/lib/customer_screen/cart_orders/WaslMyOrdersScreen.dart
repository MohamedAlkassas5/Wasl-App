import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/ui/wasl_async.dart';
import 'package:wasl_app/core/ui/wasl_failure.dart';
import 'package:wasl_app/core/ui/wasl_submit_guard.dart';
import 'package:wasl_app/core/widgets/wasl_async_view.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderTrackingScreen.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslMyOrdersScreen extends StatefulWidget {
  const WaslMyOrdersScreen({Key? key}) : super(key: key);

  /// Every live instance of this screen, so anything that changes the
  /// customer's orders can refresh all of them.
  ///
  /// The shell keeps one instance alive for the whole session inside an
  /// IndexedStack — its `initState` runs once at app start and never again — so
  /// without an external refresh the list a customer sees is whatever was
  /// fetched when the app launched, and an order placed a minute ago simply is
  /// not there.
  ///
  /// 🐞 This used to be a **single slot** (`static Function()? refreshHook`),
  /// and that is what made a new order invisible until the app was restarted.
  /// Three flows push a *second* instance of this screen — the pharmacy
  /// request, the هاتلي/وصللي success screen, and a push-notification tap. Each
  /// one overwrote the slot in its own `initState` and then set it back to
  /// **null** in its `dispose`. From that moment the shell's long-lived
  /// instance had no hook at all: opening the الطلبات tab, and "تتبّع طلباتي"
  /// after checkout, both called `refreshNow()` and it did nothing. Only a full
  /// restart rebuilt the shell instance and re-fetched.
  ///
  /// A set fixes it at the cause: instances register and unregister
  /// themselves, and can no longer overwrite one another.
  static final Set<Future<void> Function()> _refreshHooks =
      <Future<void> Function()>{};

  static void registerRefreshHook(Future<void> Function() hook) =>
      _refreshHooks.add(hook);

  static void unregisterRefreshHook(Future<void> Function() hook) =>
      _refreshHooks.remove(hook);

  /// Whether any instance is currently listening. Exposed for tests.
  static int get liveRefreshHooks => _refreshHooks.length;

  /// Refreshes every live instance. A no-op when none is mounted, so callers
  /// (order creation, the shell's tab switch) never have to check.
  static Future<void> refreshNow() async {
    for (final hook in _refreshHooks.toList()) {
      await hook();
    }
  }

  @override
  State<WaslMyOrdersScreen> createState() => _WaslMyOrdersScreenState();
}

class _WaslMyOrdersScreenState extends State<WaslMyOrdersScreen>
    with SingleTickerProviderStateMixin, WaslSubmitGuard<WaslMyOrdersScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  TabController? _tabController;
  int? _customerId;

  List<dynamic> _activeOrders = [];
  List<dynamic> _completedOrders = [];

  /// حالة تحميل الطلبات.
  ///
  /// قبل كده كان فيه `_isLoading` بس: لو الطلب فشل، الشاشة كانت بتوقف التحميل
  /// وتسيب القوايم فاضية، فالعميل يشوف «لا توجد طلبات» وهو عنده طلب شغال —
  /// فشل الشبكة كان بيتقرا كأنه مفيش بيانات. دلوقتي الفشل حالة قائمة بذاتها
  /// وليها رسالة وزرار إعادة محاولة.
  WaslAsync<List<dynamic>> _orders = const WaslAsync.loading();

  /// Held in a field so `dispose` unregisters the very same closure it
  /// registered, whatever Dart decides about tear-off identity.
  late final Future<void> Function() _refreshHook;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshHook = _loadCustomerSessionAndFetchOrders;
    _loadCustomerSessionAndFetchOrders();
    WaslMyOrdersScreen.registerRefreshHook(_refreshHook);
  }

  Future<void> _loadCustomerSessionAndFetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final id = prefs.getInt('user_id') ?? 1;
    setState(() => _customerId = id);
    await _fetchCustomerOrdersFromServer();
  }

  Future<void> _fetchCustomerOrdersFromServer() async {
    // Now reachable from outside the widget (order creation, the shell's tab
    // switch), so it can no longer assume it is still on screen.
    if (!mounted || _customerId == null) return;

    setState(() => _orders = const WaslAsync.loading());

    final result = await _ordersService.getCustomerOrders(_customerId!);

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _orders = WaslAsync.failure(WaslFailure.fromResult(result)));
      return;
    }

    final List<dynamic> allOrders = result['data'] ?? [];

    setState(() {
      _activeOrders = allOrders.where((order) {
        final status = order['status']?.toString().toLowerCase();
        return status == 'pending_offers' ||
            status == 'accepted' ||
            status == 'at_store' ||
            status == 'items_bought' ||
            status == 'delivering';
      }).toList();

      // 🐞 كان بيفلتر 'completed' بس، فالطلبات الملغية كانت بتختفي من الشاشتين
      // خالص — العميل ميعرفش إن طلبه اتلغى أصلاً. دلوقتي بتظهر في السجل.
      _completedOrders = allOrders.where((order) {
        final status = order['status']?.toString().toLowerCase();
        return status == 'completed' || status == 'cancelled';
      }).toList();

      _orders = WaslAsync.data(allOrders);
    });
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_offers':
        return 'قيد استقبال عروض الكباتن ⏳';
      case 'accepted':
        return 'تم قبول الكابتن وفي طريقه للمحل 🏍️';
      case 'at_store':
        return 'الكابتن وصل للمحل وجاري الشراء 🛒';
      case 'items_bought':
        return 'تم شراء المنتجات — بانتظار موافقتك 📋';
      case 'delivering':
        return 'الكابتن في طريقه إليك الآن 🚴';
      case 'completed':
        return 'تم التوصيل بنجاح 🎉';
      case 'cancelled':
        return 'تم إلغاء الطلب ❌';
      default:
        return 'قيد المعالجة...';
    }
  }

  @override
  void dispose() {
    // Only this instance stops listening. Any other live instance — notably the
    // shell's, which must survive for the whole session — keeps its own hook.
    WaslMyOrdersScreen.unregisterRefreshHook(_refreshHook);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          'طلباتي',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchCustomerOrdersFromServer,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          tabs: const [
            Tab(text: 'طلبات جارية'),
            Tab(text: 'طلبات مكتملة'),
          ],
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              // شريط بيظهر بس لما يكون الفشل سببه الشبكة.
              WaslOfflineBanner(
                visible: _orders.failureOrNull?.isOffline ?? false,
                onRetry: _fetchCustomerOrdersFromServer,
              ),
              Expanded(
                child: WaslAsyncView<List<dynamic>>(
                  state: _orders,
                  onRetry: _fetchCustomerOrdersFromServer,
                  // الفراغ بيتقرر جوه كل تبويب لأن لكل واحد نص مختلف؛ هنا
                  // بنهتم بالتحميل والفشل بس.
                  builder: (context, _) => TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveOrdersList(),
                      _buildCompletedOrdersList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrdersList() {
    if (_activeOrders.isEmpty) {
      return _buildEmptyState('لا توجد طلبات جارية حالياً', Icons.assignment_late_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeOrders.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final order = _activeOrders[index];
        final orderId = order['id'] ?? '';
        final String status = order['status']?.toString().toLowerCase() ?? 'pending_offers';
        final bool isPendingOffers = status == 'pending_offers';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.textPrimary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('رقم الطلب: WS-$orderId', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPendingOffers ? AppColors.warning.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPendingOffers ? Colors.orange.shade800 : AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Text(order['categoryType'] ?? 'طلبات عامة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                if (order['storeName'] != null && order['storeName'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('المكان: ${order['storeName']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                ],
                const SizedBox(height: 6),
                Text('المشتريات: ${order['itemsDescription'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                const SizedBox(height: 16),
                ElevatedButton(
                  // الطلب اللي لسه مستني كابتن والطلب اللي اتقبل بيروحوا نفس
                  // الشاشة: التتبع بيعرض الحالة الحالية في الحالتين. مفيش
                  // شاشة عروض أسعار بعد إلغاء المزايدة.
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WaslOrderTrackingScreen(orderData: order)),
                    );
                    _fetchCustomerOrdersFromServer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPendingOffers ? AppColors.secondary : AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    isPendingOffers ? 'متابعة الطلب ⏳' : 'تتبع الكابتن 📍',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ),
                // الإلغاء متاح طالما مفيش كابتن قبل الطلب. بعد القبول الزرار
                // بيختفي خالص لأن الكابتن ممكن يكون بدأ يتحرك للمحل.
                if (isPendingOffers) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmCancelOrder(order),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.danger),
                    label: const Text(
                      'إلغاء الطلب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Asks before cancelling, then calls the server. The server is the authority
  /// on whether cancelling is still allowed — if a driver accepted in the
  /// meantime it refuses, and we surface that instead of pretending it worked.
  Future<void> _confirmCancelOrder(dynamic order) async {
    final orderId = order['id'];
    final int parsedId =
        orderId is num ? orderId.toInt() : int.tryParse('$orderId') ?? 0;
    if (parsedId == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إلغاء الطلب؟',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          content: Text(
            'هيتم إلغاء طلبك رقم WS-$parsedId. تقدر تطلب تاني في أي وقت.',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إلغاء الطلب',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // ضغطتين سريعتين على «إلغاء الطلب» كانت بتبعت طلبين للسيرفر. الحارس هنا
    // بيمنع التاني من أصله بدل ما نستنى السيرفر يرفضه ويطلع للعميل رسالة
    // خطأ على ضغطة شرعية تماماً.
    await guardedSubmit(() async {
      final result = await _ordersService.cancelOrder(parsedId);
      if (!mounted) return;

      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppColors.success : AppColors.danger,
          content: Text(
            ok
                ? 'تم إلغاء الطلب'
                : WaslFailure.fromResult(result).message,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );

      await _fetchCustomerOrdersFromServer();
    });
  }

  Widget _buildCompletedOrdersList() {
    if (_completedOrders.isEmpty) {
      return _buildEmptyState('سجل طلباتك فارغ', Icons.assignment_turned_in_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedOrders.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final order = _completedOrders[index];
        final orderId = order['id'] ?? '';
        // 🐞 كان بيكتب "مكتمل ✓" لأي طلب في التبويب ده — يعني الطلب الملغي كان
        // بيتعرض للعميل كإنه اتوصّل. الحالة بقت من الطلب نفسه.
        final bool isCancelled =
            order['status']?.toString().toLowerCase() == 'cancelled';

        final double deliveryFee = double.tryParse(order['finalDeliveryFee']?.toString() ?? '0') ?? 0;
        final double itemsPrice = double.tryParse(order['itemsPrice']?.toString() ?? '0') ?? 0;
        final double totalPrice = deliveryFee + itemsPrice;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.textPrimary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('طلب رقم: WS-$orderId', style: const TextStyle(fontFamily: 'monospace', color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    Text(
                      isCancelled ? 'ملغي ✕' : 'مكتمل ✓',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCancelled
                            ? AppColors.danger
                            : const Color(0xFF16A34A),
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${order['categoryType'] ?? 'طلبات عامة'} • ${order['storeName'] ?? 'من أقرب مكان'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Text(order['itemsDescription'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${totalPrice.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
