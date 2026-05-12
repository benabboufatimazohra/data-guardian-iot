// lib/services/export_service.dart
//
// COMPATIBLE WITH: excel ^2.1.0  (NOT excel ^4.x)
//
// ERRORS FIXED:
//   - TextCellValue / IntCellValue / DoubleCellValue → use .value = directly
//   - ExcelColor → use ExcelColor.fromHexString or just omit for v2
//   - setColumnWidth → not available in v2, removed
//   - CellStyle API differences between v2 and v4

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

enum ExportRange { lastHour, today, lastWeek, custom }

class ExportRequest {
  final String      espId;
  final String      espName;
  final ExportRange range;
  final DateTime?   customFrom;
  final DateTime?   customTo;
  final bool        includeReadings;
  final bool        includeAlerts;

  const ExportRequest({
    required this.espId,
    required this.espName,
    required this.range,
    this.customFrom,
    this.customTo,
    this.includeReadings = true,
    this.includeAlerts   = true,
  });

  DateTime get fromDate {
    switch (range) {
      case ExportRange.lastHour:
        return DateTime.now().subtract(const Duration(hours: 1));
      case ExportRange.today:
        return DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      case ExportRange.lastWeek:
        return DateTime.now().subtract(const Duration(days: 7));
      case ExportRange.custom:
        return customFrom ?? DateTime.now().subtract(const Duration(days: 1));
    }
  }

  DateTime get toDate => customTo ?? DateTime.now();

