import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models.dart';

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

                    // Confirmation before Editing
                    if (isEditing) {
                      final confirmEdit = await _showConfirmationDialog(
                        title: 'Save Changes?',
                        content:
                            'Are you sure you want to update this registration?',
                        confirmText: 'Update',
                      );
                      if (!confirmEdit) return;
                    }

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

  // Delete with confirmation
  Future<void> _confirmAndDeleteRegistration(int id) async {
    final confirmed = await _showConfirmationDialog(
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
                            await _confirmAndDeleteRegistration(reg.id!);
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
