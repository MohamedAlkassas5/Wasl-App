// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية فلاش الجديدة
// import 'package:wasl_app/core/theme/app_colors.dart';
// import 'package:wasl_app/customer_screen/profile/WaslHelpCenterScreen.dart';
// import 'package:wasl_app/screens/WaslLoginScreen.dart'; // استيراد شاشة تسجيل الدخول صراحة للتوجيه المباشر
// import 'package:wasl_app/services/auth_service.dart';
//
// class WaslSettingsScreen extends StatefulWidget {
//   const WaslSettingsScreen({Key? key}) : super(key: key);
//
//   @override
//   State<WaslSettingsScreen> createState() => _WaslSettingsScreenState();
// }
//
// class _WaslSettingsScreenState extends State<WaslSettingsScreen> {
//   bool _isDarkMode = false;
//
//   String _userName = 'جاري التحميل...';
//   String _userPhone = '';
//   String _userRole = 'عميل';
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _userName = prefs.getString('user_name') ?? 'مستخدم فلاش';
//       _userPhone = prefs.getString('user_phone') ?? '';
//
//       String role = prefs.getString('user_role') ?? 'customer';
//       _userRole = role == 'customer' ? 'عميل مميز' : 'كابتن فلاش';
//     });
//   }
//
//   // 🎯 تفعيل وتشغيل دالة تسجيل الخروج بشكل آمن ومستقر 100% لتدمير الـ Session
//   Future<void> _handleLogout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear(); // تنظيف بيانات جلسة المستخدم بالكامل لكسر الـ Auto login
//
//     if (!mounted) return;
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('تم تسجيل الخروج بنجاح، نراك قريباً! 👋', style: TextStyle(fontFamily: 'Cairo')),
//         backgroundColor: AppColors.textPrimary,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//
//     // التوجيه المباشر والمستقر مع تفريغ الـ Navigation Stack بالكامل ومنع زر العودة
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
//           (route) => false,
//     );
//   }
//
//   // 🎯 دالة حذف الحساب التأكيدية المربوطة بالـ Database
//   Future<void> _showDeleteAccountDialog() async {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Directionality(
//           textDirection: TextDirection.rtl,
//           child: AlertDialog(
//             backgroundColor: AppColors.white,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             title: Row(
//               children: const [
//                 Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
//                 SizedBox(width: 8),
//                 Text(
//                   'حذف الحساب نهائياً',
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary, fontFamily: 'Cairo'),
//                 ),
//               ],
//             ),
//             content: const Text(
//               'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء سيؤدي إلى إزالة كافة بياناتك، طلباتك السابقة، ومحفظتك اللوجستية من السيرفر نهائياً ولا يمكن التراجع عنه.',
//               style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.5),
//             ),
//             actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text(
//                   'إلغاء',
//                   style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   Navigator.pop(context); // إغلاق الديالوج
//
//                   // إظهار مؤشر التحميل أثناء الاتصال بقاعدة البيانات
//                   showDialog(
//                     context: context,
//                     barrierDismissible: false,
//                     builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
//                   );
//
//                   // 🚀 استدعاء دالة الحذف المحدثة من الـ Service مرسلاً رقم الهاتف الموثق
//                   final Map<String, dynamic> result = await FlutterAuthService().deleteUserAccount(_userPhone);
//
//                   if (!mounted) return;
//                   Navigator.pop(context); // إغلاق مؤشر التحميل
//
//                   if (result['success']) {
//                     final prefs = await SharedPreferences.getInstance();
//                     await prefs.clear(); // تصفير الجلسة تماماً بعد حذف الحساب
//
//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text('تم حذف حسابك وبياناتك من السيرفر بنجاح.', style: TextStyle(fontFamily: 'Cairo')),
//                         backgroundColor: AppColors.success,
//                         behavior: SnackBarBehavior.floating,
//                       ),
//                     );
//
//                     Navigator.of(context).pushAndRemoveUntil(
//                       MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
//                           (route) => false,
//                     );
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(result['message'] ?? 'فشلت عملية حذف الحساب، يرجى المحاولة لاحقاً', style: const TextStyle(fontFamily: 'Cairo')),
//                         backgroundColor: AppColors.danger,
//                         behavior: SnackBarBehavior.floating,
//                       ),
//                     );
//                   }
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.danger,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   elevation: 0,
//                 ),
//                 child: const Text(
//                   'نعم، احذف الحساب',
//                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             if (Navigator.canPop(context)) {
//               Navigator.pop(context);
//             }
//           },
//         ),
//         title: const Text(
//           'فلاش • FLASH',
//           style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
//         ),
//         centerTitle: true,
//       ),
//       body: Directionality(
//         textDirection: TextDirection.rtl,
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(20.0),
//             physics: const BouncingScrollPhysics(),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // كارت الهوية الشخصية الموحد بنظام الـ Gradients لفلاش
//                 Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     gradient: AppColors.logoGradient,
//                     borderRadius: BorderRadius.circular(24),
//                     boxShadow: [
//                       BoxShadow(
//                         color: AppColors.primary.withOpacity(0.15),
//                         blurRadius: 12,
//                         offset: const Offset(0, 4),
//                       )
//                     ],
//                   ),
//                   child: Column(
//                     children: [
//                       const CircleAvatar(radius: 36, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 40, color: AppColors.white)),
//                       const SizedBox(height: 12),
//                       Text(_userName, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//                       const SizedBox(height: 4),
//                       Text(
//                         '$_userRole • $_userPhone',
//                         textDirection: TextDirection.ltr,
//                         style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 _buildSectionTitle('الحساب'),
//                 _buildSettingsTile(
//                   title: 'معلومات الحساب',
//                   sub: 'الاسم، البريد الإلكتروني، رقم الهاتف',
//                   icon: Icons.person_outline,
//                   onTap: () {},
//                 ),
//                 _buildSettingsTile(
//                   title: 'إعدادات التنبيهات',
//                   sub: 'الرسائل القصيرة، البريد، الإشعارات',
//                   icon: Icons.notifications_none,
//                   onTap: () {},
//                 ),
//
//                 _buildSectionTitle('التفضيلات'),
//                 _buildSettingsTile(
//                   title: 'اللغة',
//                   sub: 'العربية (جمهورية مصر العربية)',
//                   icon: Icons.language,
//                   onTap: () {},
//                 ),
//
//                 // كارت تحويل الوضع الليلي
//                 Container(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                   decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Row(
//                         children: const [
//                           Icon(Icons.dark_mode_outlined, color: AppColors.textSecondary),
//                           SizedBox(width: 12),
//                           Text('الوضع الليلي', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                         ],
//                       ),
//                       Switch(
//                         value: _isDarkMode,
//                         onChanged: (v) => setState(() => _isDarkMode = v),
//                         activeColor: AppColors.secondary,
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 _buildSectionTitle('الأمان'),
//                 _buildSettingsTile(
//                   title: 'كلمة المرور والحماية',
//                   sub: 'تغيير كلمة المرور، المصادقة الثنائية',
//                   icon: Icons.shield_outlined,
//                   onTap: () {},
//                 ),
//                 _buildSettingsTile(
//                   title: 'مركز المساعدة',
//                   sub: 'تواصل معنا، الأسئلة الشائعة',
//                   icon: Icons.help_outline,
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => const WaslHelpCenterScreen()),
//                     );
//                   },
//                 ),
//
//                 const SizedBox(height: 24),
//
//                 // زر تسجيل الخروج
//                 ElevatedButton.icon(
//                   onPressed: _handleLogout,
//                   icon: const Icon(Icons.logout, size: 18),
//                   label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.danger.withOpacity(0.08),
//                     foregroundColor: AppColors.danger,
//                     minimumSize: const Size.fromHeight(54),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                     elevation: 0,
//                   ),
//                 ),
//
//                 const SizedBox(height: 12),
//
//                 // زر حذف الحساب بشكل دائم
//                 TextButton.icon(
//                   onPressed: _showDeleteAccountDialog,
//                   icon: const Icon(Icons.delete_forever_outlined, size: 18, color: AppColors.textSecondary),
//                   label: const Text(
//                     'حذف الحساب نهائياً',
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.textSecondary, decoration: TextDecoration.underline),
//                   ),
//                   style: TextButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSectionTitle(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(right: 8.0, bottom: 8, top: 12),
//       child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
//     );
//   }
//
//   Widget _buildSettingsTile({
//     required String title,
//     required String sub,
//     required IconData icon,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(16),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             children: [
//               Icon(icon, color: AppColors.textSecondary),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo')),
//                     Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Cairo')),
//                   ],
//                 ),
//               ),
//               const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/customer_screen/profile/WaslHelpCenterScreen.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/services/auth_service.dart';

