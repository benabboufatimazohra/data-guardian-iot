// lib/screens/export_screen.dart
//
// ERREURS CORRIGÉES :
//   1. EspDevice non reconnu
//      → Manquait l'import de '../models/models.dart'
//        qui réexporte EspDevice depuis esp_device.dart.
//
//   2. ExportRange non reconnu
//      → Manquait l'import de '../services/export_service.dart'
//        qui définit ExportRange et ExportRequest.
//
//   3. withOpacity() déprécié partout
//      → Remplacé par .withValues(alpha: ...) dans tout le fichier.
//
//   4. curly_braces_in_flow_control_structures (export_screen.dart:72-73)
//      → Les if sans accolades ont été corrigés avec {}.
//
//   5. activeColor déprécié sur Switch
//      → Remplacé par thumbColor et trackColor avec MaterialStateProperty.

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart'; // ← AJOUTÉ : fournit EspDevice

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  EspDevice?  _selectedEsp;
  ExportRange _range        = ExportRange.today;
  bool        _exportExcel  = true;
  bool        _exportPdf    = true;
  bool        _inclReadings = true;
  bool        _inclAlerts   = true;

  DateTime? _customFrom;
  DateTime? _customTo;

  List<EspDevice> _espList      = [];
  bool            _isLoading    = false;
  bool            _isExporting  = false;
  String?         _statusMsg;
  bool            _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadEsps();
  }

  Future<void> _loadEsps() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    final esps = user != null
        ? await DatabaseHelper.instance.getEspsForUser(user)
        : await DatabaseHelper.instance.getAllEsps();
    setState(() {
      _espList     = esps;
      _selectedEsp = esps.isNotEmpty ? esps.first : null;
      _isLoading   = false;
    });
  }

  Future<void> _pickCustomDate(bool isFrom) async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now(),
      firstDate:   DateTime.now().subtract(const Duration(days: 365)),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom = picked; // ← CORRECTION : accolades ajoutées
      } else {
        _customTo = picked;   // ← CORRECTION : accolades ajoutées
      }
    });
  }

  Future<void> _doExport() async {
    if (_selectedEsp == null) {
      _showStatus('Please select an ESP device', isError: true);
      return;
    }
    if (!_exportExcel && !_exportPdf) {
      _showStatus('Select at least one format (Excel or PDF)', isError: true);
      return;
    }
    if (_range == ExportRange.custom &&
        (_customFrom == null || _customTo == null)) {
      _showStatus('Please pick both start and end dates', isError: true);
      return;
    }

    setState(() { _isExporting = true; _statusMsg = null; });

    final req = ExportRequest(
      espId:           _selectedEsp!.id,
      espName:         _selectedEsp!.name,
      range:           _range,
      customFrom:      _customFrom,
      customTo:        _customTo,
      includeReadings: _inclReadings,
      includeAlerts:   _inclAlerts,
    );

    try {
      final files = <File>[];
      final svc   = ExportService.instance;

      if (_exportExcel) {
        _showStatus('Generating Excel…');
        files.add(await svc.exportToExcel(req));
      }
      if (_exportPdf) {
        _showStatus('Generating PDF…');
        files.add(await svc.exportToPdf(req));
      }

      for (final f in files) {
        await svc.shareFile(f, '${_selectedEsp!.name} — ${req.rangeLabel}');
      }

      _showStatus('Export successful! ${files.length} file(s) ready.');
    } catch (e) {
      _showStatus('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showStatus(String msg, {bool isError = false}) =>
      setState(() { _statusMsg = msg; _statusIsError = isError; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Export Data',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 1. Sélection ESP ────────────────────────────────────
                  const _SectionTitle(
                      title: '1. Select Device', icon: Icons.router),
                  const SizedBox(height: 10),
                  if (_espList.isEmpty)
                    const _InfoBox('No ESP devices found in database.',
                        isError: true)
                  else
                    ..._espList.map((esp) => _EspTile(
                      esp:        esp,
                      isSelected: _selectedEsp?.id == esp.id,
                      onTap:      () => setState(() => _selectedEsp = esp),
                    )),

                  const SizedBox(height: 24),

                  // ── 2. Période ──────────────────────────────────────────
                  const _SectionTitle(
                      title: '2. Time Period',
                      icon: Icons.calendar_today_outlined),
                  const SizedBox(height: 10),
                  _RangeSelector(
                    selected:  _range,
                    onChanged: (r) => setState(() => _range = r),
                  ),

                  if (_range == ExportRange.custom) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _DatePickerButton(
                        label: 'From',
                        date:  _customFrom,
                        onTap: () => _pickCustomDate(true),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _DatePickerButton(
                        label: 'To',
                        date:  _customTo,
                        onTap: () => _pickCustomDate(false),
                      )),
                    ]),
                  ],

                  const SizedBox(height: 24),

                  // ── 3. Contenu ──────────────────────────────────────────
                  const _SectionTitle(
                      title: '3. Data to Include',
                      icon: Icons.storage_outlined),
                  const SizedBox(height: 10),
                  _ToggleRow(
                    label:     'Sensor Readings',
                    subtitle:  'Temperature, humidity, water level',
                    icon:      Icons.thermostat,
                    value:     _inclReadings,
                    onChanged: (v) => setState(() => _inclReadings = v),
                  ),
                  const SizedBox(height: 8),
                  _ToggleRow(
                    label:     'Alerts History',
                    subtitle:  'All triggered alerts',
                    icon:      Icons.notifications_outlined,
                    value:     _inclAlerts,
                    onChanged: (v) => setState(() => _inclAlerts = v),
                  ),

                  const SizedBox(height: 24),

                  // ── 4. Format ────────────────────────────────────────────
                  const _SectionTitle(
                      title: '4. Export Format',
                      icon: Icons.file_download_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _FormatCard(
                      label:      'Excel',
                      subtitle:   '.xlsx — Full data\nwith formatting',
                      icon:       Icons.table_chart_outlined,
                      color:      const Color(0xFF217346),
                      isSelected: _exportExcel,
                      onTap:      () => setState(
                          () => _exportExcel = !_exportExcel),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _FormatCard(
                      label:      'PDF',
                      subtitle:   '.pdf — Printable\nreport with stats',
                      icon:       Icons.picture_as_pdf_outlined,
                      color:      const Color(0xFFB91C1C),
                      isSelected: _exportPdf,
                      onTap:      () => setState(
                          () => _exportPdf = !_exportPdf),
                    )),
                  ]),

                  const SizedBox(height: 28),

                  // ── Status ───────────────────────────────────────────────
                  if (_statusMsg != null)
                    _InfoBox(_statusMsg!, isError: _statusIsError),
                  const SizedBox(height: 12),

                  // ── Bouton Export ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _doExport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:         AppColors.primary,
                        foregroundColor:         Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download_outlined),
                      label: Text(
                        _isExporting
                            ? 'Generating…'
                            : 'Generate & Share Export',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String   title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 18),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);
}

