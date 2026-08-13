import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/core/widgets/wasl_authed_image.dart';
import 'package:wasl_app/customer_screen/chat/chat_models.dart';
import 'package:wasl_app/services/chat_service.dart';

/// محادثة الطلب — شاشة واحدة يستخدمها العميل والكابتن.
///
/// نفس أسلوب باقي الشاشات: polling كل ٣ ثواني زي شاشة التتبع، من غير أي
/// بنية تحتية جديدة للـ realtime.
///
/// تعديل السعر بيظهر كبطاقة فيها زرارين صريحين (موافقة / رفض). النص المكتوب
/// في المحادثة مش وسيلة موافقة، ومحدش بيقدر يغيّر السعر من هنا غير بالزرار.
class WaslOrderChatScreen extends StatefulWidget {
  const WaslOrderChatScreen({
    super.key,
    required this.orderId,
    this.orderTitle,
  });

  final int orderId;
  final String? orderTitle;

  @override
  State<WaslOrderChatScreen> createState() => _WaslOrderChatScreenState();
}

class _WaslOrderChatScreenState extends State<WaslOrderChatScreen> {
  final WaslChatService _chat = WaslChatService();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Timer? _pollTimer;
  List<WaslChatMessage> _messages = [];
  Map<int, WaslPriceProposal> _proposals = {};
  int _myUserId = 0;
  String _myRole = 'customer';
  bool _loading = true;
  bool _closed = false;
  bool _sending = false;
  String? _error;

  bool get _isDriver => _myRole == 'delivery';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getInt('user_id') ?? 0;
    _myRole = prefs.getString('user_role') ?? 'customer';

