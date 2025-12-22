import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils/dialogs.dart';

class RegistrationScreen extends StatefulWidget {
  final Tenant tenant;
  const RegistrationScreen({super.key, required this.tenant});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late Future<List<RoomRegistration>> _registrationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _registrationsFuture = DatabaseHelper.instance.readRegistrationsByTenant(
        widget.tenant.id!,
      );
    });
  }

  void _openRegistrationForm({RoomRegistration? existingReg}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RegistrationFormDialog(
        tenantId: widget.tenant.id!,
        existingReg: existingReg,
      ),
    );

    if (result == true && mounted) {
      _refresh();
    }
  }

  Future<void> _confirmAndDeleteRegistration(int id) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Registration',
      content: 'Are you sure you want to remove this room history?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      await DatabaseHelper.instance.deleteRegistration(id);
      if (mounted) _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tenant.fullName)),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildRegistrationList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRegistrationForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text("History for ${widget.tenant.fullName}")),
        ],
      ),
    );
  }

  Widget _buildRegistrationList() {
    return FutureBuilder<List<RoomRegistration>>(
      future: _registrationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No room history"));
        }

        final registrations = snapshot.data!;

        return ListView.builder(
          itemCount: registrations.length,
          itemBuilder: (context, index) {
            final reg = registrations[index];
            return ListTile(
              leading: const Icon(Icons.bedroom_parent),
              title: Text('Room: ${reg.roomNumber}'),
              subtitle: Text(
                'Date: ${DateFormat('yyyy-MM-dd').format(reg.checkInDate)}',
              ),
              trailing: PopupMenuButton(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openRegistrationForm(existingReg: reg);
                  } else if (value == 'delete') {
                    _confirmAndDeleteRegistration(reg.id!);
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
            );
          },
        );
      },
    );
  }
}

class _RegistrationFormDialog extends StatefulWidget {
  final int tenantId;
  final RoomRegistration? existingReg;

  const _RegistrationFormDialog({required this.tenantId, this.existingReg});

  @override
  State<_RegistrationFormDialog> createState() =>
      __RegistrationFormDialogState();
}

class __RegistrationFormDialogState extends State<_RegistrationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roomCtrl;
  late DateTime _selectedDate;
  bool get _isEditing => widget.existingReg != null;

  @override
  void initState() {
    super.initState();
    _roomCtrl = TextEditingController(text: widget.existingReg?.roomNumber);
    _selectedDate = widget.existingReg?.checkInDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditing) {
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'Save Changes?',
        content: 'Are you sure you want to update this registration?',
        confirmText: 'Update',
      );
      if (!confirmed) return;
    }

    final reg = RoomRegistration(
      id: widget.existingReg?.id,
      tenantId: widget.tenantId,
      roomNumber: _roomCtrl.text,
      checkInDate: _selectedDate,
    );

    if (_isEditing) {
      await DatabaseHelper.instance.updateRegistration(reg);
    } else {
      await DatabaseHelper.instance.createRegistration(reg);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Registration' : 'Register Room'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _roomCtrl,
              decoration: const InputDecoration(labelText: 'Room Number'),
              validator: (val) => val!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Check-in Date: "),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Register'),
        ),
      ],
    );
  }
}
