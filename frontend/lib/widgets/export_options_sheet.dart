import 'package:flutter/material.dart';
import '../shared/presentation/theme/theme.dart';

/// Bottom sheet for selecting export options
class StaffExportOptionsSheet extends StatefulWidget {
  final String? selectedYear;

  const StaffExportOptionsSheet({
    super.key,
    this.selectedYear,
  });

  @override
  State<StaffExportOptionsSheet> createState() => _StaffExportOptionsSheetState();
}

class _StaffExportOptionsSheetState extends State<StaffExportOptionsSheet> {
  String _selectedPeriod = 'month';
  String _selectedFormat = 'csv';
  DateTimeRange? _customRange;

  static const _formats = [
    _FormatOption(
      key: 'csv',
      label: 'CSV',
      icon: Icons.table_chart_outlined,
      description: 'Spreadsheet-compatible',
    ),
    _FormatOption(
      key: 'pdf',
      label: 'PDF',
      icon: Icons.picture_as_pdf_outlined,
      description: 'Formatted report',
    ),
    _FormatOption(
      key: 'xlsx',
      label: 'Excel',
      icon: Icons.grid_on_outlined,
      description: 'With charts & styling',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navySpaceCadet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: AppColors.navySpaceCadet,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Shifts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Download your shift history',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Format selection
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Format',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _formats.map((fmt) {
                      final isSelected = _selectedFormat == fmt.key;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFormat = fmt.key),
                          child: Container(
                            margin: EdgeInsets.only(
                              right: fmt.key != 'xlsx' ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.navySpaceCadet
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.navySpaceCadet
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  fmt.icon,
                                  size: 22,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.navySpaceCadet,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fmt.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.navySpaceCadet,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fmt.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Period selection
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PeriodChip(
                        label: 'This Week',
                        isSelected: _selectedPeriod == 'week',
                        onTap: () => setState(() {
                          _selectedPeriod = 'week';
                          _customRange = null;
                        }),
                      ),
                      _PeriodChip(
                        label: 'This Month',
                        isSelected: _selectedPeriod == 'month',
                        onTap: () => setState(() {
                          _selectedPeriod = 'month';
                          _customRange = null;
                        }),
                      ),
                      _PeriodChip(
                        label: 'This Year',
                        isSelected: _selectedPeriod == 'year',
                        onTap: () => setState(() {
                          _selectedPeriod = 'year';
                          _customRange = null;
                        }),
                      ),
                      _PeriodChip(
                        label: 'All Time',
                        isSelected: _selectedPeriod == 'all',
                        onTap: () => setState(() {
                          _selectedPeriod = 'all';
                          _customRange = null;
                        }),
                      ),
                      _PeriodChip(
                        label: _customRange != null
                            ? '${_customRange!.start.month}/${_customRange!.start.day} - ${_customRange!.end.month}/${_customRange!.end.day}'
                            : 'Custom',
                        icon: Icons.date_range,
                        isSelected: _selectedPeriod == 'custom',
                        onTap: () => _showDatePicker(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Export info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Export includes: date, event, venue, role, hours, and earnings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Export button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      StaffExportOptions(
                        format: _selectedFormat,
                        period: _selectedPeriod,
                        startDate: _customRange?.start,
                        endDate: _customRange?.end,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navySpaceCadet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _formats.firstWhere((f) => f.key == _selectedFormat).icon,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Export ${_formats.firstWhere((f) => f.key == _selectedFormat).label}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navySpaceCadet,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customRange = result;
      });
    }
  }
}

class _FormatOption {
  final String key;
  final String label;
  final IconData icon;
  final String description;

  const _FormatOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.description,
  });
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navySpaceCadet : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.navySpaceCadet : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Export options returned from the bottom sheet
class StaffExportOptions {
  final String format;
  final String period;
  final DateTime? startDate;
  final DateTime? endDate;

  StaffExportOptions({
    required this.format,
    required this.period,
    this.startDate,
    this.endDate,
  });
}
