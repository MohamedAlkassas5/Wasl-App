import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

class WaslHelpCenterScreen extends StatelessWidget {
  const WaslHelpCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'مركز المساعدة',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كيف يمكننا مساعدتك اليوم؟',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Cairo', letterSpacing: -0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تواصل معنا أو تصفح الأسئلة الشائعة لحل مشكلتك فوراُ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 🔍 صندوق البحث الاحترافي والناعم (Minimalistic Help Search)
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: AppColors.textPrimary.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مشاكل حسابك أو الأسئلة الشائعة...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                      fillColor: AppColors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'تصفح الفئات',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCategoryCard('الطلبات والشحن', Icons.receipt_long_rounded, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCategoryCard('إعدادات الحساب', Icons.person_outline_rounded, const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 16),

                // ⚡ كارت مشاكل التوصيل بالتدرج اللوني الفخم للـ Gradients المشفرة لـ فلاش
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.local_shipping_rounded, color: Colors.amber, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('مشاكل التوصيل الشائعة', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                            const SizedBox(height: 2),
                            Text(
                              'هل تأخر طلبك أو واجهت مشكلة مع الكابتن؟ سنقوم بحلها فوراً داخل مركز كوم حمادة.',
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11, fontFamily: 'Cairo', height: 1.4),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'الأسئلة الشائعة الأكثر زيارة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                _buildExpansionTile('كيف يمكنني تتبع طلبي في الوقت الفعلي؟', 'بمجرد قبول المندوب لطلبك اللوجستي الموحد، يمكنك تتبع حركته مباشرة ثانية بثانية عبر الـ GPS المدمج بخرائط فلاش للتوصيل السريع.'),
                _buildExpansionTile('ما هي طرق الدفع المتاحة في تطبيق فلاش؟', 'نوفر حالياً نظام الدفع النقدي (كاش) فور استلام الشحنة والمشتريات من الكابتن، وجاري دمج المحفظة الرقمية لـ فلاش لتسهيل التحويلات البنكية لاحقاً.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 12))
        ],
      ),
    );
  }

  Widget _buildExpansionTile(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo'),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Text(
                content,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.5, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
              ),
            )
          ],
        ),
      ),
    );
  }
}