  String get rangeLabel {
    switch (range) {
      case ExportRange.lastHour: return 'Last Hour';
      case ExportRange.today:    return 'Today';
      case ExportRange.lastWeek: return 'Last 7 Days';
      case ExportRange.custom:
        final f = fromDate;
        final t = toDate;
        return '${f.day}/${f.month}/${f.year} – ${t.day}/${t.month}/${t.year}';
    }
  }
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  CellValue _wrapCellValue(Object? value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    return TextCellValue(value.toString());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL EXPORT — compatible with excel v2.1.0
  // ═══════════════════════════════════════════════════════════════════════════
  Future<File> exportToExcel(ExportRequest req) async {
    final db = DatabaseHelper.instance;

    // Since we no longer store all sensor readings (only critical alerts),
    // the readings list will be empty — we export alerts only.
    final alerts = req.includeAlerts
        ? await db.getAlertsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <AlertModel>[];

    final excel = Excel.createExcel();

    // ── Sheet 1: Critical Alerts ──────────────────────────────────────────
    final alertSheet = excel['Critical Alerts'];
    excel.setDefaultSheet('Critical Alerts');

    // Headers — in excel v2, we set cell.value directly as a String/int/double
    final alertHeaders = [
      '#', 'Date & Time', 'ESP ID', 'Severity', 'Title', 'Location', 'Status'
    ];
    for (int c = 0; c < alertHeaders.length; c++) {
      final cell = alertSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = _wrapCellValue(alertHeaders[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (int i = 0; i < alerts.length; i++) {
      final a   = alerts[i];
      final row = i + 1;

      final rowData = [
        i + 1,
        _fmtDate(a.timestamp),
        a.deviceId,
        a.severity.name.toUpperCase(),
        a.title,
        a.location,
        a.isResolved ? 'Resolved' : 'Active',
      ];

      for (int c = 0; c < rowData.length; c++) {
        final cell = alertSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = _wrapCellValue(rowData[c]);
        if (a.severity == AlertSeverity.critical && !a.isResolved) {
          cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#CC0000'));
        }
        if (row % 2 == 0) {
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F0F4FF'));
        }
      }
    }

    // ── Sheet 2: Summary ───────────────────────────────────────────────────
    final summarySheet = excel['Summary'];

    void addRow(String label, String value) {
      final rowIdx = summarySheet.maxRows;
      summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx),
      ).value = _wrapCellValue(label);
      summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx),
      ).value = _wrapCellValue(value);
    }

    addRow('Report',       'DataGuardian IoT Export');
    addRow('ESP Device',   req.espName);
    addRow('ESP ID',       req.espId);
    addRow('Period',       req.rangeLabel);
    addRow('Generated',    DateTime.now().toString());
    addRow('',             '');
    addRow('Total Critical Alerts', '${alerts.length}');
    addRow('Unresolved',   '${alerts.where((a) => !a.isResolved).length}');
    addRow('Resolved',     '${alerts.where((a) => a.isResolved).length}');

    final dir      = await getApplicationDocumentsDirectory();
    final filename =
        'dataguardian_${req.espId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file  = File('${dir.path}/$filename');
    final bytes = excel.encode();
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<File> exportToPdf(ExportRequest req) async {
    final db = DatabaseHelper.instance;
    final alerts = req.includeAlerts
        ? await db.getAlertsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <AlertModel>[];

    final pdf = pw.Document();

    const headerBlue  = PdfColor(0.12, 0.23, 0.37);
    const accentBlue  = PdfColor(0.24, 0.51, 0.96);
    const alertRed    = PdfColor(0.94, 0.27, 0.27);
    const alertOrange = PdfColor(0.98, 0.60, 0.09);
    const bgGray      = PdfColor(0.97, 0.98, 0.99);
    const textDark    = PdfColor(0.12, 0.16, 0.24);
    const textMuted   = PdfColor(0.39, 0.45, 0.55);
    const white       = PdfColors.white;
    const white70     = PdfColor(1, 1, 1, 0.7);
    const white54     = PdfColor(1, 1, 1, 0.54);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [

        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: const pw.BoxDecoration(color: headerBlue),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('DataGuardian IoT',
                    style: pw.TextStyle(fontSize: 22,
                        fontWeight: pw.FontWeight.bold, color: white)),
                pw.SizedBox(height: 4),
                pw.Text('Critical Alerts Report',
                    style: const pw.TextStyle(fontSize: 12, color: white70)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(req.espName,
                    style: pw.TextStyle(fontSize: 14,
                        fontWeight: pw.FontWeight.bold, color: white)),
                pw.Text(req.rangeLabel,
                    style: const pw.TextStyle(fontSize: 11, color: white70)),
                pw.Text('Generated: ${_fmtDate(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: white54)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Summary cards
        pw.Text('Summary',
            style: pw.TextStyle(fontSize: 14,
                fontWeight: pw.FontWeight.bold, color: textDark)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _pdfStatCard('Total Alerts', '${alerts.length}',
              'Period: ${req.rangeLabel}', accentBlue),
          pw.SizedBox(width: 12),
          _pdfStatCard('Unresolved',
              '${alerts.where((a) => !a.isResolved).length}',
              'Needs attention', alertRed),
          pw.SizedBox(width: 12),
          _pdfStatCard('Resolved',
              '${alerts.where((a) => a.isResolved).length}',
              'Handled', const PdfColor(0.06, 0.71, 0.51)),
        ]),
        pw.SizedBox(height: 24),

        // Alerts table
        if (alerts.isNotEmpty) ...[
          pw.Text('Critical Alert Log',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(110),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBlue),
                children: ['Date & Time', 'Alert Title', 'Severity', 'Status']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h, style: pw.TextStyle(
                              color: white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9))))
                    .toList(),
              ),
              ...alerts.map((a) {
                final idx = alerts.indexOf(a);
                final sevColor = a.severity == AlertSeverity.critical
                    ? alertRed
                    : a.severity == AlertSeverity.warning
                        ? alertOrange
                        : accentBlue;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: idx % 2 == 0 ? bgGray : PdfColors.white),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_fmtDate(a.timestamp),
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(a.title,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(a.severity.name.toUpperCase(),
                            style: pw.TextStyle(fontSize: 8,
                                color: sevColor,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                            a.isResolved ? 'Resolved' : 'Active',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: a.isResolved
                                    ? PdfColors.green700
                                    : alertRed))),
                  ],
                );
              }),
            ],
          ),
        ] else ...[
          pw.Text('No alerts found for this period.',
              style: const pw.TextStyle(fontSize: 13, color: textMuted)),
        ],

        // Footer
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey300),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('DataGuardian IoT — Confidential',
              style: const pw.TextStyle(fontSize: 8, color: textMuted)),
          pw.Text('ESP: ${req.espId} | ${req.rangeLabel}',
              style: const pw.TextStyle(fontSize: 8, color: textMuted)),
        ]),
      ],
    ));

    final dir      = await getApplicationDocumentsDirectory();
    final filename =
        'dataguardian_${req.espId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> shareFile(File file, String subject) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        text: 'DataGuardian IoT Export — $subject',
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  pw.Widget _pdfStatCard(
      String label, String value, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(sub,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ]),
      ),
    );
  }
}

