import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/wallet_service.dart';

/// سجل المكافآت والأرباح — كشف حساب المحفظة.
///
/// مفيش سجل أرباح تاني في المشروع، ومش محتاج واحد: كل جنيه دخل أو خرج من
/// محفظة الكابتن مكتوب أصلاً في `wallet_transactions` — عمولة توصيل، شحن
/// معتمد، غرامة إلغاء، أو استرجاع غرامة. الشاشة دي بتقرا نفس السجل من نفس
/// `WaslWalletService` اللي شاشة الشحن بتستعمله، من غير أي مسار جديد على
/// السيرفر ومن غير نسخة تانية من الحسابات.
///
/// **مفيش أي حساب بيتعمل هنا.** `balanceAfter` بيتكتب على السيرفر جوه نفس
/// المعاملة اللي بتحرك الرصيد، فالأرقام دي هي هي اللي في المحفظة — مش مجموع
/// بيتحسب في التطبيق وممكن يختلف.
class WaslDriverEarningsScreen extends StatefulWidget {
  const WaslDriverEarningsScreen({Key? key}) : super(key: key);

  @override
  State<WaslDriverEarningsScreen> createState() =>
      _WaslDriverEarningsScreenState();
}

class _WaslDriverEarningsScreenState extends State<WaslDriverEarningsScreen> {
  final WaslWalletService _wallet = WaslWalletService();

  List<WaslWalletTransaction> _transactions = const [];
  double? _balance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      _wallet.getSummary(),
      _wallet.getTransactions(),
    ]);
    if (!mounted) return;

    final summary = results[0];
    final ledger = results[1];

    setState(() {
      _isLoading = false;
      if (summary['success'] == true) {
        _balance = (summary['balance'] as num?)?.toDouble() ??
            double.tryParse(summary['balance']?.toString() ?? '');
      }
      if (ledger['success'] == true) {
        _transactions =
            (ledger['transactions'] as List).cast<WaslWalletTransaction>();
      } else {
        _error = ledger['message']?.toString() ?? 'تعذّر تحميل السجل';
      }
    });
  }

  /// الاسم العربي لكل نوع حركة، بنفس تسميات السيرفر (`WalletTxType`).
  (String, IconData, Color) _describe(WaslWalletTransaction tx) {
    switch (tx.type) {
      case 'topup':
        return ('شحن رصيد معتمد', Icons.add_card_rounded, AppColors.success);
      case 'commission':
        return ('عمولة توصيل', Icons.percent_rounded, AppColors.danger);
      case 'cancellation_penalty':
        return ('غرامة إلغاء', Icons.cancel_schedule_send_rounded,
            AppColors.danger);
      case 'penalty_refund':
        return ('استرجاع غرامة', Icons.undo_rounded, AppColors.success);
      case 'adjustment':
        return ('تعديل من الإدارة', Icons.tune_rounded, AppColors.warning);
      default:
        return (tx.type, Icons.swap_vert_rounded, AppColors.textSecondary);
    }
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
          'سجل المكافآت والأرباح',
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
          child: RefreshIndicator(
            onRefresh: _load,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 20),
                      const Text(
                        'كل الحركات',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 10),
                      if (_error != null)
                        _buildMessage(_error!, AppColors.danger)
                      else if (_transactions.isEmpty)
                        _buildMessage(
                            'لا توجد حركات على محفظتك حتى الآن.\n'
                            'أول عمولة أو شحن معتمد هيظهر هنا.',
                            AppColors.textSecondary)
                      else
                        ..._transactions.map(_buildRow),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Text('الرصيد الحالي بالمحفظة',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            _balance == null
                ? 'تعذّر تحميل الرصيد'
                : '${_balance!.toStringAsFixed(2)} ج.م',
            style: TextStyle(
                color: _balance == null ? Colors.white70 : AppColors.white,
                fontSize: _balance == null ? 15 : 26,
                fontWeight: FontWeight.w900,
                fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 12, height: 1.6, color: color)),
    );
  }

  Widget _buildRow(WaslWalletTransaction tx) {
    final (label, icon, color) = _describe(tx);
    final created = tx.createdAt;
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                if (tx.note != null && tx.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(tx.note!,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(date,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                // العلامة من إشارة المبلغ نفسه زي ما السيرفر كتبه.
                '${tx.isCredit ? '+' : '−'}${tx.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: tx.isCredit ? AppColors.success : AppColors.danger),
              ),
              const SizedBox(height: 2),
              Text('الرصيد: ${tx.balanceAfter.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
