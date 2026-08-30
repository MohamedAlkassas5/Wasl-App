// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// // 🎯 استيراد كلاس الألوان الموحد الخاص بهوية وصل الجديدة
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
//       _userName = prefs.getString('user_name') ?? 'مستخدم وصل';
//       _userPhone = prefs.getString('user_phone') ?? '';
//
//       String role = prefs.getString('user_role') ?? 'customer';
//       _userRole = role == 'customer' ? 'عميل مميز' : 'كابتن وصل';
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
//           'وصل • FLASH',
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
//                 // كارت الهوية الشخصية الموحد بنظام الـ Gradients لوصل
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
import 'package:wasl_app/screens/WaslForgotPasswordScreen.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/services/push_service.dart';
import 'package:wasl_app/core/widgets/wasl_area_picker.dart';
import 'package:wasl_app/services/profile_service.dart';
import 'package:wasl_app/services/zones_service.dart';

class WaslSettingsScreen extends StatefulWidget {
  const WaslSettingsScreen({Key? key}) : super(key: key);

  @override
  State<WaslSettingsScreen> createState() => _WaslSettingsScreenState();
}

class _WaslSettingsScreenState extends State<WaslSettingsScreen> {
  String _userName = '';
  String _userPhone = '';
  String _userEmail = '';
  String _userRole = 'عميل';
  bool _isCustomer = true;

  final _profileService = ProfileService();

  /// The saved delivery area. It decides the delivery fee, so it is shown and
  /// editable here rather than buried.
  int? _areaId;
  String? _areaName;
  bool _isSavingArea = false;

