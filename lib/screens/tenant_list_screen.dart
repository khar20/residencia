import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../excel_service.dart';
import '../utils/dialogs.dart';
import 'registration_screen.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  late Future<List<Tenant>> _tenantListFuture;
  final ExcelService _excelService = ExcelService();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshList({String query = ''}) {
    setState(() {
      _tenantListFuture = query.isEmpty
          ? DatabaseHelper.instance.readAllTenants()
          : DatabaseHelper.instance.searchTenants(query);
    });
  }

  Future<void> _confirmAndDeleteTenant(int id) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Tenant',
      content:
          'Are you sure you want to delete this tenant? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      await DatabaseHelper.instance.deleteTenant(id);
      if (mounted) _refreshList(query: _searchController.text);
    }
  }

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

              if (!ctx.mounted) return;

              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    path != null ? 'Saved to: $path' : 'Failed to save file.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openTenantForm({Tenant? tenant}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TenantFormDialog(tenant: tenant),
    );

    if (result == true && mounted) {
      _refreshList();
    }
  }

  void _importExcel() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Importing... please wait')));

    final message = await _excelService.importFromExcel();

    if (!mounted) return;
    _refreshList();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                onChanged: (value) => _refreshList(query: value),
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
              onPressed: _importExcel,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: "Export Excel",
              onPressed: _showExportDialog,
            ),
          ],
        ],
      ),
      body: FutureBuilder<List<Tenant>>(
        future: _tenantListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                _isSearching
                    ? 'No matches found.'
                    : 'No tenants found. Add one!',
              ),
            );
          }

          final tenants = snapshot.data!;

          return ListView.builder(
            itemCount: tenants.length,
            itemExtent: 95.0,
            itemBuilder: (context, index) {
              final t = tenants[index];
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
                    '${t.docType}: ${t.docNumber}\n${t.nationality}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegistrationScreen(tenant: t),
                    ),
                  ),
                  trailing: PopupMenuButton(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openTenantForm(tenant: t);
                      } else if (value == 'delete') {
                        _confirmAndDeleteTenant(t.id!);
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
          _openTenantForm();
        },
      ),
    );
  }
}

class TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;

  const TenantFormDialog({super.key, this.tenant});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
  late TextEditingController fNameCtrl;
  late TextEditingController lNameCtrl;
  late TextEditingController docNumCtrl;

  String currentDocType = '';
  String currentNationality = '';

  List<String> availableDocTypes = [];
  List<String> availableNationalities = [];

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    fNameCtrl = TextEditingController(text: widget.tenant?.firstName);
    lNameCtrl = TextEditingController(text: widget.tenant?.lastName);
    docNumCtrl = TextEditingController(text: widget.tenant?.docNumber);
    currentDocType = widget.tenant?.docType ?? '';
    currentNationality = widget.tenant?.nationality ?? '';

    _loadSuggestions();
  }

  void _loadSuggestions() async {
    final db = DatabaseHelper.instance;
    final docs = await db.getDistinctDocTypes();
    final nats = await db.getDistinctNationalities();

    if (mounted) {
      setState(() {
        availableDocTypes = docs;
        availableNationalities = nats;
      });
    }
  }

  @override
  void dispose() {
    fNameCtrl.dispose();
    lNameCtrl.dispose();
    docNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (currentDocType.trim().isEmpty || currentNationality.trim().isEmpty) {
      setState(() {});
      return;
    }

    if (widget.tenant != null) {
      final confirm = await showConfirmationDialog(
        context: context,
        title: 'Save Changes?',
        content: 'Update this tenant?',
        confirmText: 'Update',
      );
      if (!confirm) return;
    }

    final newTenant = Tenant(
      id: widget.tenant?.id,
      firstName: fNameCtrl.text.trim(),
      lastName: lNameCtrl.text.trim(),
      nationality: currentNationality.trim(),
      docType: currentDocType.trim(),
      docNumber: docNumCtrl.text.trim(),
    );

    if (widget.tenant == null) {
      await DatabaseHelper.instance.createTenant(newTenant);
    } else {
      await DatabaseHelper.instance.updateTenant(newTenant);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tenant == null ? 'New Tenant' : 'Edit Tenant'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fNameCtrl,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (val) => val!.trim().isEmpty ? 'Required' : null,
              ),

              TextFormField(
                controller: lNameCtrl,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (val) => val!.trim().isEmpty ? 'Required' : null,
              ),

              _buildAutocomplete(
                label: 'Document Type',
                initialValue: currentDocType,
                options: availableDocTypes,
                onChanged: (val) => currentDocType = val,
              ),

              TextFormField(
                controller: docNumCtrl,
                decoration: const InputDecoration(labelText: 'Document Number'),
                validator: (val) => val!.trim().isEmpty ? 'Required' : null,
              ),

              _buildAutocomplete(
                label: 'Nationality',
                initialValue: currentNationality,
                options: availableNationalities,
                onChanged: (val) => currentNationality = val,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildAutocomplete({
    required String label,
    required String initialValue,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') return options;
        return options.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onChanged: (val) {
            onChanged(val);
          },
          validator: (val) => val!.trim().isEmpty ? 'Required' : null,
        );
      },
    );
  }
}