class WaslSettingsScreen extends StatefulWidget {
  const WaslSettingsScreen({Key? key}) : super(key: key);

  @override
  State<WaslSettingsScreen> createState() => _WaslSettingsScreenState();
}

class _WaslSettingsScreenState extends State<WaslSettingsScreen> {
  bool _isDarkMode = false;

  String _userName = 'جاري التحميل...';
  String _userPhone = '';
  String _userRole = 'عميل';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'مستخدم فلاش';
      _userPhone = prefs.getString('user_phone') ?? '';

      String role = prefs.getString('user_role') ?? 'customer';
      _userRole = role == 'customer' ? 'عميل مميز' : 'كابتن فلاش';
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل الخروج بنجاح، نراك قريباً! 👋', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
          (route) => false,
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                SizedBox(width: 8),
                Text(
                  'حذف الحساب نهائياً',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء سيؤدي إلى إزالة كافة بياناتك، طلباتك السابقة، ومحفظتك اللوجستية من السيرفر نهائياً ولا يمكن التراجع عنه.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo', height: 1.5),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );

                  final Map<String, dynamic> result = await FlutterAuthService().deleteUserAccount(_userPhone);

                  if (!mounted) return;
                  Navigator.pop(context);

                  if (result['success']) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف حسابك وبياناتك من السيرفر بنجاح.', style: TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const WaslLoginScreen()),
                          (route) => false,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'فشلت عملية حذف الحساب، يرجى المحاولة لاحقاً', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'نعم، احذف الحساب',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                ),
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'الإعدادات',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          child: const Icon(Icons.person_rounded, size: 36, color: AppColors.white)
                      ),
                      const SizedBox(height: 12),
                      Text(_userName, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 2),
                      Text(
                        '$_userRole • $_userPhone',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildSectionTitle('الحساب'),
                _buildSettingsTile(
                  title: 'معلومات الحساب',
                  sub: 'الاسم، البريد الإلكتروني، رقم الهاتف',
                  icon: Icons.person_outline_rounded,
                  onTap: () {},
                ),
                _buildSettingsTile(
                  title: 'إعدادات التنبيهات',
                  sub: 'الرسائل القصيرة، البريد، الإشعارات',
                  icon: Icons.notifications_none_rounded,
                  onTap: () {},
                ),

                _buildSectionTitle('التفضيلات'),
                _buildSettingsTile(
                  title: 'اللغة',
                  sub: 'العربية (جمهورية مصر العربية)',
                  icon: Icons.language_rounded,
                  onTap: () {},
                ),

                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.dark_mode_outlined, color: AppColors.textSecondary, size: 22),
                          SizedBox(width: 12),
                          Text('الوضع الليلي', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13)),
                        ],
                      ),
                      Switch(
                        value: _isDarkMode,
                        onChanged: (v) => setState(() => _isDarkMode = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                _buildSectionTitle('الأمان والدعم'),
                _buildSettingsTile(
                  title: 'كلمة المرور والحماية',
                  sub: 'تغيير كلمة المرور، المصادقة الثنائية',
                  icon: Icons.shield_outlined,
                  onTap: () {},
                ),
                _buildSettingsTile(
                  title: 'مركز المساعدة',
                  sub: 'تواصل معنا، الأسئلة الشائعة وفريق الدعم',
                  icon: Icons.help_outline_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WaslHelpCenterScreen()),
                    );
                  },
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),

                const SizedBox(height: 10),

                // 🎯 [تم الإصلاح الفوري هنا]: إزالة الـ const واستدعاء AppColors.danger الصحيح
                OutlinedButton.icon(
                  onPressed: _showDeleteAccountDialog,
                  icon: Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.danger),
                  label: const Text(
                    'حذف الحساب نهائياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(color: AppColors.danger, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0, bottom: 8, top: 12),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String sub,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                    const SizedBox(height: 1),
                    Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}