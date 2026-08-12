import 'package:flutter/material.dart';
import 'package:wasl_app/core/theme/app_colors.dart';
import 'package:wasl_app/services/zones_service.dart';

/// Picks one of the approved delivery areas.
///
/// Shared by registration, the Waslly From/To form and the profile screen so
/// there is exactly one place that decides how an area is chosen and what
/// happens when the list can't be loaded. The options come from the server —
/// the app has no built-in list of areas to fall out of date.
class WaslAreaPicker extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;

  /// Pre-selected area id, if any.
  final int? selectedZoneId;

  /// Areas to leave out — used so a Waslly run can't pick the same area twice
  /// in a row when that route isn't offered.
  final Set<int> excludeZoneIds;

  final ValueChanged<WaslZone?> onChanged;

  const WaslAreaPicker({
    super.key,
    required this.onChanged,
    this.label = 'المنطقة',
    this.hint = 'اختر منطقتك',
    this.icon = Icons.location_on_outlined,
    this.selectedZoneId,
    this.excludeZoneIds = const {},
  });

  @override
  State<WaslAreaPicker> createState() => _WaslAreaPickerState();
}

class _WaslAreaPickerState extends State<WaslAreaPicker> {
  final _zonesService = ZonesService();

  List<WaslZone> _zones = [];
  int? _selectedId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedZoneId;
    _load();
  }

  @override
  void didUpdateWidget(covariant WaslAreaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedZoneId != oldWidget.selectedZoneId) {
      setState(() => _selectedId = widget.selectedZoneId);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final zones = await _zonesService.getZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // No silent fallback list: showing invented areas would let someone
        // order to a place the platform does not actually serve.
        _error = 'تعذّر تحميل المناطق، تأكد من الاتصال وحاول مرة أخرى';
        _isLoading = false;
      });
    }
  }

  List<WaslZone> get _options =>
      _zones.where((z) => !widget.excludeZoneIds.contains(z.id)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 4),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        if (_isLoading)
          _shell(
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'جاري تحميل المناطق...',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (_error != null)
          _shell(
            borderColor: AppColors.danger,
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text(
                    'إعادة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          _shell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _options.any((z) => z.id == _selectedId)
                    ? _selectedId
                    : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
                hint: Row(
                  children: [
                    Icon(widget.icon, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      widget.hint,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                items: [
                  for (final zone in _options)
                    DropdownMenuItem(
                      value: zone.id,
                      child: Row(
                        children: [
                          Icon(widget.icon,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            zone.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (id) {
                  setState(() => _selectedId = id);
                  widget.onChanged(
                    id == null
                        ? null
                        : _zones.firstWhere((z) => z.id == id),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _shell({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(WaslSpacing.radiusMd),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      constraints: const BoxConstraints(minHeight: 52),
      child: Center(child: child),
    );
  }
}
