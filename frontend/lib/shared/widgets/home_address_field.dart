import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../l10n/app_localizations.dart';
import '../../shared/presentation/theme/theme.dart';

/// A text field with Nominatim (OpenStreetMap) address autocomplete.
/// Debounces queries by 500ms; shows a suggestion card below the field.
class HomeAddressField extends StatefulWidget {
  const HomeAddressField({
    super.key,
    required this.initialAddress,
    required this.onAddressSelected,
  });

  final String initialAddress;

  /// Called when the user selects a suggestion.
  final void Function(String address, double lat, double lng) onAddressSelected;

  @override
  State<HomeAddressField> createState() => _HomeAddressFieldState();
}

class _HomeAddressFieldState extends State<HomeAddressField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  Timer? _debounce;

  bool _loading = false;
  List<_NominatimResult> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialAddress);
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '0',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'FlowShiftApp/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        setState(() {
          _suggestions = list
              .map((e) => _NominatimResult.fromMap(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _suggestions = [];
        _loading = false;
      });
    }
  }

  void _selectSuggestion(_NominatimResult result) {
    _ctrl.text = result.displayName;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    setState(() => _suggestions = []);
    _focus.unfocus();
    widget.onAddressSelected(result.displayName, result.lat, result.lng);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.home_outlined, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)?.homeAddressHint ?? 'Search your home address...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 14, color: AppColors.navySpaceCadet),
              ),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.borderLight),
                  InkWell(
                    onTap: () => _selectSuggestion(_suggestions[i]),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(10))
                        : i == _suggestions.length - 1
                            ? const BorderRadius.vertical(bottom: Radius.circular(10))
                            : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _suggestions[i].displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

}

class _NominatimResult {
  final String displayName;
  final double lat;
  final double lng;

  const _NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory _NominatimResult.fromMap(Map<String, dynamic> map) {
    return _NominatimResult(
      displayName: map['display_name'] as String? ?? '',
      lat: double.tryParse(map['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(map['lon']?.toString() ?? '') ?? 0.0,
    );
  }
}
