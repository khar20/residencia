import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'models.dart';
import 'excel_service.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TenantListScreen(),
    ),
  );
}

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  late Future<List<Tenant>> _tenantList;
  final ExcelService _excelService = ExcelService();

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _tenantList = DatabaseHelper.instance.readAllTenants();
    });
  }

  // Dialog to choose Export method
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Database'),
        content: const Text('Choose how you want to export the Excel file.'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await _excelService.shareExcel();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save to Device'),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              String? path = await _excelService.saveToDevice();

              if (!mounted) return;

              if (path != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Saved to: $path')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to save file. Try Sharing instead.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Add/Edit Dialog
  void _showForm({Tenant? tenant}) {
    final fNameCtrl = TextEditingController(text: tenant?.firstName);
    final lNameCtrl = TextEditingController(text: tenant?.lastName);
    final natCtrl = TextEditingController(text: tenant?.nationality);
    final docNumCtrl = TextEditingController(text: tenant?.docNumber);

    String selectedDocType = tenant?.docType ?? 'ID Card';
    final List<String> docTypes = [
      'ID Card',
      'Passport',
      'Driver License',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tenant == null ? 'New Tenant' : 'Edit Tenant'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                    ),
                    TextField(
                      controller: lNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDocType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                      ),
                      items: docTypes.map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedDocType = val;
                        }
                      },
                    ),
                    TextField(
                      controller: docNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Document Number',
                      ),
                    ),
                    TextField(
                      controller: natCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nationality',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (fNameCtrl.text.isEmpty || docNumCtrl.text.isEmpty) {
                      return;
                    }

                    final newTenant = Tenant(
                      id: tenant?.id,
                      firstName: fNameCtrl.text,
                      lastName: lNameCtrl.text,
                      nationality: natCtrl.text,
                      docType: selectedDocType,
                      docNumber: docNumCtrl.text,
                    );

                    if (tenant == null) {
                      await DatabaseHelper.instance.createTenant(newTenant);
                    } else {
                      await DatabaseHelper.instance.updateTenant(newTenant);
                    }

                    // Check if dialog is still open
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    // Check if the main screen is still there to refresh
                    if (mounted) {
                      _refreshList();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Import Excel",
            onPressed: () async {
              await _excelService.importFromExcel();

              // Check 'context.mounted' directly to satisfy the linter
              if (!context.mounted) return;

              _refreshList();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import Successful')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export Excel",
            onPressed: () => _showExportDialog(),
          ),
        ],
      ),
      body: FutureBuilder<List<Tenant>>(
        future: _tenantList,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No tenants found.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final t = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(t.firstName.isNotEmpty ? t.firstName[0] : '?'),
                  ),
                  title: Text(
                    t.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${t.docType}: ${t.docNumber} \nNationality: ${t.nationality}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegistrationScreen(tenant: t),
                    ),
                  ),
                  trailing: PopupMenuButton(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showForm(tenant: t);
                      } else if (value == 'delete') {
                        await DatabaseHelper.instance.deleteTenant(t.id!);
                        // Safe to use 'mounted' here as we aren't using 'context'
                        if (mounted) _refreshList();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () => _showForm(),
      ),
    );
  }
}

// Room Registration Screen
class RegistrationScreen extends StatefulWidget {
  final Tenant tenant;
  const RegistrationScreen({super.key, required this.tenant});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late Future<List<RoomRegistration>> _registrations;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _registrations = DatabaseHelper.instance.readRegistrationsByTenant(
        widget.tenant.id!,
      );
    });
  }

  // Unified Dialog for Adding and Editing
  void _showRegistrationForm({RoomRegistration? existingReg}) {
    final roomCtrl = TextEditingController(text: existingReg?.roomNumber);
    // Use existing date or default to now
    DateTime selectedDate = existingReg?.checkInDate ?? DateTime.now();
    final isEditing = existingReg != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Registration' : 'Register Room'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(labelText: 'Room Number'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Check-in Date: "),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && picked != selectedDate) {
                            setStateDialog(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (roomCtrl.text.isEmpty) return;

                    final reg = RoomRegistration(
                      id: existingReg?.id, // Preserve ID if editing
                      tenantId: widget.tenant.id!,
                      roomNumber: roomCtrl.text,
                      checkInDate: selectedDate,
                    );

                    if (isEditing) {
                      await DatabaseHelper.instance.updateRegistration(reg);
                    } else {
                      await DatabaseHelper.instance.createRegistration(reg);
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    if (mounted) _refresh();
                  },
                  child: Text(isEditing ? 'Save' : 'Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRegistration(int id) async {
    await DatabaseHelper.instance.deleteRegistration(id);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tenant.firstName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(child: Text("History for ${widget.tenant.fullName}")),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<RoomRegistration>>(
              future: _registrations,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text("No room history"));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final reg = snapshot.data![index];
                    return ListTile(
                      leading: const Icon(Icons.bedroom_parent),
                      title: Text('Room: ${reg.roomNumber}'),
                      subtitle: Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(reg.checkInDate)}',
                      ),
                      trailing: PopupMenuButton(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showRegistrationForm(existingReg: reg);
                          } else if (value == 'delete') {
                            await _deleteRegistration(reg.id!);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRegistrationForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
