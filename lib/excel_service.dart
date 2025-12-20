import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'models.dart';

class ExcelService {
  // EXPORT
  Future<void> exportToExcel() async {
    final db = DatabaseHelper.instance;
    List<Tenant> tenants = await db.readAllTenants();

    var excel = Excel.createExcel();
    Sheet sheet = excel['Tenants'];
    excel.delete('Sheet1'); // Remove default sheet

    // Add Headers
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
      // Get latest room info for the report
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

    // Save and Share
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/tenants_report.xlsx";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      // Share file allowing user to save to Drive/Files
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Tenants Database Export'),
      );
    }
  }

  // IMPORT
  Future<void> importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      final db = DatabaseHelper.instance;

      for (var table in excel.tables.keys) {
        if (excel.tables[table] == null) continue;

        // Skip header row (index 0), start from row 1
        for (var row in excel.tables[table]!.rows.skip(1)) {
          // Ensure row has enough columns
          if (row.length >= 6) {
            String fName = row[1]?.value.toString() ?? "";
            String lName = row[2]?.value.toString() ?? "";
            String nat = row[3]?.value.toString() ?? "";
            String dType = row[4]?.value.toString() ?? "ID";
            String dNum = row[5]?.value.toString() ?? "";

            if (fName.isNotEmpty && dNum.isNotEmpty) {
              await db.createTenant(
                Tenant(
                  firstName: fName,
                  lastName: lName,
                  nationality: nat,
                  docType: dType,
                  docNumber: dNum,
                ),
              );
            }
          }
        }
      }
    }
  }
}
