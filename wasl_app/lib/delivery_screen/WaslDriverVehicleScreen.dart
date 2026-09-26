import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/vehicle_service.dart';

/// بيانات المركبة — عرض وتعديل.
///
/// الكابتن بيعدّل نوع المركبة ورقم اللوحة بس. الوثائق اللي الإدارة وافقت
/// عليها وحالة التوثيق بتتعرض للقراءة بس — لو الكابتن قدر يغيّرها من هنا يبقى
/// بيعدّل نتيجة توثيق نفسه، والسيرفر رافض ده أصلاً (`UpdateVehicleDto`).
class WaslDriverVehicleScreen extends StatefulWidget {
  const WaslDriverVehicleScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverVehicleScreen> createState() =>
      _WaslDriverVehicleScreenState();
}

class _WaslDriverVehicleScreenState extends State<WaslDriverVehicleScreen> {
  final WaslVehicleService _service = WaslVehicleService();
  final TextEditingController _plateController = TextEditingController();

  WaslVehicleType? _vehicleType;
  String _verificationStatus = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.getMyVehicle();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _vehicleType = WaslVehicleType.fromWire(result['vehicleType']?.toString());
        _plateController.text = result['licenseNumber']?.toString() ?? '';
        _verificationStatus = result['verificationStatus']?.toString() ?? '';
      } else {
        _error = result['message']?.toString() ?? 'تعذّر تحميل بيانات المركبة';
      }
    });
  }

  Future<void> _save() async {
    if (_vehicleType == null) return;
    setState(() => _isSaving = true);

    final result = await _service.updateMyVehicle(
      vehicleType: _vehicleType!,
      licenseNumber: _plateController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (result['message']?.toString() ?? 'تم حفظ بيانات المركبة')
              : (result['message']?.toString() ?? 'تعذّر حفظ البيانات'),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
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
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'بيانات المركبة',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: const Text('حاول تاني',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVerificationBanner(),
          const SizedBox(height: 22),
          _label('نوع المركبة'),
          const SizedBox(height: 10),
          ...WaslVehicleType.values.map(_buildTypeTile),
          const SizedBox(height: 20),
          _label('رقم اللوحة / الرخصة'),
          const SizedBox(height: 8),
          TextField(
            controller: _plateController,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'مثال: أ ب ج 1234',
              hintStyle: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.textSecondary, size: 20),
              fillColor: AppColors.white,
              filled: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التعديلات',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'صور المركبة والوثائق اللي رفعتها وقت التسجيل بتتغيّر من الإدارة '
            'فقط — تعديل نوع المركبة أو رقم اللوحة هنا ما بيأثرش على حالة '
            'توثيق حسابك.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                height: 1.7,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    final (label, color) = switch (_verificationStatus) {
      'approved' => ('مركبتك موثّقة ومعتمدة ✅', AppColors.success),
      'rejected' => ('التوثيق مرفوض — راجع الإدارة ❌', AppColors.danger),
      _ => ('بيانات المركبة تحت المراجعة ⏳', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTile(WaslVehicleType type) {
    final isSelected = _vehicleType == type;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _vehicleType = type),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.06)
                      : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(type.icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(type.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontFamily: 'Cairo')),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFCBD5E1),
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo')),
      );
}
