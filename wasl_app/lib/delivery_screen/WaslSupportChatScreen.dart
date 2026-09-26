import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/support_service.dart';

/// مركز الدعم الفني — محادثة الكابتن مع الإدارة.
///
/// **مش محادثة الطلب.** دي قناة الكابتن مع المنصة نفسها: مشاكل شحن المحفظة،
/// تحويل اتعمل والرصيد ما زادش، مشاكل الحساب. محادثة الطلب بين العميل والكابتن
/// وليها شاشتها.
///
/// الشاشة بتعمل polling كل ٦ ثواني بـ `after` — نفس أسلوب شات الطلب: بتجيب
/// الجديد بس مش المحادثة كلها.
class WaslSupportChatScreen extends StatefulWidget {
  const WaslSupportChatScreen({Key? key}) : super(key: key);

  @override
  State<WaslSupportChatScreen> createState() => _WaslSupportChatScreenState();
}

class _WaslSupportChatScreenState extends State<WaslSupportChatScreen> {
  final WaslSupportService _support = WaslSupportService();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<WaslSupportMessage> _messages = [];
  Timer? _poll;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    // بعد أول تحميل بنطلب اللي بعد آخر رسالة عندنا بس.
    final after = _messages.isEmpty ? null : _messages.last.id;
    final result = await _support.getMessages(after: initial ? null : after);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        if (initial) _error = result['message']?.toString();
      });
      return;
    }

    final incoming =
        (result['messages'] as List).cast<WaslSupportMessage>();

    setState(() {
      _isLoading = false;
      _error = null;
      if (initial) {
        _messages
          ..clear()
          ..addAll(incoming);
      } else {
        // الرد ممكن يوصل مرتين لو الـ polling سبق الإرسال؛ بنمنع التكرار بالـ id.
        final known = _messages.map((m) => m.id).toSet();
        _messages.addAll(incoming.where((m) => !known.contains(m.id)));
      }
    });

    if (incoming.isNotEmpty) {
      // فتح الشاشة أو وصول رد = قراءة.
      await _support.markRead();
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final result = await _support.sendMessage(text);
    if (!mounted) return;

    setState(() => _isSending = false);
    if (result['success'] != true) {
      _toast(result['message']?.toString() ?? 'تعذّر إرسال الرسالة');
      return;
    }

    _composer.clear();
    final sent = result['data'];
    if (sent is WaslSupportMessage) {
      setState(() => _messages.add(sent));
      _scrollToEnd();
    } else {
      await _load();
    }
  }

  Future<void> _attach() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _isSending = true);
    final result = await _support.sendImage(File(picked.path));
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] != true) {
      _toast(result['message']?.toString() ?? 'تعذّر إرسال الصورة');
      return;
    }
    await _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.danger,
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
        title: const Column(
          children: [
            Text('مركز الدعم الفني',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    fontSize: 15)),
            Text('فريق وصل — الرد خلال وقت العمل',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Cairo',
                    fontSize: 10)),
          ],
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildBody()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => _load(initial: true),
                child: const Text('حاول تاني',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: AppColors.primary, size: 38),
          ),
          const SizedBox(height: 18),
          const Text('إزاي نقدر نساعدك؟',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'اكتب مشكلتك وفريق الدعم هيرد عليك هنا.\n'
            'لو المشكلة في شحن المحفظة، ارفق صورة التحويل عشان المراجعة تبقى أسرع.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.8,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(WaslSupportMessage message) {
    if (message.sender == WaslSupportSender.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message.body ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 11.5, height: 1.6)),
        ),
      );
    }

    final mine = message.isMine;
    final created = message.createdAt;
    final time = created == null
        ? ''
        : '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 4 : 16),
            bottomRight: Radius.circular(mine ? 16 : 4),
          ),
          border: mine ? null : Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('فريق الدعم',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Text(message.body!,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.7,
                      color: mine ? AppColors.white : AppColors.textPrimary)),
            if (message.attachmentUrl != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_rounded,
                      size: 14,
                      color: mine ? Colors.white70 : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('صورة مرفقة',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: mine
                              ? Colors.white70
                              : AppColors.textSecondary)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(time,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9,
                    color: mine ? Colors.white60 : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _isSending ? null : _attach,
            icon: const Icon(Icons.attach_file_rounded,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'إرفاق صورة',
          ),
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك للدعم...',
                hintStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSending ? AppColors.textSecondary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
