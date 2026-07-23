import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderOffersScreen.dart';
import 'package:wasl_app/customer_screen/cart_orders/WaslOrderTrackingScreen.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslMyOrdersScreen extends StatefulWidget {
  const WaslMyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WaslMyOrdersScreen> createState() => _WaslMyOrdersScreenState();
}

class _WaslMyOrdersScreenState extends State<WaslMyOrdersScreen> with SingleTickerProviderStateMixin {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  TabController? _tabController;
  int? _customerId;

  List<dynamic> _activeOrders = [];
  List<dynamic> _completedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomerSessionAndFetchOrders();
  }

  Future<void> _loadCustomerSessionAndFetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 1;
    setState(() => _customerId = id);
    await _fetchCustomerOrdersFromServer();
  }

  Future<void> _fetchCustomerOrdersFromServer() async {
    if (_customerId == null) return;

    setState(() => _isLoading = true);

    final result = await _ordersService.getCustomerOrders(_customerId!);

    if (!mounted) return;

    if (result['success'] == true) {
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

        _completedOrders = allOrders.where((order) {
          return order['status']?.toString().toLowerCase() == 'completed';
        }).toList();

        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);
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
      default:
        return 'قيد المعالجة...';
    }
  }

  @override
  void dispose() {
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveOrdersList(),
                    _buildCompletedOrdersList(),
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
                  onPressed: () async {
                    if (isPendingOffers) {
                      final int parsedId = orderId is num ? orderId.toInt() : int.tryParse(orderId.toString()) ?? 1;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WaslOrderOffersScreen(orderId: parsedId)),
                      );
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WaslOrderTrackingScreen(orderData: order)),
                      );
                    }
                    _fetchCustomerOrdersFromServer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPendingOffers ? AppColors.secondary : AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    isPendingOffers ? 'عرض عروض الكباتن 🏁' : 'تتبع الكابتن 📍',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                    const Text('مكتمل ✓', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
