
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:seniorsync/backend/modules/health/vitals_model.dart';
import 'package:seniorsync/backend/modules/health/health_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late HealthService _healthService;
  List<Vitals> _vitals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _healthService = HealthService(userId: auth.user!.uid);
      _loadVitals();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVitals() async {
    setState(() => _isLoading = true);
    try {
      final items = await _healthService.fetchVitals();
      setState(() => _vitals = items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("My Health", style: SeniorStyles.header),
        actions: [
          IconButton(onPressed: _loadVitals, icon: const Icon(Icons.refresh, color: SeniorStyles.primaryBlue)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadVitals,
            child: _vitals.isEmpty 
              ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height*0.7, child: _buildEmptyState())])
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text("Latest Numbers", style: SeniorStyles.subheader),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildLargeMetric("BP", _vitals.first.bloodPressure, SeniorStyles.alertRed, "mmHg")),
                        const SizedBox(width: 12),
                        Expanded(child: _buildLargeMetric("Pulse", "${_vitals.first.heartRate}", Colors.pink, "bpm")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLargeMetric("Blood Sugar", "${_vitals.first.bloodSugar}", SeniorStyles.warningOrange, "mg/dL"),
                    const SizedBox(height: 32),
                    const Text("Weekly Trends", style: SeniorStyles.subheader),
                    const SizedBox(height: 16),
                    _buildChartCard(_vitals.reversed.toList()),
                    const SizedBox(height: 32),
                    const Text("History", style: SeniorStyles.subheader),
                    const SizedBox(height: 12),
                    ..._vitals.map((v) => _buildHistoryItem(v)),
                    const SizedBox(height: 80),
                  ],
                ),
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SeniorStyles.primaryBlue,
        onPressed: () => _showAddVitalsDialog(context),
        tooltip: 'Add Reading',
        child: const Icon(Icons.add_chart, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No health data yet", style: SeniorStyles.subheader),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => _showAddVitalsDialog(context), child: const Text("Add First Reading")),
        ],
      ),
    );
  }

  Widget _buildLargeMetric(String label, String value, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SeniorStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(fontSize: 14, color: Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<Vitals> items) {
    // Duplicate the spot to draw a continuous graph even if there is only 1 entry recorded 
    List<Vitals> chartItems = items;
    if (chartItems.length == 1) {
      chartItems = [items.first, items.first];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SeniorStyles.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, color: Colors.pink, margin: const EdgeInsets.only(right: 6)),
              const Text("Heart Rate", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 16),
              Container(width: 12, height: 12, color: SeniorStyles.warningOrange, margin: const EdgeInsets.only(right: 6)),
              const Text("Blood Sugar (x0.5)", style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartItems.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.heartRate.toDouble())).toList(),
                    isCurved: true,
                    color: Colors.pink,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.pink.withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: chartItems.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.bloodSugar.toDouble() / 2)).toList(), // Scaled for demo
                    isCurved: true,
                    color: SeniorStyles.warningOrange,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: SeniorStyles.warningOrange.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Vitals v) {
    final date = DateFormat('MMM dd, hh:mm a').format(v.timestamp);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text("BP: ${v.bloodPressure} | HR: ${v.heartRate}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Text("Sugar: ${v.bloodSugar}", style: const TextStyle(color: SeniorStyles.warningOrange, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddVitalsDialog(BuildContext context) {
    final bpCtrl = TextEditingController();
    final hrCtrl = TextEditingController();
    final bsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Record New Vitals", style: SeniorStyles.header),
            const SizedBox(height: 24),
            TextField(controller: bpCtrl, decoration: const InputDecoration(labelText: "Blood Pressure (e.g. 120/80)", border: OutlineInputBorder()), style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            TextField(controller: hrCtrl, decoration: const InputDecoration(labelText: "Heart Rate (bpm)", border: OutlineInputBorder()), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            TextField(controller: bsCtrl, decoration: const InputDecoration(labelText: "Blood Sugar (mg/dL)", border: OutlineInputBorder()), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final bp = bpCtrl.text.trim();
                  final hr = int.tryParse(hrCtrl.text) ?? 0;
                  final bs = int.tryParse(bsCtrl.text) ?? 0;

                  final bpRegex = RegExp(r'^\d{2,3}\/\d{2,3}$');

                  if (bp.isEmpty || !bpRegex.hasMatch(bp) || hr <= 0 || hr > 300 || bs <= 0 || bs > 600) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid vitals (e.g. BP: 120/80)')),
                    );
                    return;
                  }

                  final v = Vitals(
                    bloodPressure: bp,
                    heartRate: hr,
                    bloodSugar: bs,
                    timestamp: DateTime.now(),
                  );
                  await _healthService.addVitals(v);
                  if (context.mounted) Navigator.pop(context);
                  _loadVitals();
                },
                style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.primaryBlue, foregroundColor: Colors.white),
                child: const Text("Save Vitals", style: SeniorStyles.largeButtonText),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
