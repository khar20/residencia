import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../excel_service.dart';
import 'registration_screen.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  late Future<List<Tenant>> _tenantList;
  final ExcelService _excelService = ExcelService();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList({String query = ''}) {
    setState(() {
      if (query.isEmpty) {
        _tenantList = DatabaseHelper.instance.readAllTenants();
      } else {
        _tenantList = DatabaseHelper.instance.searchTenants(query);
      }
    });
  }

  // Helper for Confirmation Dialogs
  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    Color confirmColor = Colors.blue,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Logic to delete tenant with confirmation
  Future<void> _confirmAndDeleteTenant(int id) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Tenant',
      content:
          'Are you sure you want to delete this tenant? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      await DatabaseHelper.instance.deleteTenant(id);
      if (mounted) {
        // Refresh with current query to keep search results consistent
        _refreshList(query: _searchController.text);
      }
    }
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
              Navigator.pop(ctx);
              await _excelService.shareExcel();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save to Device'),
            onPressed: () async {
              Navigator.pop(ctx);
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
  void _showForm({Tenant? tenant}) async {
    final fNameCtrl = TextEditingController(text: tenant?.firstName);
    final lNameCtrl = TextEditingController(text: tenant?.lastName);
    final docNumCtrl = TextEditingController(text: tenant?.docNumber);

    final db = DatabaseHelper.instance;
    List<String> availableDocTypes = await db.getDistinctDocTypes();
    List<String> availableNationalities = await db.getDistinctNationalities();

    String currentDocType = tenant?.docType ?? '';
    String currentNationality = tenant?.nationality ?? '';

    // Error State Variables
    String? fNameError;
    String? lNameError;
    String? docTypeError;
    String? docNumError;
    String? natError;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void clearError(String field) {
              setStateDialog(() {
                if (field == 'fname') fNameError = null;
                if (field == 'lname') lNameError = null;
                if (field == 'docNum') docNumError = null;
                if (field == 'nat') natError = null;
                if (field == 'docType') docTypeError = null;
              });
            }

            return AlertDialog(
              title: Text(tenant == null ? 'New Tenant' : 'Edit Tenant'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        errorText: fNameError,
                      ),
                      onChanged: (_) => clearError('fname'),
                    ),
                    TextField(
                      controller: lNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        errorText: lNameError,
                      ),
                      onChanged: (_) => clearError('lname'),
                    ),
                    const SizedBox(height: 10),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: currentDocType),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return availableDocTypes;
                        }
                        return availableDocTypes.where((String option) {
                          return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        currentDocType = selection;
                        clearError('docType');
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Document Type',
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                errorText: docTypeError,
                              ),
                              onChanged: (text) {
                                currentDocType = text;
                                clearError('docType');
                              },
                            );
                          },
                    ),
                    TextField(
                      controller: docNumCtrl,
                      decoration: InputDecoration(
                        labelText: 'Document Number',
                        errorText: docNumError,
                      ),
                      onChanged: (_) => clearError('docNum'),
                    ),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: currentNationality),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return availableNationalities;
                        }
                        return availableNationalities.where((String option) {
                          return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        currentNationality = selection;
                        clearError('nat');
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Nationality',
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                errorText: natError,
                              ),
                              onChanged: (text) {
                                currentNationality = text;
                                clearError('nat');
                              },
                            );
                          },
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
                    // VALIDATION LOGIC
                    bool isValid = true;
                    setStateDialog(() {
                      fNameError = null;
                      lNameError = null;
                      docTypeError = null;
                      docNumError = null;
                      natError = null;

                      if (fNameCtrl.text.trim().isEmpty) {
                        fNameError = 'Required';
                        isValid = false;
                      }
                      if (lNameCtrl.text.trim().isEmpty) {
                        lNameError = 'Required';
                        isValid = false;
                      }
                      if (currentDocType.trim().isEmpty) {
                        docTypeError = 'Required';
                        isValid = false;
                      }
                      if (docNumCtrl.text.trim().isEmpty) {
                        docNumError = 'Required';
                        isValid = false;
                      }
                      if (currentNationality.trim().isEmpty) {
                        natError = 'Required';
                        isValid = false;
                      }
                    });

                    if (!isValid) return;

                    // Confirmation before Editing
                    if (tenant != null) {
                      final confirmEdit = await _showConfirmationDialog(
                        title: 'Save Changes?',
                        content: 'Are you sure you want to update this tenant?',
                        confirmText: 'Update',
                      );
                      if (!confirmEdit) return;
                    }

                    // SAVE
                    final newTenant = Tenant(
                      id: tenant?.id,
                      firstName: fNameCtrl.text.trim(),
                      lastName: lNameCtrl.text.trim(),
                      nationality: currentNationality.trim(),
                      docType: currentDocType.trim(),
                      docNumber: docNumCtrl.text.trim(),
                    );

                    if (tenant == null) {
                      await DatabaseHelper.instance.createTenant(newTenant);
                    } else {
                      await DatabaseHelper.instance.updateTenant(newTenant);
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    if (mounted) _refreshList();
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search name or document...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _refreshList(query: value);
                },
              )
            : const Text('Tenant Manager'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _refreshList();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: "Import Excel",
              onPressed: () async {
                await _excelService.importFromExcel();
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
        ],
      ),
      body: FutureBuilder<List<Tenant>>(
        future: _tenantList,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                _isSearching
                    ? 'No matches found.'
                    : 'No tenants found. Add one!',
              ),
            );
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
                        await _confirmAndDeleteTenant(t.id!);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
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
        onPressed: () {
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _refreshList();
            });
          }
          _showForm();
        },
      ),
    );
  }
}