class _EspTile extends StatelessWidget {
  final EspDevice    esp;
  final bool         isSelected;
  final VoidCallback onTap;
  const _EspTile(
      {required this.esp, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // CORRECTION withOpacity → withValues
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color: esp.isOnline ? AppColors.emerald : AppColors.red,
              shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(esp.name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primary : AppColors.textPrimary)),
            Text('${esp.id} · ${esp.room}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ])),
        if (isSelected)
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
      ]),
    ),
  );
}

class _RangeSelector extends StatelessWidget {
  final ExportRange selected;
  final ValueChanged<ExportRange> onChanged;
  const _RangeSelector(
      {required this.selected, required this.onChanged});

  static const _options = [
    (ExportRange.lastHour, 'Last Hour',   Icons.schedule),
    (ExportRange.today,    'Today',       Icons.today),
    (ExportRange.lastWeek, 'Last 7 Days', Icons.date_range),
    (ExportRange.custom,   'Custom',      Icons.calendar_month),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: _options.map((opt) {
      final (range, label, icon) = opt;
      final isSel = selected == range;
      return GestureDetector(
        onTap: () => onChanged(range),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // CORRECTION withOpacity → withValues
            color: isSel
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSel ? AppColors.primary : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14,
                color: isSel ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isSel ? AppColors.primary : AppColors.textSecondary)),
          ]),
        ),
      );
    }).toList(),
  );
}

class _DatePickerButton extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePickerButton(
      {required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.calendar_today,
            color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          date != null
              ? '${date!.day}/${date!.month}/${date!.year}'
              : 'Pick $label',
          style: TextStyle(
              fontSize: 13,
              color: date != null
                  ? AppColors.textPrimary : AppColors.textMuted),
        ),
      ]),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String   label, subtitle;
  final IconData icon;
  final bool     value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.subtitle,
      required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // CORRECTION withOpacity → withValues
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(subtitle, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
        ])),
      // CORRECTION activeColor déprécié → thumbColor + trackColor
      Switch(
        value:    value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textMuted),
      ),
    ]),
  );
}

class _FormatCard extends StatelessWidget {
  final String   label, subtitle;
  final IconData icon;
  final Color    color;
  final bool     isSelected;
  final VoidCallback onTap;
  const _FormatCard({required this.label, required this.subtitle,
      required this.icon, required this.color,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // CORRECTION withOpacity → withValues
        color: isSelected
            ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isSelected ? color : AppColors.border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon,
              color: isSelected ? color : AppColors.textMuted, size: 28),
          if (isSelected)
            Icon(Icons.check_circle, color: color, size: 18),
        ]),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: isSelected ? color : AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ),
  );
}

class _InfoBox extends StatelessWidget {
  final String message;
  final bool   isError;
  const _InfoBox(this.message, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.red : AppColors.emerald;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // CORRECTION withOpacity → withValues
        color:  color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(fontSize: 12, color: color))),
      ]),
    );
  }
}
