import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, String>> _contacts = [];
  static const _storageKey = 'emergency_contacts';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final List<dynamic> decoded = json.decode(raw);
      setState(() {
        _contacts = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(_contacts));
  }

  Future<void> _addOrEditContact({Map<String, String>? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final relationCtrl = TextEditingController(text: existing?['relation'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'Add Emergency Contact' : 'Edit Contact', style: SeniorStyles.subheader),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationCtrl,
              decoration: const InputDecoration(labelText: 'Relation (e.g. Son, Doctor)', prefixIcon: Icon(Icons.group)),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
      final contact = {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'relation': relationCtrl.text.trim(),
      };
      setState(() {
        if (index != null) {
          _contacts[index] = contact;
        } else {
          _contacts.add(contact);
        }
      });
      await _saveContacts();
    }
  }

  Future<void> _deleteContact(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Remove ${_contacts[index]['name']} from emergency contacts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: SeniorStyles.alertRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _contacts.removeAt(index));
      await _saveContacts();
    }
  }

  void _callContact(String phone) {
    launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text('Emergency Contacts', style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOrEditContact,
        backgroundColor: SeniorStyles.primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('No emergency contacts yet', style: SeniorStyles.subheader),
                  const SizedBox(height: 8),
                  const Text('Add trusted contacts who can be reached\nin an emergency.', textAlign: TextAlign.center, style: SeniorStyles.cardSubtitle),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: SeniorStyles.alertRed),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Tap the phone icon to call any contact instantly.', style: TextStyle(color: Colors.red.shade700, fontSize: 14))),
                        ],
                      ),
                    ),
                  );
                }
                final contact = _contacts[i - 1];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: SeniorStyles.primaryBlue.withOpacity(0.12),
                      radius: 26,
                      child: Text(
                        contact['name']![0].toUpperCase(),
                        style: const TextStyle(color: SeniorStyles.primaryBlue, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    title: Text(contact['name'] ?? '', style: SeniorStyles.cardTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((contact['relation'] ?? '').isNotEmpty)
                          Text(contact['relation']!, style: const TextStyle(color: SeniorStyles.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(contact['phone'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black54)),
                      ],
                    ),
                    isThreeLine: (contact['relation'] ?? '').isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone, color: SeniorStyles.successGreen, size: 28),
                          onPressed: () => _callContact(contact['phone'] ?? ''),
                          tooltip: 'Call',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.black45, size: 24),
                          onPressed: () => _addOrEditContact(existing: contact, index: i - 1),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: SeniorStyles.alertRed, size: 24),
                          onPressed: () => _deleteContact(i - 1),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
