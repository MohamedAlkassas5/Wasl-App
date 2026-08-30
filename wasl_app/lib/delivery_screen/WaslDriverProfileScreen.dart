import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/services/push_service.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/services/orders_service.dart';

class WaslDriverProfileScreen extends StatefulWidget {
  const WaslDriverProfileScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverProfileScreen> createState() => _WaslDriverProfileScreenState();
}

class _WaslDriverProfileScreenState extends State<WaslDriverProfileScreen> {
  final FlutterOrdersService _ordersService = FlutterOrdersService();
  String _name = 'كابتن وصل';
  String _phone = '';
  int? _driverId; // 🎯 حفظ الـ ID لإرساله في طلب الحذف وجلب البيانات
  double _driverRating = 5.00; // 🎯 متغير حفظ التقييم التراكمي الحي
  bool _isDeleting = false; // مؤشر انتظار تحميل الحذف

  @override
  void initState() {
    super.initState();
    _loadDriverDataAndFetchRating();
  }

  void _loadDriverDataAndFetchRating() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 21; // الافتراضي 21 للتست
    final name = prefs.getString('user_name') ?? 'كابتن وصل';
    final phone = prefs.getString('user_phone') ?? '';

    setState(() {
      _driverId = id;
      _name = name;
      _phone = phone;
    });

    // 🎯 جلب التقييم المحدث مباشرة من السيرفر فور دخول الصفحة
    await _fetchLiveDriverRating(id);
  }

  // 📡 جلب إحصائيات البروفايل لاستخراج التقييم الحقيقي المحدث تراكمياً
  Future<void> _fetchLiveDriverRating(int driverId) async {
    final result = await _ordersService.getDriverDashboardStats(driverId);
    if (result['success'] == true && mounted) {
      setState(() {
        _driverRating = double.tryParse(result['rating']?.toString() ?? '5') ?? 5.0;
      });
    }
  }

  // 🎯 دالة تسجيل الخروج وتصفير الجلسة محلياً
  void _handleLogout() async {
    // 🔔 قبل مسح الجلسة: إلغاء تسجيل الجهاز محتاج توكن صالح. الكابتن تحديداً
    // بيستقبل عروض الطلبات، فجهاز فاضل مسجّل بعد الخروج معناه إن عروض شغل
    // بتروح لحد تاني ماسك الموبايل.
    await WaslPushService.instance.stop();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل الخروج بنجاح، ننتظرك قريباً يا كابتن 👋', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WaslLoginScreen()),
          (route) => false,
    );
  }

  // 📡 ضربة الـ API وتدمير الحساب نهائياً من قاعدة البيانات (PostgreSQL)
  Future<void> _deleteAccountFromDatabase() async {
    if (_driverId == null) return;

    setState(() => _isDeleting = true);

    final success = await _ordersService.deleteDriverAccount(_driverId!);

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف حسابك وبياناتك بالكامل من منظومة وصل بنجاح 🛡️', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WaslLoginScreen()),
        (route) => false,
      );
      return;
    }

    setState(() => _isDeleting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('عفواً، فشل حذف الحساب. يرجى التحقق من اتصال الشبكة 📡', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('⚠️ تنبيه أمني حاسم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.danger)),
            content: const Text(
              'هل أنت متأكد تماماً من رغبتك في حذف الحساب؟ هذا الإجراء سيقوم بتدمير محفظتك الماليّة، وسجلك اللوجستي، ومسح بياناتك نهائياً من قاعدة بيانات وصل ولا يمكن التراجع عنه.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5, color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء التراجع', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccountFromDatabase();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('نعم، احذف نهائياً', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'الملف الشخصي للكابتن',
          style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: _isDeleting
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.danger),
                SizedBox(height: 16),
                Text('جاري تدمير البيانات وحذف الحساب من السيرفر...', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ],
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1️⃣ كارت الهوية العلوية المطور للكابتن (مدمج معه صف النجوم والتقييم الحي)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withOpacity(0.015),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      child: const Icon(Icons.delivery_dining_rounded, size: 44, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo', color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // 🎯 [تم التحديث]: شريط التقييم التراكمي التفاعلي أسفل بيانات الاتصال للكابتن
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'تقييمك التراكمي: ${_driverRating.toStringAsFixed(2)} ★',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2️⃣ خيارات التحكم والإعدادات اللوجستية الملونة للكابتن
              _buildListTile('وثائق التحقق والهوية الشخصية 🪪', Icons.verified_user_outlined, AppColors.primary),
              _buildListTile('تحديث بيانات المركبة والموتوسيكل 🏍️', Icons.two_wheeler_rounded, Colors.blue.shade600),
              _buildListTile('سجل المكافآت والأرباح الأسبوعية 💵', Icons.analytics_outlined, const Color(0xFF16A34A)),
              _buildListTile('مركز الدعم الفني والمساعدة 🛠️', Icons.support_agent_rounded, Colors.amber.shade800),
              const SizedBox(height: 24),

              // 3️⃣ زر تسجيل الخروج الحاسي لتدمير الجلسة الأمنية المحفوظة
              ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'تسجيل الخروج من الحساب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),

              // 4️⃣ زر حذف الحساب نهائياً ومسح البيانات من قاعدة البيانات
              OutlinedButton.icon(
                onPressed: _showDeleteConfirmationDialog,
                icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 18),
                label: const Text(
                  'حذف الحساب نهائياً ومسح البيانات',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.005),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
        onTap: () {},
      ),
    );
  }
}