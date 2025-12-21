import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'db_helper.dart';
import 'models.dart';

List<Tenant> parseExcelInIsolate(List<int> bytes) {
  var excel = Excel.decodeBytes(bytes);
  List<Tenant> tenants = [];

  for (var table in excel.tables.keys) {
    if (excel.tables[table] == null) continue;
    for (var row in excel.tables[table]!.rows.skip(1)) {
      if (row.length >= 6) {
        String fName = row[1]?.value.toString() ?? "";
        String dNum = row[5]?.value.toString() ?? "";

        if (fName.isNotEmpty && dNum.isNotEmpty) {
          tenants.add(
            Tenant(
              firstName: fName,
              lastName: row[2]?.value.toString() ?? "",
              nationality: row[3]?.value.toString() ?? "",
              docType: row[4]?.value.toString() ?? "ID",
              docNumber: dNum,
            ),
          );
        }
      }
    }
  }
  return tenants;
}

class ExcelService {
  // Helper: Generates the Excel file in memory
  Future<List<int>?> _generateExcelBytes() async {
    final db = DatabaseHelper.instance;
    List<Tenant> tenants = await db.readAllTenants();

    var excel = Excel.createExcel();
    Sheet sheet = excel['Tenants'];
    excel.delete('Sheet1');

    // Headers
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Nationality'),
      TextCellValue('Doc Type'),
      TextCellValue('Doc Number'),
      TextCellValue('Last Room'),
      TextCellValue('Check-in Date'),
    ]);

    for (var tenant in tenants) {
      List<RoomRegistration> regs = await db.readRegistrationsByTenant(
        tenant.id!,
      );
      String lastRoom = regs.isNotEmpty ? regs.first.roomNumber : '-';
      String lastDate = regs.isNotEmpty
          ? regs.first.checkInDate.toString().split(' ')[0]
          : '-';

      sheet.appendRow([
        IntCellValue(tenant.id!),
        TextCellValue(tenant.firstName),
        TextCellValue(tenant.lastName),
        TextCellValue(tenant.nationality),
        TextCellValue(tenant.docType),
        TextCellValue(tenant.docNumber),
        TextCellValue(lastRoom),
        TextCellValue(lastDate),
      ]);
    }

    return excel.save();
  }

  // OPTION 1: Share
  Future<void> shareExcel() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/tenants_report.xlsx";
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Tenants Database Export'),
    );
  }

  // OPTION 2: Save directly to device
  Future<String?> saveToDevice() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return null;

    String? outputFile;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // DESKTOP: Use "Save As" dialog
      outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Tenants Report',
        fileName: 'tenants_report.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
    } else if (Platform.isAndroid) {
      // ANDROID: Try to save to "Downloads" folder
      // Note: On Android 11+, this creates a file in the public Download directory.
      Directory? directory = Directory('/storage/emulated/0/Download');
      // Fallback if that path doesn't exist
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }

      if (directory != null) {
        // Create a unique filename to avoid overwriting
        String fileName =
            "tenants_report_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        outputFile = p.join(directory.path, fileName);
      }
    } else if (Platform.isIOS) {
      // IOS: Save to Documents (accessible via Files app)
      final directory = await getApplicationDocumentsDirectory();
      outputFile = p.join(directory.path, "tenants_report.xlsx");
    }

    if (outputFile != null) {
      try {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return outputFile;
      } catch (e) {
        print("Error saving file: $e");
        return null;
      }
    }
    return null;
  }

  // Import
  Future<void> importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      var bytes = await file.readAsBytes();

      List<Tenant> newTenants = await compute(parseExcelInIsolate, bytes);

      final db = await DatabaseHelper.instance.database;
      final batch = db.batch();

      for (var t in newTenants) {
        batch.insert('tenants', t.toMap());
      }
      await batch.commit(noResult: true);
    }
  }
}
