// Data Import/Export Utility
// Supports CSV and Excel formats for bulk data operations

import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

enum ExportFormat { csv, excel }

enum ImportFormat { csv, excel }

class DataImportExport {
  // ── Export to File ──────────────────────────────────────────────────────────

  /// Export data to CSV or Excel file
  static Future<Uint8List?> exportToBytes(
    List<List<dynamic>> data, {
    ExportFormat format = ExportFormat.csv,
    String sheetName = 'Data',
  }) async {
    try {
      if (format == ExportFormat.csv) {
        return _exportToCsv(data);
      } else {
        return _exportToExcel(data, sheetName);
      }
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }

  static Uint8List _exportToCsv(List<List<dynamic>> data) {
    final csvData = const ListToCsvConverter().convert(data);
    return Uint8List.fromList(csvData.codeUnits);
  }

  static Uint8List _exportToExcel(List<List<dynamic>> data, String sheetName) {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];

    // Add data
    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      for (var j = 0; j < row.length; j++) {
        final cell = CellValue.fromRawValue(row[j]?.toString() ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i)).value = cell;
      }
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ── Import from File ────────────────────────────────────────────────────────

  /// Pick and import CSV or Excel file
  static Future<List<List<dynamic>>?> importFromFile({
    ImportFormat? format,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) return null;

      final extension = file.extension?.toLowerCase();

      if (extension == 'csv') {
        return _importFromCsv(bytes);
      } else if (extension == 'xlsx' || extension == 'xls') {
        return _importFromExcel(bytes);
      }

      return null;
    } catch (e) {
      debugPrint('Import error: $e');
      return null;
    }
  }

  static List<List<dynamic>> _importFromCsv(Uint8List bytes) {
    final csvString = String.fromCharCodes(bytes);
    return const CsvToListConverter().convert(csvString);
  }

  static List<List<dynamic>> _importFromExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final data = <List<dynamic>>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet != null) {
        for (final row in sheet.rows) {
          data.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
        }
      }
    }

    return data;
  }

  // ── Preview Data ────────────────────────────────────────────────────────────

  /// Show preview dialog for imported data
  static Future<bool?> showPreviewDialog(
    BuildContext context,
    List<List<dynamic>> data, {
    String title = 'Import Preview',
    int maxRowsToShow = 10,
  }) async {
    if (data.isEmpty) return null;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                columns: data.first
                    .asMap()
                    .entries
                    .map((e) => DataColumn(
                          label: Text(
                            e.value.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ))
                    .toList(),
                rows: data
                    .skip(1)
                    .take(maxRowsToShow)
                    .map((row) => DataRow(
                          cells: row
                              .map((cell) => DataCell(Text(
                                    cell.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  )))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Import ${data.length - 1} Rows'),
          ),
        ],
      ),
    );
  }
}

// ── Quick Import/Export Menu Button ───────────────────────────────────────────

class ImportExportMenu extends StatelessWidget {
  const ImportExportMenu({
    super.key,
    required this.onImport,
    required this.onExport,
  });

  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.upload_file),
      tooltip: 'Import/Export',
      onSelected: (value) {
        switch (value) {
          case 'import':
            onImport();
            break;
          case 'export':
            onExport();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload, size: 20),
              SizedBox(width: 8),
              Text('Import Data'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download, size: 20),
              SizedBox(width: 8),
              Text('Export Data'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Format Selection Dialog ───────────────────────────────────────────────────

class FormatSelectionDialog extends StatelessWidget {
  const FormatSelectionDialog({
    super.key,
    required this.title,
    this.showImport = true,
    this.showExport = true,
  });

  final String title;
  final bool showImport;
  final bool showExport;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showImport) ...[
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Import from CSV'),
              subtitle: const Text('.csv file format'),
              onTap: () => Navigator.pop(context, 'import_csv'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Import from Excel'),
              subtitle: const Text('.xlsx or .xls file'),
              onTap: () => Navigator.pop(context, 'import_excel'),
            ),
            if (showExport) const Divider(),
          ],
          if (showExport) ...[
            ListTile(
              leading: const Icon(Icons.download, color: Colors.orange),
              title: const Text('Export as CSV'),
              subtitle: const Text('Comma-separated values'),
              onTap: () => Navigator.pop(context, 'export_csv'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.purple),
              title: const Text('Export as Excel'),
              subtitle: const Text('.xlsx spreadsheet'),
              onTap: () => Navigator.pop(context, 'export_excel'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Success/Error Feedback ─────────────────────────────────────────────────────

void showImportSuccess(BuildContext context, int count) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Successfully imported $count records'),
      backgroundColor: Colors.green,
    ),
  );
}

void showImportError(BuildContext context, String error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Import failed: $error'),
      backgroundColor: Colors.red,
    ),
  );
}

void showExportSuccess(BuildContext context, String filename) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Exported to $filename'),
      backgroundColor: Colors.green,
    ),
  );
}
