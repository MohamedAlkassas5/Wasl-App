import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../ui/wasl_async.dart';
import '../ui/wasl_failure.dart';

/// عرض موحّد لحالات التحميل/الفراغ/الخطأ.
///
/// قبل ده كانت كل شاشة بتكتب الحالات دي بنفسها — spinner هنا، رسالة خطأ
/// إنجليزية هناك، وشاشة تالتة بتعرض قايمة فاضية من غير ما تقول ليه. النتيجة
/// إن المستخدم كان بيشوف تجربة مختلفة في كل شاشة، والأسوأ إن شاشات كتير
/// مكانش عندها زرار «إعادة المحاولة» أصلاً فالحل الوحيد كان قفل التطبيق.
///
/// الويدجت دي بتاخد [WaslAsync] وبترسم الحالة الصح:
///
///  * **بيحمّل** — مؤشر تحميل في النص.
///  * **فشل** — رسالة عربية + «إعادة المحاولة» لو الفشل يستاهل إعادة، وشريط
///    «مفيش اتصال» لو السبب الشبكة.
///  * **فاضي** — نص واضح بدل صفحة بيضا.
///  * **فيه بيانات** — [builder].
class WaslAsyncView<T> extends StatelessWidget {
  const WaslAsyncView({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'لا توجد طلبات حالياً',
    this.emptyIcon = Icons.inbox_rounded,
    this.loadingBuilder,
  });

  final WaslAsync<T> state;

  /// يرسم المحتوى لما البيانات تكون موجودة.
  final Widget Function(BuildContext context, T value) builder;

  /// يعيد المحاولة. لو null، مفيش زرار إعادة.
  final VoidCallback? onRetry;

  /// امتى تعتبر البيانات «فاضية». لو null، مفيش حالة فراغ.
  final bool Function(T value)? isEmpty;

  final String emptyMessage;
  final IconData emptyIcon;

  /// بديل لمؤشر التحميل الافتراضي (مثلاً skeleton).
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final current = state;

    if (current is WaslAsyncLoading<T>) {
      return loadingBuilder?.call(context) ?? const _Loading();
    }

    if (current is WaslAsyncFailure<T>) {
      return _Failure(
        failure: current.failure,
        // زرار إعادة بيفشل كل مرة أسوأ من مفيش زرار — بنعرضه بس لما يكون
        // فيه أمل حقيقي إن المحاولة التانية تنجح.
        onRetry: current.failure.isRetryable ? onRetry : null,
      );
    }

    final value = (current as WaslAsyncData<T>).value;
    if (isEmpty?.call(value) ?? false) {
      return _Empty(message: emptyMessage, icon: emptyIcon, onRetry: onRetry);
    }

    return builder(context, value);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.failure, this.onRetry});

  final WaslFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure.isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 46,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              // نص عربي جاهز للعرض — الاستثناء الأصلي بيفضل في technicalDetail
              // ومابيوصلش هنا.
              failure.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.icon, this.onRetry});

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شريط «مفيش اتصال» بيتعرض فوق المحتوى.
///
/// بيظهر بناءً على فشل طلب حقيقي، مش على حالة الشبكة في النظام: اللي يهم
/// المستخدم هو إحنا قدرنا نكلّم السيرفر ولا لأ، والموبايل ممكن يكون متصل
/// بواي فاي من غير إنترنت.
class WaslOfflineBanner extends StatelessWidget {
  const WaslOfflineBanner({super.key, required this.visible, this.onRetry});

  final bool visible;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF334155),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
