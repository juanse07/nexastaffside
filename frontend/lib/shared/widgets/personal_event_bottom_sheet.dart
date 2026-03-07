import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/google_places_service.dart';
import '../presentation/theme/app_colors.dart';

/// Bottom sheet for creating or editing a personal event.
/// Pass [existingEvent] to pre-fill for editing.
/// Pass [onLocalEdit] for local-only editing (bulk import preview) — Save
/// button calls the callback with form data instead of hitting the API.
class PersonalEventBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? existingEvent;
  final void Function(Map<String, dynamic> editedData)? onLocalEdit;

  const PersonalEventBottomSheet({
    super.key,
    this.existingEvent,
    this.onLocalEdit,
  });

  @override
  State<PersonalEventBottomSheet> createState() =>
      _PersonalEventBottomSheetState();
}

class _PersonalEventBottomSheetState extends State<PersonalEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _roleController = TextEditingController();
  final _clientController = TextEditingController();
  final _rateController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;
  List<String> _roleSuggestions = [];
  List<String> _clientSuggestions = [];

  // Places autocomplete state
  List<PlacePrediction> _placePredictions = [];
  bool _loadingPlaces = false;
  Timer? _placeDebounce;
  double? _userLat;
  double? _userLng;

  bool get _isEditing => widget.existingEvent != null && widget.existingEvent!['id'] != null;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
    _getUserLocation();
    if (widget.existingEvent != null) {
      final e = widget.existingEvent!;
      _locationController.text = e['location'] ?? e['venue_name'] ?? '';
      _notesController.text = e['notes'] ?? '';
      _roleController.text = e['personal_role'] ?? e['role'] ?? '';
      _clientController.text = e['personal_client'] ?? e['client'] ?? '';
      final rate = e['personal_hourly_rate'] ?? e['hourlyRate'] ?? e['hourly_rate'];
      if (rate != null && rate != 0) _rateController.text = rate.toString();
      if (e['date'] != null) {
        _selectedDate = DateTime.tryParse(e['date'].toString()) ?? _selectedDate;
      }
      if (e['startTime'] != null || e['start_time'] != null) {
        final t = (e['startTime'] ?? e['start_time']).toString().split(':');
        if (t.length >= 2) {
          _startTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
        }
      }
      if (e['endTime'] != null || e['end_time'] != null) {
        final t = (e['endTime'] ?? e['end_time']).toString().split(':');
        if (t.length >= 2) {
          _endTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
        }
      }
    }
  }

  Future<void> _fetchSuggestions() async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('$_apiBaseUrl$_apiPathPrefix/personal-events/suggestions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _roleSuggestions = List<String>.from(data['roles'] ?? []);
            _clientSuggestions = List<String>.from(data['clients'] ?? []);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    _locationController.dispose();
    _notesController.dispose();
    _roleController.dispose();
    _clientController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
        });
      }
    } catch (_) {}
  }

  void _onLocationChanged(String value) {
    _placeDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _placePredictions = []);
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loadingPlaces = true);
      final predictions = await GooglePlacesService.getPlacePredictions(
        value.trim(),
        userLat: _userLat,
        userLng: _userLng,
      );
      if (mounted) {
        setState(() {
          _placePredictions = predictions;
          _loadingPlaces = false;
        });
      }
    });
  }

  void _selectPlace(PlacePrediction prediction) {
    _locationController.text = prediction.description;
    setState(() => _placePredictions = []);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
    return raw;
  }

  String get _apiPathPrefix {
    final raw = (dotenv.env['API_PATH_PREFIX'] ?? '').trim();
    if (raw.isEmpty) return '';
    final withLead = raw.startsWith('/') ? raw : '/$raw';
    return withLead.endsWith('/')
        ? withLead.substring(0, withLead.length - 1)
        : withLead;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Local-edit mode: return form data without hitting API
    if (widget.onLocalEdit != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final rateVal = double.tryParse(_rateController.text.trim());
      final formData = <String, dynamic>{
        'date': dateStr,
        'startTime': _formatTime(_startTime),
        'endTime': _formatTime(_endTime),
        if (_locationController.text.trim().isNotEmpty)
          'location': _locationController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        if (_roleController.text.trim().isNotEmpty)
          'role': _roleController.text.trim(),
        if (_clientController.text.trim().isNotEmpty)
          'client': _clientController.text.trim(),
        if (rateVal != null && rateVal > 0) 'hourlyRate': rateVal,
      };
      widget.onLocalEdit!(formData);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() => _saving = true);

    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        if (mounted) Navigator.pop(context, false);
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final rateVal = double.tryParse(_rateController.text.trim());
      final body = jsonEncode({
        'date': dateStr,
        'startTime': _formatTime(_startTime),
        'endTime': _formatTime(_endTime),
        if (_locationController.text.trim().isNotEmpty)
          'location': _locationController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        if (_roleController.text.trim().isNotEmpty)
          'role': _roleController.text.trim(),
        if (_clientController.text.trim().isNotEmpty)
          'client': _clientController.text.trim(),
        if (rateVal != null && rateVal > 0)
          'hourlyRate': rateVal,
      });

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      http.Response response;
      if (_isEditing) {
        final id = widget.existingEvent!['id'];
        response = await http.put(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/personal-events/$id'),
          headers: headers,
          body: body,
        );
      } else {
        response = await http.post(
          Uri.parse('$_apiBaseUrl$_apiPathPrefix/personal-events'),
          headers: headers,
          body: body,
        );
      }

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        Navigator.pop(context, true);
      } else if (response.statusCode == 402) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.personalEventRequiresPro),
          ),
        );
        setState(() => _saving = false);
      } else {
        final msg = jsonDecode(response.body)['message'] ?? 'Error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.personalEventLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: AppColors.personalEvent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? l10n.editPersonalEvent : l10n.addPersonalEvent,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Date picker
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.personalEventDate,
                        filled: true,
                        fillColor: AppColors.formFillLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today_rounded,
                            size: 20, color: AppColors.personalEvent),
                      ),
                      child: Text(
                        DateFormat('EEEE, MMM d, y').format(_selectedDate),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start / End time row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isStart: true),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.personalEventStartTime,
                              filled: true,
                              fillColor: AppColors.formFillLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              suffixIcon: const Icon(Icons.access_time_rounded,
                                  size: 20, color: AppColors.personalEvent),
                            ),
                            child: Text(
                              _startTime.format(context),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isStart: false),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.personalEventEndTime,
                              filled: true,
                              fillColor: AppColors.formFillLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              suffixIcon: const Icon(Icons.access_time_rounded,
                                  size: 20, color: AppColors.personalEvent),
                            ),
                            child: Text(
                              _endTime.format(context),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Role + Client row (optional)
                  Row(
                    children: [
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (v) => _roleSuggestions
                              .where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
                          fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                            // Sync controller text
                            if (ctrl.text.isEmpty && _roleController.text.isNotEmpty) {
                              ctrl.text = _roleController.text;
                            }
                            _roleController.addListener(() {
                              if (ctrl.text != _roleController.text) ctrl.text = _roleController.text;
                            });
                            ctrl.addListener(() => _roleController.text = ctrl.text);
                            return TextFormField(
                              controller: ctrl,
                              focusNode: fn,
                              decoration: InputDecoration(
                                labelText: 'Role',
                                hintText: 'e.g. Bartender',
                                filled: true,
                                fillColor: AppColors.formFillLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.personalEvent, width: 1.5),
                                ),
                                prefixIcon: const Icon(Icons.badge_outlined,
                                    size: 20, color: AppColors.textMuted),
                                isDense: true,
                              ),
                            );
                          },
                          onSelected: (v) => _roleController.text = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (v) => _clientSuggestions
                              .where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
                          fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                            if (ctrl.text.isEmpty && _clientController.text.isNotEmpty) {
                              ctrl.text = _clientController.text;
                            }
                            _clientController.addListener(() {
                              if (ctrl.text != _clientController.text) ctrl.text = _clientController.text;
                            });
                            ctrl.addListener(() => _clientController.text = ctrl.text);
                            return TextFormField(
                              controller: ctrl,
                              focusNode: fn,
                              decoration: InputDecoration(
                                labelText: 'Client',
                                hintText: 'e.g. Marriott',
                                filled: true,
                                fillColor: AppColors.formFillLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.personalEvent, width: 1.5),
                                ),
                                prefixIcon: const Icon(Icons.business_outlined,
                                    size: 20, color: AppColors.textMuted),
                                isDense: true,
                              ),
                            );
                          },
                          onSelected: (v) => _clientController.text = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location (Places autocomplete) + Hourly rate row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _locationController,
                          onChanged: _onLocationChanged,
                          decoration: InputDecoration(
                            labelText: l10n.personalEventLocation,
                            hintText: l10n.personalEventLocationHint,
                            filled: true,
                            fillColor: AppColors.formFillLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.personalEvent, width: 1.5),
                            ),
                            prefixIcon: const Icon(Icons.location_on_outlined,
                                size: 20, color: AppColors.textMuted),
                            suffixIcon: _loadingPlaces
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.personalEvent,
                                      ),
                                    ),
                                  )
                                : null,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '\$/hr',
                            hintText: '25',
                            filled: true,
                            fillColor: AppColors.formFillLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.personalEvent, width: 1.5),
                            ),
                            prefixIcon: const Icon(Icons.attach_money_rounded,
                                size: 20, color: AppColors.textMuted),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Place predictions dropdown
                  if (_placePredictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: _placePredictions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final p = _placePredictions[i];
                          return InkWell(
                            onTap: () => _selectPlace(p),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.place_rounded,
                                      size: 18,
                                      color: AppColors.personalEvent
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.mainText,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        if (p.secondaryText.isNotEmpty)
                                          Text(
                                            p.secondaryText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes (optional)
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.personalEventNotes,
                      hintText: l10n.personalEventNotesHint,
                      filled: true,
                      fillColor: AppColors.formFillLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.personalEvent, width: 1.5),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.personalEvent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? l10n.save : l10n.addPersonalEvent,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