  /// Whether the profile request is still running, and why it failed if it
  /// did. Previously the screen just showed cached values with no way to tell
  /// stale data from fresh.
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    // Cached values paint immediately so the header isn't blank, then the
    // server's answer replaces them — it is the authority on all of this.
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'customer';
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _userPhone = prefs.getString('user_phone') ?? '';
      _isCustomer = role == 'customer';
      _userRole = _isCustomer ? 'عميل مميز' : 'كابتن وصل';
      _areaId = prefs.getInt('customer_zone_id');
    });

    final profile = await _profileService.getMe();
    if (!mounted) return;

    if (profile['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError =
            (profile['message'] ?? 'تعذّر تحميل بيانات حسابك').toString();
      });
      return;
    }

    final data = profile['data'] as Map<String, dynamic>;
    final zone = data['customerZone'];
    setState(() {
      _isLoading = false;
      _userName = data['name']?.toString() ?? _userName;
      _userPhone = data['phone']?.toString() ?? _userPhone;
      _userEmail = data['email']?.toString() ?? '';
      _isCustomer = data['role']?.toString() == 'customer';
      _userRole = _isCustomer ? 'عميل مميز' : 'كابتن وصل';
      _areaId = (zone?['id'] as num?)?.toInt();
      _areaName = zone?['name']?.toString();
    });

    await prefs.setString('user_name', _userName);
    await prefs.setString('user_phone', _userPhone);
    if (_areaId != null) {
      await prefs.setInt('customer_zone_id', _areaId!);
    } else {
      await prefs.remove('customer_zone_id');
    }
  }

  /// Edits name and email. The phone is shown but not editable — it is the
  /// login identifier and changing it needs a fresh WhatsApp verification.
  Future<void> _showEditProfileSheet() async {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'معلومات الحساب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sheetLabel('الاسم'),
                    TextFormField(
                      controller: nameController,
                      decoration: _sheetInput('اسمك بالكامل'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.length < 2) return 'الاسم قصير جداً';
                        if (text.length > 100) return 'الاسم طويل جداً';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _sheetLabel('البريد الإلكتروني (اختياري)'),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _sheetInput('example@mail.com'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return null; // clearing is allowed
                        final looksValid =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                        return looksValid ? null : 'بريد إلكتروني غير صحيح';
                      },
                    ),
                    const SizedBox(height: 16),
                    _sheetLabel('رقم الهاتف'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _userPhone,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.lock_outline_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 4),
                      child: Text(
                        'رقم الهاتف هو معرّف الدخول، وتغييره محتاج تحقق جديد بواتساب',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);

                              final result = await _profileService.updateProfile(
                                name: nameController.text.trim(),
                                email: emailController.text.trim(),
                              );
                              if (!sheetContext.mounted) return;

                              if (result['success'] != true) {
                                setSheetState(() => isSaving = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      (result['message'] ?? 'تعذّر الحفظ')
                                          .toString(),
                                      style: const TextStyle(fontFamily: 'Cairo'),
                                    ),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(sheetContext);
                              if (!mounted) return;
                              await _loadUserData();
                              if (!mounted) return;
                              _showSnack(
                                  'تم حفظ بياناتك بنجاح', AppColors.success);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              'حفظ التعديلات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
      );

  InputDecoration _sheetInput(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Future<void> _saveArea(WaslZone? zone) async {
    if (zone == null || zone.id == _areaId) return;

    setState(() => _isSavingArea = true);
    final result = await _profileService.updateArea(zone.id);
    if (!mounted) return;
    setState(() => _isSavingArea = false);

    if (result['success'] != true) {
      _showSnack(
        (result['message'] ?? 'تعذّر تحديث المنطقة').toString(),
        AppColors.danger,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('customer_zone_id', zone.id);
    if (!mounted) return;
    setState(() {
      _areaId = zone.id;
      _areaName = zone.name;
    });
    _showSnack('تم تحديث منطقتك إلى ${zone.name}', AppColors.success);
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
    // 🔔 قبل مسح الجلسة: مسار إلغاء تسجيل الجهاز محمي بالتوكن، ولو مسحناه
    // الأول الطلب هيترفض والجهاز هيفضل مسجّل على الحساب ده.
    await WaslPushService.instance.stop();

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
            // النص ده بيوصف اللي بيحصل فعلاً. النسخة القديمة كانت بتوعد بمسح
            // الطلبات السابقة كمان — وده مش بيحصل، لأن الطلب فيه سجل توصيل
            // وعمولة تخص الكابتن، ومينفعش حساب العميل يمسح تاريخ حد تاني.
            content: const Text(
              'هل أنت متأكد؟ هيتم مسح اسمك وبريدك وبياناتك الشخصية نهائياً، ورقم هاتفك هيرجع متاح للتسجيل من جديد.\n\nسجلات الطلبات السابقة بتفضل محفوظة بدون بياناتك الشخصية، لأنها مرتبطة بحسابات الكباتن اللي نفّذوها.',
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
                      if (_isLoading && _userName.isEmpty)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      else
                        Text(_userName.isEmpty ? 'مستخدم وصل' : _userName, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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

                // A failed profile load is stated plainly with a way to retry,
                // instead of silently leaving stale cached values on screen.
                if (_loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadUserData,
                          child: const Text('إعادة',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                _buildSectionTitle('الحساب'),
                _buildSettingsTile(
                  title: 'معلومات الحساب',
                  sub: _userEmail.isEmpty
                      ? 'الاسم والبريد الإلكتروني'
                      : _userEmail,
                  icon: Icons.person_outline_rounded,
                  onTap: _isLoading ? null : _showEditProfileSheet,
                ),

                // 🗑️ "إعدادات التنبيهات" اتشالت: مكانش وراها أي مسار في
                // السيرفر — مفيش تفضيلات إشعارات مخزّنة أصلاً، فالتبويب كان
                // بيوعد بحاجة مش موجودة.

                _buildSectionTitle('التفضيلات'),

                // 📍 منطقة التوصيل — دي اللي بتحدد سعر التوصيل، فبتتغير من هنا
                // على طول من غير ما العميل يضطر يكلّم الدعم.
                if (_isCustomer)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WaslAreaPicker(
                          label: 'منطقة التوصيل',
                          hint: _areaName ?? 'اختر منطقتك',
                          selectedZoneId: _areaId,
                          onChanged: _isSavingArea ? (_) {} : _saveArea,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 4),
                          child: Text(
                            _isSavingArea
                                ? 'جاري الحفظ...'
                                : 'سعر التوصيل بيتحدد حسب المنطقة دي',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // اللغة: عرض فقط. التطبيق عربي بالكامل ومفيش لغة تانية
                // يتبدّل ليها، فبقى صف معلومات مش زرار بيدوس على الفاضي.
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.language_rounded, color: AppColors.textSecondary, size: 22),
                      SizedBox(width: 12),
                      Text('اللغة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13)),
                      Spacer(),
                      Text('العربية', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
                    ],
                  ),
                ),

                // 🗑️ مفتاح "الوضع الليلي" اتشال: مكانش موصّل بأي theme —
                // كان بيتحرك ومايغيرش حاجة في التطبيق.

                _buildSectionTitle('الأمان والدعم'),
                _buildSettingsTile(
                  title: 'تغيير كلمة المرور',
                  sub: 'عن طريق رمز تحقق على واتساب',
                  icon: Icons.shield_outlined,
                  // يعيد استخدام مسار "نسيت كلمة المرور" الموجود، اللي بيتحقق
                  // من الرقم بـ OTP قبل ما يغيّر الكلمة. مفيش مصادقة ثنائية في
                  // النظام، فاتشالت من العنوان بدل ما نوعد بيها.
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WaslForgotPasswordScreen(),
                    ),
                  ),
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

  /// `onTap: null` disables the row — used while the profile is still loading,
  /// so a tap can't open an editor over data that hasn't arrived.
  Widget _buildSettingsTile({
    required String title,
    required String sub,
    required IconData icon,
    required VoidCallback? onTap,
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