    await _refresh(initial: true);
    await _chat.markRead(widget.orderId);

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh({bool initial = false}) async {
    final lastId = _messages.isEmpty ? null : _messages.last.id;

    final result = await _chat.getMessages(
      widget.orderId,
      after: initial ? null : lastId,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString();
      });
      return;
    }

    final incoming = (result['messages'] as List).cast<WaslChatMessage>();
    final closed = result['closed'] == true;

    // بطاقات السعر بتتحدّث بس لو فيه رسالة سعر جديدة، عشان ما نضربش السيرفر
    // بطلب زيادة كل ٣ ثواني من غير داعي.
    final touchesPrice = incoming.any((message) =>
        message.kind == WaslMessageKind.priceProposal ||
        message.kind == WaslMessageKind.priceDecision);

    setState(() {
      _loading = false;
      _error = null;
      _closed = closed;
      if (incoming.isNotEmpty) _messages = [..._messages, ...incoming];
    });

    if (initial || touchesPrice) await _loadProposals();
    if (incoming.isNotEmpty) {
      await _chat.markRead(widget.orderId);
      _scrollToEnd();
    }
  }

  Future<void> _loadProposals() async {
    final result = await _chat.getPriceProposals(widget.orderId);
    if (!mounted || result['success'] != true) return;

    final list = (result['proposals'] as List).cast<WaslPriceProposal>();
    setState(() {
      _proposals = {for (final proposal in list) proposal.id: proposal};
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  // ─── إجراءات ─────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    final result = await _chat.sendText(widget.orderId, body);
    if (!mounted) return;

    setState(() => _sending = false);
    if (result['success'] == true) {
      _composer.clear();
      await _refresh();
    } else {
      _toast(result['message']?.toString() ?? 'تعذّر الإرسال', error: true);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    final result = await _chat.sendImage(widget.orderId, File(picked.path));
    if (!mounted) return;

    setState(() => _sending = false);
    if (result['success'] == true) {
      await _refresh();
    } else {
      _toast(result['message']?.toString() ?? 'تعذّر إرسال الصورة',
          error: true);
    }
  }

  Future<void> _decide(WaslPriceProposal proposal, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(approve ? 'تأكيد الموافقة' : 'تأكيد الرفض'),
        content: Text(
          approve
              ? 'هتوافق على تعديل سعر المشتريات إلى ${proposal.newItemsPrice.toStringAsFixed(2)} جنيه.'
              : 'هترفض تعديل السعر. الطلب هيفضل بسعره الحالي، والكابتن هو اللي هيقرر خطوته الجاية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.danger,
            ),
            child: Text(approve ? 'موافق' : 'رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _chat.decidePriceProposal(
      widget.orderId,
      proposal.id,
      approve: approve,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      _toast(approve ? 'تمت الموافقة على السعر' : 'تم رفض تعديل السعر');
      await _loadProposals();
      await _refresh();
    } else {
      _toast(result['message']?.toString() ?? 'تعذّر إرسال ردك', error: true);
    }
  }

  Future<void> _openPriceChangeSheet() async {
    final priceController = TextEditingController();
    final reasonController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: WaslSpacing.md,
          right: WaslSpacing.md,
          top: WaslSpacing.md,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + WaslSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'طلب تعديل سعر المشتريات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: WaslSpacing.xs),
            const Text(
              'العميل لازم يوافق قبل ما السعر يتغيّر.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: WaslSpacing.md),
            TextField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'السعر الفعلي (جنيه)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: WaslSpacing.sm),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'السبب (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: WaslSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('إرسال الطلب للعميل'),
              ),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final newPrice = double.tryParse(priceController.text.trim());
    if (newPrice == null || newPrice <= 0) {
      _toast('اكتب سعر صحيح', error: true);
      return;
    }

    final result = await _chat.proposePriceChange(
      widget.orderId,
      newItemsPrice: newPrice,
      reason: reasonController.text.trim(),
    );
    if (!mounted) return;

    if (result['success'] == true) {
      _toast('تم إرسال طلب تعديل السعر');
      await _loadProposals();
      await _refresh();
    } else {
      _toast(result['message']?.toString() ?? 'تعذّر إرسال الطلب', error: true);
    }
  }

  // ─── الواجهة ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0.5,
          title: Text(
            widget.orderTitle ?? 'محادثة الطلب FL-${widget.orderId}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_isDriver && !_closed)
              IconButton(
                tooltip: 'طلب تعديل السعر',
                icon: const Icon(Icons.price_change_outlined),
                onPressed: _openPriceChangeSheet,
              ),
          ],
        ),
        body: Column(
          children: [
            if (_closed) _closedBanner(),
            Expanded(child: _body()),
            if (!_closed) _composerBar(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WaslSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: WaslSpacing.sm),
              Text(
                _error ?? 'ابدأ المحادثة مع الطرف التاني',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(WaslSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _messageTile(_messages[index]),
    );
  }

  Widget _closedBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.border,
      padding: const EdgeInsets.symmetric(
        vertical: WaslSpacing.sm,
        horizontal: WaslSpacing.md,
      ),
      child: const Text(
        'الطلب اتقفل — المحادثة للعرض فقط',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _messageTile(WaslChatMessage message) {
    if (message.kind == WaslMessageKind.priceProposal ||
        message.kind == WaslMessageKind.priceDecision) {
      return _priceCard(message);
    }

    final mine = message.isMine(_myUserId);
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? AppColors.white : AppColors.textPrimary;

    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: WaslSpacing.sm),
        padding: const EdgeInsets.all(WaslSpacing.sm),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentUrl != null) ...[
              WaslAuthedImage(
                path: message.attachmentUrl!,
                width: 220,
                height: 180,
              ),
              if (message.body != null && message.body!.isNotEmpty)
                const SizedBox(height: WaslSpacing.xs),
            ],
            if (message.body != null && message.body!.isNotEmpty)
              Text(message.body!, style: TextStyle(color: textColor)),
            const SizedBox(height: 2),
            Text(
              _timeLabel(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? AppColors.white.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة تعديل السعر. الزرارين بيظهروا للعميل بس، وطالما الطلب لسه مفتوح.
  Widget _priceCard(WaslChatMessage message) {
    final proposal =
        message.proposalId == null ? null : _proposals[message.proposalId];

    final showActions = proposal != null &&
        proposal.isPending &&
        !_isDriver &&
        !_closed &&
        message.kind == WaslMessageKind.priceProposal;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: WaslSpacing.sm),
      padding: const EdgeInsets.all(WaslSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.price_change_outlined,
                  color: AppColors.warning, size: 18),
              SizedBox(width: WaslSpacing.xs),
              Text(
                'تعديل سعر المشتريات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: WaslSpacing.xs),
          Text(
            message.body ?? '',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (proposal != null && !proposal.isPending) ...[
            const SizedBox(height: WaslSpacing.xs),
            Text(
              proposal.status == WaslProposalStatus.approved
                  ? '✅ تمت الموافقة'
                  : '❌ تم الرفض',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: proposal.status == WaslProposalStatus.approved
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: WaslSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decide(proposal, true),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: WaslSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decide(proposal, false),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _composerBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WaslSpacing.sm,
          vertical: WaslSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppColors.primary),
              onPressed: _sending ? null : _sendImage,
            ),
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك…',
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sending ? null : _sendText,
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
