import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/wallet_service.dart';

/// شحن رصيد المحفظة للكابتن.
///
/// الترتيب الحقيقي للعملية، وهو اللي الشاشة دي بتعكسه:
///
///   يختار المبلغ والطريقة → يحوّل بره التطبيق على حساب فودافون كاش /
///   إنستاباي → يرفع صورة التحويل → يبعت الطلب → **قيد المراجعة** → الإدارة
///   تراجع الصورة → توافق فيتضاف الرصيد، أو ترفض فما يتغيرش حاجة.
///
/// عشان كده الشاشة ما بتقولش «تم شحن ١٠٠ جنيه» بعد الإرسال. النسخة القديمة
/// كانت بتقول كده وبتعرض رصيد ما اتغيرش — والفلوس كانت لسه ما اتحركتش أصلاً.
/// الرسالة الصح إن الطلب اتبعت للمراجعة.
class WaslDeliveryPaymentScreen extends StatefulWidget {
  const WaslDeliveryPaymentScreen({Key? key}) : super(key: key);

  @override
  State<WaslDeliveryPaymentScreen> createState() =>
      _WaslDeliveryPaymentScreenState();
}

class _WaslDeliveryPaymentScreenState extends State<WaslDeliveryPaymentScreen> {
  final WaslWalletService _wallet = WaslWalletService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();

  WaslTopUpMethod _method = WaslTopUpMethod.vodafoneCash;
  File? _proofImage;

  double? _balance;
  int _pendingCount = 0;
  bool _isLoadingBalance = true;
  bool _isSubmitting = false;

  String _vodafoneNumber = '';
  String _instapayHandle = '';
  String _instructions = '';
  double _minAmount = 0;
  double _maxAmount = 0;

  List<WaslTopUpRequest> _history = const [];
  bool _isLoadingHistory = true;

  final List<int> _quickAmounts = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  /// الرصيد وسجل الطلبات مع بعض — الاتنين بيتغيروا بعد أي مراجعة من الإدارة.
  Future<void> _refresh() async {
    await Future.wait([_loadBalance(), _loadHistory()]);
  }

  /// 💰 المصدر الوحيد للرصيد: `/wallet/summary` — محفظة صاحب التوكن، من غير
  /// أي رقم كابتن متخزّن محلياً ممكن يكون قديم أو غلط.
  Future<void> _loadBalance() async {
    final result = await _wallet.getSummary();
    if (!mounted) return;
    setState(() {
      _isLoadingBalance = false;
      if (result['success'] == true) {
        // من غير قيمة افتراضية: لو القراءة فشلت الشاشة بتقول إنها فشلت بدل ما
        // تعرض رقم مخترع.
        _balance = (result['balance'] as num?)?.toDouble() ??
            double.tryParse(result['balance']?.toString() ?? '');
        _pendingCount = (result['pendingTopUpCount'] as num?)?.toInt() ?? 0;
      }
    });
  }

