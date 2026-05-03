// lib/services/export_service.dart
//
// ERREURS CORRIGÉES :
//   1. ambiguous_import SensorReading
//      → database_helper.dart contenait SensorReading en double.
//        Solution : supprimer les classes de database_helper.dart.
//
//   2. invalid_constant + undefined_getter 'white70' / 'white54'
//      → PdfColors.white70 et PdfColors.white54 n'existent pas dans le package pdf.
//        Solution : utiliser PdfColor avec opacité manuelle :
//          PdfColor(1, 1, 1, 0.7)  au lieu de PdfColors.white70
//          PdfColor(1, 1, 1, 0.54) au lieu de PdfColors.white54
//
//   3. unchecked_use_of_nullable_value (waterLeak, temperature, etc.)
//      → readings.take(50).map() retournait SensorReading? dans certains contextes.
//        Solution : ajouter le type explicite .map<SensorReading>() et
//        utiliser des variables locales non-nullables.

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
      case ExportRange.lastHour: return DateTime.now().subtract(const Duration(hours: 1));
      case ExportRange.today:
        return DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      case ExportRange.lastWeek: return DateTime.now().subtract(const Duration(days: 7));
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

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL EXPORT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<File> exportToExcel(ExportRequest req) async {
    final db       = DatabaseHelper.instance;
    final readings = req.includeReadings
        ? await db.getReadingsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <SensorReading>[];
    final alerts   = req.includeAlerts
        ? await db.getAlertsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <AlertModel>[];

    final excel = Excel.createExcel();

    // ── Sheet 1 : Sensor Readings ──────────────────────────────────────────
    if (req.includeReadings) {
      final sheet = excel['Sensor Readings'];
      excel.setDefaultSheet('Sensor Readings');

      final headers = ['#', 'Date & Time', 'ESP ID', 'Temperature (°C)',
          'Humidity (%)', 'Water Level (ADC)', 'Water Level (%)', 'Water Leak'];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(
          bold:               true,
          backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
          fontColorHex:       ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign:    HorizontalAlign.Center,
        );
      }

      for (int i = 0; i < readings.length; i++) {
        final r   = readings[i]; // SensorReading non-nullable
        final row = i + 1;
        final dt  = _fmtExcelDate(r.recordedAt);

        final rowData = [
          IntCellValue(i + 1),
          TextCellValue(dt),
          TextCellValue(r.espId),
          DoubleCellValue(r.temperature),
          DoubleCellValue(r.humidity),
          IntCellValue(r.waterLevel),
          DoubleCellValue(r.waterPercent),
          TextCellValue(r.waterLeak ? 'YES' : 'NO'),
        ];

        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = rowData[c];
          if (row % 2 == 0) {
            cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#F0F4FF'));
          }
          if (c == 7 && r.waterLeak) {
            cell.cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#CC0000'), bold: true);
          }
          if (c == 3 && r.temperature > 35) {
            cell.cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#CC0000'), bold: true);
          }
        }
      }

      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 22);
      sheet.setColumnWidth(2, 14);
      sheet.setColumnWidth(3, 18);
      sheet.setColumnWidth(4, 15);
      sheet.setColumnWidth(5, 20);
      sheet.setColumnWidth(6, 18);
      sheet.setColumnWidth(7, 13);
    }

    // ── Sheet 2 : Alerts ───────────────────────────────────────────────────
    if (req.includeAlerts && alerts.isNotEmpty) {
      final sheet   = excel['Alerts'];
      final headers = ['#', 'Date & Time', 'ESP ID', 'Severity',
          'Title', 'Location', 'Status'];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(
          bold:               true,
          backgroundColorHex: ExcelColor.fromHexString('#5C1A1A'),
          fontColorHex:       ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign:    HorizontalAlign.Center,
        );
      }
      for (int i = 0; i < alerts.length; i++) {
        final a   = alerts[i];
        final row = i + 1;
        final rowData = [
          IntCellValue(i + 1),
          TextCellValue(_fmtDateShort(a.timestamp)),
          TextCellValue(a.deviceId),
          TextCellValue(a.severity.name.toUpperCase()),
          TextCellValue(a.title),
          TextCellValue(a.location),
          TextCellValue(a.isResolved ? 'Resolved' : 'Active'),
        ];
        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = rowData[c];
          if (a.severity == AlertSeverity.critical && !a.isResolved) {
            cell.cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#CC0000'));
          }
        }
      }
      sheet.setColumnWidth(1, 20);
      sheet.setColumnWidth(4, 40);
    }

    // ── Sheet 3 : Summary ─────────────────────────────────────────────────
    {
      final sheet = excel['Summary'];
      final stats = await DatabaseHelper.instance.getStats(
        espId:     req.espId,
        hoursBack: req.range == ExportRange.lastHour ? 1
            : req.range == ExportRange.today    ? 24
            : req.range == ExportRange.lastWeek ? 168 : 24,
      );

      void addRow(String label, String value, {bool bold = false}) {
        final rowIdx = sheet.maxRows;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
            .value = TextCellValue(label);
        final valCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx));
        valCell.value = TextCellValue(value);
        if (bold) valCell.cellStyle = CellStyle(bold: true);
      }

      addRow('Report',    'DataGuardian IoT Export', bold: true);
      addRow('ESP Device', req.espName);
      addRow('ESP ID',     req.espId);
      addRow('Period',     req.rangeLabel);
      addRow('Generated',  DateTime.now().toString());
      addRow('', '');
      addRow('--- SENSOR STATS ---', '', bold: true);
      addRow('Total Readings',    '${stats.totalReadings}');
      addRow('Temp Min',          '${stats.tempMin.toStringAsFixed(1)}°C');
      addRow('Temp Max',          '${stats.tempMax.toStringAsFixed(1)}°C');
      addRow('Temp Avg',          '${stats.tempAvg.toStringAsFixed(1)}°C');
      addRow('Humidity Min',      '${stats.humMin.toStringAsFixed(0)}%');
      addRow('Humidity Max',      '${stats.humMax.toStringAsFixed(0)}%');
      addRow('Humidity Avg',      '${stats.humAvg.toStringAsFixed(0)}%');
      addRow('Water Leak Events', stats.hadLeak ? 'YES — detected' : 'None');
      addRow('Total Alerts',      '${alerts.length}');
      sheet.setColumnWidth(0, 22);
      sheet.setColumnWidth(1, 30);
    }

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
    final db       = DatabaseHelper.instance;
    final readings = req.includeReadings
        ? await db.getReadingsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <SensorReading>[];
    final alerts   = req.includeAlerts
        ? await db.getAlertsForExport(
            espId: req.espId, from: req.fromDate, to: req.toDate)
        : <AlertModel>[];
    final stats = await db.getStats(
      espId:     req.espId,
      hoursBack: req.range == ExportRange.lastHour ? 1
          : req.range == ExportRange.today    ? 24 : 168,
    );

    final pdf = pw.Document();

    // ── Couleurs ──────────────────────────────────────────────────────────
    const headerBlue  = PdfColor(0.12, 0.23, 0.37);       // #1E3A5F
    const accentBlue  = PdfColor(0.24, 0.51, 0.96);       // #3C83F6
    const alertRed    = PdfColor(0.94, 0.27, 0.27);       // #EF4444
    const alertOrange = PdfColor(0.98, 0.60, 0.09);       // #F97316
    const bgGray      = PdfColor(0.97, 0.98, 0.99);       // #F8FAFC
    const textDark    = PdfColor(0.12, 0.16, 0.24);       // #1E293B
    const textMuted   = PdfColor(0.39, 0.45, 0.55);       // #64748B

    // CORRECTION : PdfColor(r,g,b,alpha) au lieu de PdfColors.white70/white54
    // qui n'existent pas dans le package pdf.
    const white       = PdfColors.white;
    const white70     = PdfColor(1, 1, 1, 0.7);  // remplace PdfColors.white70
    const white54     = PdfColor(1, 1, 1, 0.54); // remplace PdfColors.white54

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
                pw.Text('Sensor Data Report',
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

        // Stats cards
        pw.Text('Summary Statistics',
            style: pw.TextStyle(fontSize: 14,
                fontWeight: pw.FontWeight.bold, color: textDark)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _pdfStatCard(
              'Temperature',
              '${stats.tempAvg.toStringAsFixed(1)}°C avg',
              'Min ${stats.tempMin.toStringAsFixed(1)}° / Max ${stats.tempMax.toStringAsFixed(1)}°',
              accentBlue),
          pw.SizedBox(width: 12),
          _pdfStatCard(
              'Humidity',
              '${stats.humAvg.toStringAsFixed(0)}% avg',
              'Min ${stats.humMin.toStringAsFixed(0)}% / Max ${stats.humMax.toStringAsFixed(0)}%',
              const PdfColor(0.22, 0.74, 0.97)),
          pw.SizedBox(width: 12),
          _pdfStatCard(
              'Water Leaks',
              stats.hadLeak ? 'DETECTED' : 'None',
              // CORRECTION : lecture directe de la liste typée — pas de nullable
              '${readings.where((r) => r.waterLeak).length} event(s)',
              stats.hadLeak ? alertRed : const PdfColor(0.06, 0.71, 0.51)),
          pw.SizedBox(width: 12),
          _pdfStatCard('Total Readings', '${stats.totalReadings}',
              'Period: ${req.rangeLabel}', textMuted),
        ]),
        pw.SizedBox(height: 24),

        // Alerts table
        if (alerts.isNotEmpty) ...[
          pw.Text('Alert Summary',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(120),
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
              ...alerts.take(20).map((a) {
                final sevColor = a.severity == AlertSeverity.critical
                    ? alertRed
                    : a.severity == AlertSeverity.warning
                        ? alertOrange : accentBlue;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: alerts.indexOf(a) % 2 == 0
                          ? bgGray : PdfColors.white),
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
                            style: pw.TextStyle(fontSize: 8,
                                color: a.isResolved
                                    ? PdfColors.green700 : alertRed))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Readings table
        if (readings.isNotEmpty) ...[
          pw.Text('Sensor Readings',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 6),
          pw.Text(
              'Showing ${readings.length > 50 ? 50 : readings.length} '
              'of ${readings.length} records',
              style: const pw.TextStyle(fontSize: 9, color: textMuted)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(110),
              1: const pw.FixedColumnWidth(75),
              2: const pw.FixedColumnWidth(65),
              3: const pw.FixedColumnWidth(85),
              4: const pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBlue),
                children: ['Date & Time', 'Temp (°C)', 'Humidity (%)',
                    'Water Level', 'Leak']
                    .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h, style: pw.TextStyle(
                          color: white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9))))
                    .toList(),
              ),
              // CORRECTION : variable locale r = SensorReading (non-nullable)
              ...readings.take(50).map((r) {
                final isAnomaly = r.temperature > 35 || r.waterLeak;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isAnomaly
                        ? const PdfColor(1, 0.94, 0.94)
                        : readings.indexOf(r) % 2 == 0
                            ? bgGray : PdfColors.white,
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_fmtDate(r.recordedAt),
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(r.temperature.toStringAsFixed(1),
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: r.temperature > 35
                                    ? alertRed : textDark,
                                fontWeight: r.temperature > 35
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(r.humidity.toStringAsFixed(0),
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                            '${r.waterPercent.toStringAsFixed(0)}%'
                            ' (${r.waterLevel})',
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(r.waterLeak ? 'YES' : 'NO',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: r.waterLeak
                                    ? alertRed : PdfColors.green700,
                                fontWeight: pw.FontWeight.bold))),
                  ],
                );
              }),
            ],
          ),
          if (readings.length > 50)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                  '... and ${readings.length - 50} more records '
                  '(export Excel for full data)',
                  style: const pw.TextStyle(fontSize: 9, color: textMuted)),
            ),
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
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text:    'DataGuardian IoT Export — $subject',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Format long avec secondes — pour Excel
  String _fmtExcelDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  /// Format court sans secondes — pour PDF et alertes Excel
  String _fmtDateShort(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) => _fmtDateShort(dt);

  pw.Widget _pdfStatCard(
      String label, String value, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border:       pw.Border.all(color: color, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(sub,
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
        ]),
      ),
    );
  }
}
