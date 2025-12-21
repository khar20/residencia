import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
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
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      final db = DatabaseHelper.instance;

      int tenantsAdded = 0;
      int regsAdded = 0;

      // This map links the ID in the Excel file to the REAL ID in the database
      Map<int, int> excelIdToDbId = {};

      // Process Tenants Sheet first to build the ID Map
      if (excel.tables.containsKey('Tenants')) {
        var table = excel.tables['Tenants']!;
        for (var row in table.rows.skip(1)) {
          if (row.length >= 6) {
            // Parse Excel Data
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
              // Check if tenant already exists in DB by Document Number
              int? existingDbId = await db.getTenantIdByDoc(dNum);

              if (existingDbId != null) {
                // Tenant exists, map Excel ID to existing DB ID
                excelIdToDbId[excelId] = existingDbId;
              } else {
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
                excelIdToDbId[excelId] = newDbId;
              }
            }
          }
        }
      }

      // Process Registrations Sheet using the ID Map
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
              // Find the real database ID using our map
              int? realDbId = excelIdToDbId[excelTenantId];

              if (realDbId != null) {
                // Parse date
                DateTime date;
                try {
                  date = DateTime.parse(dateStr);
                } catch (e) {
                  date = DateTime.now();
                }

                // Insert Registration linked to the correct local DB ID
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

      return "Imported: $tenantsAdded Tenants, $regsAdded Registrations";
    } catch (e) {
      return "Error: $e";
    }
  }

  // SHARED / SAVE HELPERS

  Future<void> shareExcel() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return;

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/residencia_database.xlsx";
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Residencia Full Database Export',
      ),
    );
  }

  Future<String?> saveToDevice() async {
    final fileBytes = await _generateExcelBytes();
    if (fileBytes == null) return null;

    String? outputFile;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Database Export',
        fileName: 'residencia_backup.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
    } else if (Platform.isAndroid) {
      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
      if (directory != null) {
        String fileName =
            "residencia_backup_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        outputFile = p.join(directory.path, fileName);
      }
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      outputFile = p.join(directory.path, "residencia_backup.xlsx");
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
