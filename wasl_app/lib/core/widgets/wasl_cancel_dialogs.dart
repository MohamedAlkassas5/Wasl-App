import 'package:flutter/material.dart';

import 'package:wasl_app/core/theme/app_colors.dart';

/// حوارات تأكيد الإلغاء — المكان الوحيد اللي بيتشرح فيه قرار الإلغاء للمستخدم.
///
/// كلها في ملف واحد عشان الصياغة تفضل متسقة بين العميل والكابتن: نفس الفعل
/// بيتقال بنفس الكلام في الشاشتين، والقاعدة المالية بتتكتب مرة واحدة.
///
/// ⚠️ ولا واحد منهم بيحسب فلوس. المبالغ اللي بتتعرض إما جاية من الطلب نفسه
/// (رسوم التوصيل) أو من رد السيرفر بعد الخصم. التطبيق ما بيقدرش يقرأ نسبة
/// الغرامة — دي إعداد للأدمن بس — فما بيدّعيش إنه عارفها.

/// سبب مكتوب + تأكيد. بترجّع السبب، أو `null` لو المستخدم رجع.
///
/// السبب مطلوب على السيرفر في الحالتين (٣ حروف على الأقل)، فالحوار ده
/// بيتحقق منه قبل ما يبعت بدل ما يستنى ٤٠٠ ويعرض رسالة غامضة.
Future<String?> showWaslReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? warning,
  Color? confirmColor,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (warning != null) ...[
              const SizedBox(height: 12),
              _WarningBox(text: warning),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء',
                hintText: 'اكتب السبب باختصار',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 3) return 'اكتب سبب واضح (٣ حروف على الأقل)';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('تراجع'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.pop(dialogContext, controller.text.trim());
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// تأكيد بسيط من غير سبب مكتوب. بترجّع `true` لو أكّد.
Future<bool> showWaslConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? highlight,
  Color? confirmColor,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (highlight != null) ...[
            const SizedBox(height: 12),
            _WarningBox(text: highlight, tone: _Tone.calm),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('تراجع'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

enum _Tone { warning, calm }

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text, this.tone = _Tone.warning});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final isWarning = tone == _Tone.warning;
    final color = isWarning ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: color.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
