import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/backend/modules/sos/sos_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class SOSHistoryScreen extends StatefulWidget {
  const SOSHistoryScreen({super.key});

  @override
  State<SOSHistoryScreen> createState() => _SOSHistoryScreenState();
}

class _SOSHistoryScreenState extends State<SOSHistoryScreen> {
  late SOSService _sosService;
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _sosService = SOSService(userId: auth.user!.uid);
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _sosService.getSOSHistory();
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text("SOS History", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SeniorStyles.primaryBlue),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text("No SOS history", style: SeniorStyles.subheader),
                      const SizedBox(height: 8),
                      const Text("You haven't triggered any alerts.", style: SeniorStyles.cardSubtitle),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final date = DateTime.tryParse(item['timestamp'] ?? '');
                    final formattedDate = date != null ? "${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}" : "Unknown Date";
                    final status = item['status'] ?? 'unknown';
                    
                    Color statusColor = Colors.grey;
                    IconData statusIcon = Icons.info_outline;

                    if (status == 'active') {
                      statusColor = SeniorStyles.alertRed;
                      statusIcon = Icons.warning_amber_rounded;
                    } else if (status == 'resolved') {
                      statusColor = SeniorStyles.successGreen;
                      statusIcon = Icons.check_circle_outline;
                    } else if (status == 'cancelled') {
                      statusColor = Colors.orange;
                      statusIcon = Icons.cancel_outlined;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text("SOS Alert", style: SeniorStyles.cardTitle),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Status: ${status.toUpperCase()}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                           // Optionally expand to show precise coordinates if needed
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                             content: Text("Location: ${item['location']?['latitude']}, ${item['location']?['longitude']}"),
                             duration: const Duration(seconds: 2),
                           ));
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
