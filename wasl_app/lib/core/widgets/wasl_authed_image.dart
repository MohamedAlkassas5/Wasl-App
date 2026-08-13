import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:wasl_app/core/config/api_config.dart';
import 'package:wasl_app/core/theme/app_colors.dart';

/// صورة مرفوعة على السيرفر.
///
/// الملفات المرفوعة (صور المحادثة، الفواتير، الروشتات) بقت وراء مسار محمي
/// بتوكن — `Image.network` العادي بيرجّع 401 عليها لأنه مش بيبعت الهيدر.
/// الودجت دي بتجيب البايتات بـ GET عادي مع `Authorization` وبتعرضها من
/// الميموري.
///
/// فيه كاش بسيط في الميموري على مستوى العملية، عشان الـ polling كل ٣ ثواني
/// ما يعيدش تحميل نفس الصورة مع كل تحديث للشاشة.
class WaslAuthedImage extends StatefulWidget {
  const WaslAuthedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// المسار المخزّن في الداتابيز، زي `uploads/chat/chat-…​.jpg`.
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<WaslAuthedImage> createState() => _WaslAuthedImageState();
}

class _WaslAuthedImageState extends State<WaslAuthedImage> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WaslAuthedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final cached = _cache[widget.path];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _failed = false;
      });
      return;
    }

    setState(() {
      _bytes = null;
      _failed = false;
    });

    try {
      final headers = await WaslApiConfig.authHeaders();
      // مش JSON — بنشيل الهيدرز اللي متعلقة بالـ JSON ونسيب التوكن بس.
      headers.remove('Content-Type');
      headers['Accept'] = 'image/*';

      final response = await http
          .get(
            Uri.parse('${WaslApiConfig.baseUrl}/${widget.path}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _cache[widget.path] = response.bodyBytes;
        setState(() => _bytes = response.bodyBytes);
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(WaslSpacing.radiusSm);

    Widget child;
    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _placeholder(icon: Icons.broken_image),
      );
    } else if (_failed) {
      child = InkWell(
        onTap: _load,
        child: _placeholder(icon: Icons.refresh_rounded),
      );
    } else {
      child = _placeholder(loading: true);
    }

    return ClipRRect(borderRadius: radius, child: child);
  }

  Widget _placeholder({IconData? icon, bool loading = false}) {
    return Container(
      width: widget.width,
      height: widget.height ?? 160,
      color: AppColors.background,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: AppColors.textSecondary, size: 28),
    );
  }
}
