import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models.dart';

class ExcelService {
  // EXPORT
  Future<List<int>?> _generateExcelBytes() async {
    final db = DatabaseHelper.instance;
    var excel = Excel.createExcel();

    // Tenants Sheet
    Sheet sheetTenants = excel['Tenants'];
    excel.delete('Sheet1');

    sheetTenants.appendRow([
      TextCellValue('ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Nationality'),
      TextCellValue('Doc Type'),
      TextCellValue('Doc Number'),
    ]);

    List<Tenant> tenants = await db.readAllTenants();

    tenants.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

    for (var t in tenants) {
      sheetTenants.appendRow([
        IntCellValue(t.id!),
        TextCellValue(t.firstName),
        TextCellValue(t.lastName),
        TextCellValue(t.nationality),
        TextCellValue(t.docType),
        TextCellValue(t.docNumber),
      ]);
    }

    // Registrations Sheet
    Sheet sheetRegs = excel['Registrations'];
    sheetRegs.appendRow([
      TextCellValue('Tenant ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Doc Type'),
      TextCellValue('Doc Number'),
      TextCellValue('Room Number'),
      TextCellValue('Check-in Date'),
    ]);

    List<Map<String, dynamic>> rawRegs = await db
        .getAllRegistrationsForExport();
    for (var row in rawRegs) {
      sheetRegs.appendRow([
        IntCellValue(row['tenant_id'] as int),
        TextCellValue(row['first_name'].toString()),
        TextCellValue(row['last_name'].toString()),
        TextCellValue(row['doc_type'].toString()),
        TextCellValue(row['doc_number'].toString()),
        TextCellValue(row['room_number'].toString()),
        TextCellValue(row['check_in_date'].toString().split(' ')[0]),
      ]);
    }

    return excel.save();
  }

  // IMPORT
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
        return "Error: ${e.message}";
      }

      var excel = Excel.decodeBytes(bytes);
      final db = DatabaseHelper.instance;

      // Check if at least Tenants sheet exists before wiping DB
      if (!excel.tables.containsKey('Tenants')) {
        return "Error: Invalid Excel file (Missing 'Tenants' sheet)";
      }

      // WIPE OLD DATA
      await db.clearAllData();

      int tenantsAdded = 0;
      int regsAdded = 0;

      // Map to link Excel IDs to new Database IDs
      // Map<Excel_ID, New_DB_ID>
      Map<int, int> excelIdToDbId = {};

      // Process Tenants Sheet
      if (excel.tables.containsKey('Tenants')) {
        var table = excel.tables['Tenants']!;
        for (var row in table.rows.skip(1)) {
          if (row.length >= 6) {
            int? excelId;
            if (row[0]?.value != null) {
              excelId = int.tryParse(row[0]!.value.toString());
            }

            String fName = row[1]?.value.toString() ?? "";
            String lName = row[2]?.value.toString() ?? "";
            String nat = row[3]?.value.toString() ?? "";
            String dType = row[4]?.value.toString() ?? "ID";
            String dNum = row[5]?.value.toString() ?? "";

            if (fName.isNotEmpty && dNum.isNotEmpty && excelId != null) {
              // Create new tenant
              int newDbId = await db.createTenant(
                Tenant(
                  firstName: fName,
                  lastName: lName,
                  nationality: nat,
                  docType: dType,
                  docNumber: dNum,
                ),
              );
              tenantsAdded++;

              // Store mapping: Excel said ID was 5, but DB says ID is 1
              excelIdToDbId[excelId] = newDbId;
            }
          }
        }
      }

      // Process Registrations Sheet
      if (excel.tables.containsKey('Registrations')) {
        var table = excel.tables['Registrations']!;
        for (var row in table.rows.skip(1)) {
          // Columns: 0:TenantID, 1:FName, 2:LName, 3:DType, 4:DNum, 5:Room, 6:Date
          if (row.length >= 7) {
            int? excelTenantId;
            if (row[0]?.value != null) {
              excelTenantId = int.tryParse(row[0]!.value.toString());
            }

            String room = row[5]?.value.toString() ?? "";
            String dateStr = row[6]?.value.toString() ?? "";

            if (excelTenantId != null && room.isNotEmpty) {
              // Use the map to find who this registration belongs to in the new DB
              int? realDbId = excelIdToDbId[excelTenantId];

              if (realDbId != null) {
                DateTime date;
                try {
                  date = DateTime.parse(dateStr);
                } catch (e) {
                  date = DateTime.now();
                }

                await db.createRegistration(
                  RoomRegistration(
                    tenantId: realDbId,
                    roomNumber: room,
                    checkInDate: date,
                  ),
                );
                regsAdded++;
              }
            }
          }
        }
      }

      return "Database Replaced: $tenantsAdded Tenants, $regsAdded Registrations";
    } catch (e) {
      return "Error: $e";
    }
  }

  // SHARED / SAVE HELPERS
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
