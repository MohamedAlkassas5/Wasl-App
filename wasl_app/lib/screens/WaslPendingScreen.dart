import 'package:flutter/material.dart';
import 'package:wasl_app/services/auth_service.dart';
import 'package:wasl_app/screens/WaslLoginScreen.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/delivery_screen/WaslDriverHomeScreen.dart';

class WaslPendingScreen extends StatefulWidget {
  final String phone;
  final String initialNotes;
  final String role;

  const WaslPendingScreen({
    Key? key,
    required this.phone,
    this.initialNotes = '',
    this.role = 'delivery',
  }) : super(key: key);

  @override
  State<WaslPendingScreen> createState() => _WaslPendingScreenState();
}

class _WaslPendingScreenState extends State<WaslPendingScreen> {
  String _currentStatus = 'pending';
  String _adminNotes = '';
  String _userRole = 'delivery';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _adminNotes = widget.initialNotes;
    _userRole = widget.role;
    _checkStatusAutomatically();
  }

  Future<void> _checkStatusAutomatically() async {
    setState(() => _isLoading = true);

    final result = await FlutterAuthService().checkUserStatus(widget.phone);

    if (mounted && result['success']) {
      setState(() {
        _currentStatus = result['status'];
        _adminNotes = result['adminNotes'] ?? '';
        _userRole = result['role'] ?? widget.role;
        _isLoading = false;
      });

      if (_currentStatus == 'active') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تهانينا! تم تفعيل حسابك 🎉', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
          ),
        );

        if (_userRole == 'delivery') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WaslDriverHomeScreen()),
            (route) => false,
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                if (_currentStatus == 'pending') ...[
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.primary),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'حسابك قيد المراجعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'مستنداتك قيد الفحص لضمان أمان عمليات التوصيل. يستغرق الأمر حتى 24 ساعة كحد أقصى.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.initialNotes.isNotEmpty ? widget.initialNotes : 'جاري فحص البيانات والمستندات...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ] else if (_currentStatus == 'rejected') ...[
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gpp_bad_outlined, size: 64, color: AppColors.danger),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'تم رفض طلب الانضمام',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.danger, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.assignment_late_outlined, color: AppColors.danger, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'ملاحظات المراجع:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _adminNotes.isNotEmpty ? _adminNotes : 'يرجى مراجعة وضوح المرفقات وإعادة الرفع.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.change_circle_outlined, color: AppColors.white),
                    label: const Text('تعديل الوثائق وإعادة الإرسال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ],
                const Spacer(),
                if (_currentStatus == 'pending')
                  GestureDetector(
                    onTap: _isLoading ? null : _checkStatusAutomatically,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isLoading ? null : AppColors.logoGradient,
                        color: _isLoading ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.24),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('تحديث حالة الطلب', style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                  SizedBox(width: 8),
                                  Icon(Icons.refresh_rounded, color: AppColors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WaslLoginScreen()),
                    (route) => false,
                  ),
                  child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
