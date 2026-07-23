import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslNotificationBell extends StatefulWidget {
  final int userId;

  const WaslNotificationBell({Key? key, required this.userId}) : super(key: key);

  @override
  State<WaslNotificationBell> createState() => _WaslNotificationBellState();
}

class _WaslNotificationBellState extends State<WaslNotificationBell> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  List<dynamic> _notifications = [];
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _fetchLiveNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchLiveNotifications();
    });
  }

  Future<void> _fetchLiveNotifications() async {
    final result = await _ordersService.getUserNotifications(widget.userId);
    if (!mounted || result['success'] != true) return;

    final List<dynamic> data = result['data'] ?? [];
    if (data.length > _notifications.length && _notifications.isNotEmpty) {
      final newNotif = data.first;
      _showTopSnackBar(newNotif['title'], newNotif['message']);
    }
    setState(() => _notifications = data);
  }

  Future<void> _deleteNotification(int id, int index) async {
    setState(() => _notifications.removeAt(index));
    await _ordersService.deleteNotification(id);
  }

  Future<void> _clearAllNotifications() async {
    setState(() => _notifications.clear());
    Navigator.pop(context);
    await _ordersService.clearAllNotifications(widget.userId);
  }

  void _showTopSnackBar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message 🔔', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasUnread = _notifications.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            hasUnread ? Icons.notifications_active_rounded : Icons.notifications_none_outlined,
            color: hasUnread ? AppColors.primary : AppColors.textPrimary,
            size: 24,
          ),
          onPressed: _showNotificationsDialog,
        ),
        if (hasUnread)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                '${_notifications.length}',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          )
      ],
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المركز اللوجستي للإشعارات 🔔', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                  if (_notifications.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        await _clearAllNotifications();
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 18),
                      label: const Text('مسح الكل', style: TextStyle(color: AppColors.danger, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _notifications.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('لا توجد إشعارات جديدة حالياً.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    return Dismissible(
                      key: Key(item['id'].toString()),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      ),
                      onDismissed: (direction) async {
                        await _deleteNotification(item['id'], index);
                        setDialogState(() {}); // تحديث حالة الديالوج الداخلية بعد السحب
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        color: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(item['title'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          subtitle: Text(item['message'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.flash_on, color: AppColors.primary, size: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}