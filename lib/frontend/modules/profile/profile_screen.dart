
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // For caregiver

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.dbUser;

    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("My Profile", style: SeniorStyles.header),
      ),
      body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(user, auth),
                const SizedBox(height: 24),
                if (user != null) ...[
                  _buildSettingsSection(context, auth, user),
                  const SizedBox(height: 24),
                  _buildCaregiverSection(context, auth, user),
                ] else ...[
                  // Fallback when dbUser is null — show Firebase data + retry
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: SeniorStyles.cardDecoration,
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Text("Profile not synced with server",
                            style: TextStyle(fontSize: 18, color: Colors.black54)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await auth.retrySync();
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry Sync", style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SeniorStyles.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeniorStyles.alertRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => auth.signOut(),
                  child: const Text("Log Out", style: SeniorStyles.largeButtonText),
                ),
                const SizedBox(height: 16),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: SeniorStyles.alertRed,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () => _showEraseAccountWarning(context, auth),
                  child: const Text("Erase Application Data & Account", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  void _showEraseAccountWarning(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Erase Everything?", style: TextStyle(color: SeniorStyles.alertRed, fontWeight: FontWeight.bold)),
        content: const Text("This action is permanent. All your vitals, medications, routines, and account data will be completely erased from the servers. You cannot undo this."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.alertRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.eraseAccount();
              await auth.signOut();
            },
            child: const Text("Permanently Erase"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user, AuthService auth) {
    final displayName = user?['name'] ?? auth.user?.displayName ?? auth.user?.email?.split('@').first ?? "User";
    final displayEmail = user?['email'] ?? auth.user?.email ?? "";
    final displayRole = user?['role']?.toUpperCase() ?? "SENIOR";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SeniorStyles.cardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: SeniorStyles.primaryBlue,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: SeniorStyles.cardTitle),
                Text(displayEmail, style: SeniorStyles.cardSubtitle),
                const SizedBox(height: 4),
                Chip(
                  label: Text(displayRole),
                  backgroundColor: SeniorStyles.primaryBlue.withOpacity(0.1),
                  labelStyle: const TextStyle(color: SeniorStyles.primaryBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, AuthService auth, Map<String, dynamic> user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Details", style: SeniorStyles.subheader),
        const SizedBox(height: 12),
        _buildActionCard(
          "Edit Name",
          user['name'],
          Icons.person_outline,
          () => _showEditDialog(context, auth, "Name", user['name'], (val) => auth.updateProfile(name: val)),
        ),
        _buildActionCard(
          "Age",
          "${user['age'] ?? 'Not set'}",
          Icons.cake_outlined,
          () => _showEditDialog(context, auth, "Age", "${user['age'] ?? ''}", (val) => auth.updateProfile(age: int.tryParse(val))),
        ),
        _buildActionCard(
          "Medical Conditions",
          (user['conditions'] as List?)?.join(', ') ?? 'None set',
          Icons.medical_information_outlined,
          () => _showEditDialog(
            context, auth, "Conditions (Comma Separated)",
            (user['conditions'] as List?)?.join(', ') ?? '',
            (val) => auth.updateProfile(conditions: val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList())
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: SeniorStyles.cardDecoration,
          child: SwitchListTile(
            title: const Text("I am a Caregiver", style: SeniorStyles.cardSubtitle),
            secondary: const Icon(Icons.medical_services_outlined, color: SeniorStyles.primaryBlue),
            activeColor: SeniorStyles.primaryBlue,
            value: user['role'] == 'caregiver',
            onChanged: (val) {
              auth.updateProfile(role: val ? 'caregiver' : 'senior');
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: SeniorStyles.cardDecoration,
          child: SwitchListTile(
            title: const Text("Lock App with Biometrics", style: SeniorStyles.cardSubtitle),
            secondary: const Icon(Icons.fingerprint, color: SeniorStyles.primaryBlue),
            activeColor: SeniorStyles.primaryBlue,
            value: auth.useBiometrics,
            onChanged: (val) {
              auth.toggleBiometrics(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverSection(BuildContext context, AuthService auth, Map<String, dynamic> user) {
    final caregivers = user['caregivers'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("My Caregivers", style: SeniorStyles.subheader),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code, color: SeniorStyles.primaryBlue),
                  onPressed: () => _showMyQRCodeDialog(context, user),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCaregiverDialog(context, auth),
                  icon: const Icon(Icons.add),
                  label: const Text("Add New"),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (caregivers.isEmpty)
          const Text("No caregivers linked yet.", style: SeniorStyles.cardSubtitle)
        else
          ...caregivers.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.shield_outlined, color: SeniorStyles.successGreen),
                  title: Text(c),
                  subtitle: const Text("Linked via UID"),
                ),
              )),
      ],
    );
  }

  Widget _buildActionCard(String title, String? value, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: SeniorStyles.primaryBlue),
        title: Text(title),
        subtitle: Text(value ?? "Not set"),
        trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
      ),
    );
  }

  void _showEditDialog(BuildContext context, AuthService auth, String field, String current, Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $field"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: "Enter $field"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              onSave(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAddCaregiverDialog(BuildContext context, AuthService auth) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Link Caregiver"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your caregiver's email address to link them to your account."),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: "Caregiver Email", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                await auth.addCaregiver(ctrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caregiver linked!")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text("Link"),
          ),
        ],
      ),
    );
  }

  void _showMyQRCodeDialog(BuildContext context, Map<String, dynamic> user) {
    final uid = user['firebaseUid'];
    if (uid == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("My QR Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Have your caregiver scan this code to link with your account.", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: "seniorsync_uid:$uid",
                version: QrVersions.auto,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }
}