  Future<void> _loadHistory() async {
    final result = await _wallet.getMyRequests();
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = false;
      if (result['success'] == true) {
        _history = (result['requests'] as List).cast<WaslTopUpRequest>();
      }
    });
  }

  Future<void> _loadAccounts() async {
    final result = await _wallet.getPaymentAccounts();
    if (!mounted || result['success'] != true) return;
    setState(() {
      _vodafoneNumber = result['vodafoneCash']?.toString() ?? '';
      _instapayHandle = result['instapay']?.toString() ?? '';
      _instructions = result['instructions']?.toString() ?? '';
      _minAmount = (result['minAmount'] as num?)?.toDouble() ?? 0;
      _maxAmount = (result['maxAmount'] as num?)?.toDouble() ?? 0;
    });
  }

  String get _accountForMethod => _method == WaslTopUpMethod.vodafoneCash
      ? _vodafoneNumber
      : _instapayHandle;

  Future<void> _pickProof(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _proofImage = File(picked.path));
  }

  void _showProofSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('اختيار من الصور',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProof(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('التقاط صورة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickProof(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _toast('برجاء إدخال مبلغ شحن صحيح أولاً ⚠️', AppColors.danger);
      return;
    }
    // فحص محلي مجاملة للكابتن. الحدود الحقيقية على السيرفر، وهو اللي بيرفض.
    if (_minAmount > 0 && amount < _minAmount) {
      _toast('أقل مبلغ للشحن هو ${_minAmount.toStringAsFixed(0)} ج.م',
          AppColors.danger);
      return;
    }
    if (_maxAmount > 0 && amount > _maxAmount) {
      _toast('أقصى مبلغ للشحن هو ${_maxAmount.toStringAsFixed(0)} ج.م',
          AppColors.danger);
      return;
    }
    if (_proofImage == null) {
      _toast('لازم ترفع صورة التحويل عشان الإدارة تراجعها 📸',
          AppColors.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _wallet.submitTopUp(
      amount: amount,
      method: _method,
      proofImage: _proofImage!,
      senderReference: _senderController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      _toast(result['message']?.toString() ?? 'فشل إرسال طلب الشحن',
          AppColors.danger);
      return;
    }

    _amountController.clear();
    _senderController.clear();
    setState(() => _proofImage = null);
    await _refresh();
    if (!mounted) return;
    await _showPendingDialog(amount);
  }

  /// الرسالة بعد الإرسال. الطلب اتسجّل، والفلوس **لسه ما اتحركتش**.
  Future<void> _showPendingDialog(double amount) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.hourglass_top_rounded,
              color: AppColors.warning, size: 40),
          title: const Text(
            'تم إرسال طلب الشحن للمراجعة',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textPrimary),
          ),
          content: Text(
            'طلب شحن ${amount.toStringAsFixed(0)} ج.م تحت المراجعة الآن.\n'
            'سيتم إضافة المبلغ إلى محفظتك بعد تأكيد التحويل.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.6,
                color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تمام',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          'شحن رصيد المحفظة',
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
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('أدخل مبلغ الشحن بالجنيه'),
                    const SizedBox(height: 8),
                    _buildAmountField(),
                    const SizedBox(height: 12),
                    _buildQuickAmounts(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('اختر طريقة التحويل'),
                    const SizedBox(height: 10),
                    _buildMethodTile(
                      method: WaslTopUpMethod.vodafoneCash,
                      sub: 'حوّل على رقم المحفظة الموضح بالأسفل',
                      icon: Icons.phone_android_rounded,
                    ),
                    _buildMethodTile(
                      method: WaslTopUpMethod.instapay,
                      sub: 'حوّل على حساب إنستاباي الموضح بالأسفل',
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTransferInstructions(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('رقم المُرسِل (اختياري)'),
                    const SizedBox(height: 8),
                    _buildSenderField(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('صورة التحويل (مطلوبة)'),
                    const SizedBox(height: 8),
                    _buildProofPicker(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 28),
                    _buildHistory(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── الرصيد ───────────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'الرصيد الحالي بالمحفظة',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          if (_isLoadingBalance)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2),
              ),
            )
          else
            Text(
              _balance == null
                  ? 'تعذّر تحميل الرصيد'
                  : '${_balance!.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                  color: _balance == null ? Colors.white70 : AppColors.white,
                  fontSize: _balance == null ? 15 : 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  letterSpacing: -0.5),
            ),
          const SizedBox(height: 12),
          if (_pendingCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'لديك $_pendingCount طلب شحن قيد المراجعة',
                style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security_rounded, color: Colors.amber, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'محفظة رقمية مشفرة وآمنة',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── المبلغ ───────────────────────────────────────────────────────────────

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
        ],
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '0.00',
          hintStyle: const TextStyle(
              fontSize: 16, color: AppColors.textSecondary),
          helperText: _minAmount > 0 && _maxAmount > 0
              ? 'من ${_minAmount.toStringAsFixed(0)} إلى ${_maxAmount.toStringAsFixed(0)} ج.م'
              : null,
          helperStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textSecondary),
          suffixText: 'جنيه مصري',
          suffixStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
          prefixIcon: const Icon(Icons.account_balance_wallet_rounded,
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
    );
  }

  Widget _buildQuickAmounts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _quickAmounts.map((amount) {
        return InkWell(
          onTap: () =>
              setState(() => _amountController.text = amount.toString()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: (MediaQuery.of(context).size.width - 76) / 4,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: Text(
              '+$amount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFamily: 'Cairo'),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── طريقة التحويل وبياناتها ─────────────────────────────────────────────

  Widget _buildMethodTile({
    required WaslTopUpMethod method,
    required String sub,
    required IconData icon,
  }) {
    final isSelected = _method == method;
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
        onTap: () => setState(() => _method = method),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.06)
                      : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo')),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Cairo')),
                  ],
                ),
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

  Widget _buildTransferInstructions() {
    final account = _accountForMethod;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حوّل المبلغ إلى ${_method.label}',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          if (account.isEmpty)
            const Text(
              'لم تُضبط بيانات التحويل بعد. تواصل مع الإدارة.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.danger),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    account,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.primary),
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ',
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: account));
                    _toast('تم نسخ بيانات التحويل', AppColors.success);
                  },
                ),
              ],
            ),
          if (_instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _instructions,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  height: 1.6,
                  color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSenderField() {
    return TextField(
      controller: _senderController,
      keyboardType: TextInputType.text,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: 'رقم المحفظة أو الحساب اللي حوّلت منه',
        hintStyle: const TextStyle(
            fontSize: 12,
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
    );
  }

  // ─── صورة التحويل ────────────────────────────────────────────────────────

  Widget _buildProofPicker() {
    return InkWell(
      onTap: _showProofSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _proofImage == null
                ? const Color(0xFFF1F5F9)
                : AppColors.success,
            width: _proofImage == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _proofImage == null
                  ? Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFF8FAFC),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.textSecondary, size: 22),
                    )
                  : Image.file(_proofImage!,
                      width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _proofImage == null
                    ? 'ارفع صورة إيصال التحويل — بدونها لا يمكن مراجعة الطلب'
                    : 'تم إرفاق صورة التحويل. اضغط للتغيير.',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _proofImage == null
                        ? AppColors.textSecondary
                        : AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _submit,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.send_rounded, size: 20),
      label: Text(
          _isSubmitting ? 'جاري إرسال الطلب...' : 'تأكيد طلب الشحن',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Cairo')),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(54),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  // ─── سجل الطلبات ─────────────────────────────────────────────────────────

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('طلبات الشحن السابقة'),
        const SizedBox(height: 10),
        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('لا توجد طلبات شحن سابقة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          )
        else
          ..._history.map(_buildHistoryRow),
      ],
    );
  }

  Widget _buildHistoryRow(WaslTopUpRequest request) {
    final (color, icon) = switch (request.status) {
      WaslTopUpStatus.approved => (AppColors.success, Icons.check_circle_rounded),
      WaslTopUpStatus.rejected => (AppColors.danger, Icons.cancel_rounded),
      WaslTopUpStatus.pending => (AppColors.warning, Icons.hourglass_top_rounded),
    };
    final created = request.createdAt;
    final date = created == null
        ? ''
        : '${created.year}/${created.month.toString().padLeft(2, '0')}/${created.day.toString().padLeft(2, '0')}'
            ' ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.amount.toStringAsFixed(2)} ج.م • ${request.method.label}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(request.status.label,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                    const SizedBox(width: 8),
                    Text(date,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            color: AppColors.textSecondary)),
                  ],
                ),
                // سبب الرفض بييجي من الإدارة، والكابتن لازم يشوفه عشان يعرف
                // يصلّح إيه في المحاولة الجاية.
                if (request.status == WaslTopUpStatus.rejected &&
                    (request.adminNote?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text('سبب الرفض: ${request.adminNote}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.danger)),
                ],
                if (request.isPending) ...[
                  const SizedBox(height: 6),
                  const Text(
                      'سيتم إضافة المبلغ إلى محفظتك بعد تأكيد التحويل.',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
