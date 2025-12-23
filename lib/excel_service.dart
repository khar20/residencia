import 'dart:io';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models.dart';

class ExcelService {
  static const String _sheetTenants = 'Tenants';
  static const String _sheetRegistrations = 'Registrations';

  // EXPORT
  Future<List<int>?> _generateExcelBytes() async {
    final db = DatabaseHelper.instance;
    var excel = Excel.createExcel();

    // Define Styles

    // Header Style: Bold, Centered, All Borders
    CellStyle headerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Body Style: Regular, All Borders
    CellStyle bodyStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Date Style: Body Style + Date Format (yyyy-mm-dd)
    CellStyle dateStyle = bodyStyle.copyWith(
      numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'),
    );

    // SHEET 1: TENANTS
    Sheet sheetTenants = excel[_sheetTenants];
    excel.delete('Sheet1');

    List<TextCellValue> tenantHeaders = [
      TextCellValue('ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Nationality'),
      TextCellValue('Doc Type'),
      TextCellValue('Doc Number'),
    ];

    sheetTenants.appendRow(tenantHeaders);

    // Apply Header Style
    for (int i = 0; i < tenantHeaders.length; i++) {
      var cell = sheetTenants.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    List<Tenant> tenants = await db.readAllTenants();
    tenants.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

    for (int r = 0; r < tenants.length; r++) {
      var t = tenants[r];
      // Row index starts at 1 because 0 is header
      int rowIndex = r + 1;

      List<CellValue> rowData = [
        IntCellValue(t.id!),
        TextCellValue(t.firstName),
        TextCellValue(t.lastName),
        TextCellValue(t.nationality),
        TextCellValue(t.docType),
        TextCellValue(t.docNumber),
      ];

      sheetTenants.appendRow(rowData);

      // Apply Body Style to entire row
      for (int c = 0; c < rowData.length; c++) {
        var cell = sheetTenants.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );
        cell.cellStyle = bodyStyle;
      }
    }

    // SHEET 2: REGISTRATIONS
    Sheet sheetRegs = excel[_sheetRegistrations];

    List<TextCellValue> regHeaders = [
      TextCellValue('Tenant ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Doc Type'),
      TextCellValue('Doc Number'),
      TextCellValue('Room Number'),
      TextCellValue('Check-in Date'),
    ];

    sheetRegs.appendRow(regHeaders);

    // Apply Header Style
    for (int i = 0; i < regHeaders.length; i++) {
      var cell = sheetRegs.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    List<Map<String, dynamic>> rawRegs = await db
        .getAllRegistrationsForExport();

    for (int r = 0; r < rawRegs.length; r++) {
      var row = rawRegs[r];
      int rowIndex = r + 1;

      DateTime dateVal =
          DateTime.tryParse(row['check_in_date'].toString()) ?? DateTime.now();

      List<CellValue> rowData = [
        IntCellValue(row['tenant_id'] as int),
        TextCellValue(row['first_name'].toString()),
        TextCellValue(row['last_name'].toString()),
        TextCellValue(row['doc_type'].toString()),
        TextCellValue(row['doc_number'].toString()),
        TextCellValue(row['room_number'].toString()),
        DateCellValue.fromDateTime(dateVal),
      ];

      sheetRegs.appendRow(rowData);

      // Apply Styles
      for (int c = 0; c < rowData.length; c++) {
        var cell = sheetRegs.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
        );

        if (c == 6) {
          cell.cellStyle = dateStyle;
        } else {
          cell.cellStyle = bodyStyle;
        }
      }
    }

    return excel.save();
  }

  // IMPORT
  static Excel _decodeExcel(List<int> bytes) {
    return Excel.decodeBytes(bytes);
  }

  Future<String> importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) return "Cancelled";

    try {
      File file = File(result.files.single.path!);
      List<int> bytes;
      try {
        bytes = await file.readAsBytes();
      } on FileSystemException catch (e) {
        return "Error: Could not read file. Is it open? (${e.message})";
      }

      var excel = await compute(_decodeExcel, bytes);
      final dbHelper = DatabaseHelper.instance;

      if (!excel.tables.containsKey(_sheetTenants)) {
        return "Error: Invalid Excel file (Missing '$_sheetTenants' sheet)";
      }

      final db = await dbHelper.database;
      await dbHelper.clearAllData();

      int tenantsAdded = 0;
      int regsAdded = 0;
      Map<int, int> excelIdToDbId = {};

      // Process Tenants
      if (excel.tables.containsKey(_sheetTenants)) {
        var table = excel.tables[_sheetTenants]!;

        await db.transaction((txn) async {
          for (var row in table.rows.skip(1)) {
            if (row.length < 6) continue;

            int? excelId;
            // Handle different cell value types safely
            var idVal = row[0]?.value;
            if (idVal != null) {
              excelId = int.tryParse(idVal.toString());
            }

            String fName = row[1]?.value.toString() ?? "";
            String lName = row[2]?.value.toString() ?? "";
            String nat = row[3]?.value.toString() ?? "";
            String dType = row[4]?.value.toString() ?? "ID";
            String dNum = row[5]?.value.toString() ?? "";

            if (fName.isNotEmpty && dNum.isNotEmpty && excelId != null) {
              int newDbId = await txn.insert(DatabaseHelper.tableTenants, {
                'first_name': fName,
                'last_name': lName,
                'nationality': nat,
                'doc_type': dType,
                'doc_number': dNum,
                'is_deleted': 0,
              });
              tenantsAdded++;
              excelIdToDbId[excelId] = newDbId;
            }
          }
        });
      }

      // Process Registrations
      if (excel.tables.containsKey(_sheetRegistrations)) {
        var table = excel.tables[_sheetRegistrations]!;

        await db.transaction((txn) async {
          for (var row in table.rows.skip(1)) {
            if (row.length < 7) continue;

            int? excelTenantId;
            var idVal = row[0]?.value;
            if (idVal != null) {
              excelTenantId = int.tryParse(idVal.toString());
            }

            String room = row[5]?.value.toString() ?? "";
            String dateStr = row[6]?.value.toString() ?? "";

            if (excelTenantId != null && room.isNotEmpty) {
              int? realDbId = excelIdToDbId[excelTenantId];

              if (realDbId != null) {
                DateTime date = DateTime.tryParse(dateStr) ?? DateTime.now();

                await txn.insert(DatabaseHelper.tableRegistrations, {
                  'tenant_id': realDbId,
                  'room_number': room,
                  'check_in_date': date.toIso8601String().substring(0, 10),
                  'is_deleted': 0,
                });
                regsAdded++;
              }
            }
          }
        });
      }

      return "Database Replaced: $tenantsAdded Tenants, $regsAdded Registrations";
    } catch (e) {
      return "Error: $e";
    }
  }

  // SAVE HELPERS
  Future<void> shareExcel() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/residencia_export.xlsx";
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Residencia Backup'),
    );
  }

  Future<String?> saveToDevice() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return null;

    String timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    String defaultFileName = "residencia_backup_$timestamp.xlsx";
    String? outputFile;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: defaultFileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
    } else if (Platform.isAndroid) {
      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
      if (directory != null) {
        outputFile = p.join(directory.path, defaultFileName);
      }
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      outputFile = p.join(directory.path, defaultFileName);
    }

    if (outputFile != null) {
      try {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return outputFile;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
