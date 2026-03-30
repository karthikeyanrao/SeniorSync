import 'package:flutter/material.dart';

class SeniorSyncHome extends StatelessWidget {
  const SeniorSyncHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SeniorSync"),
        centerTitle: true,
      ),

      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,

        children: const [
          ModuleCard(title: "Vitals"),
          ModuleCard(title: "Medicine"),
          ModuleCard(title: "Emergency SOS"),
          ModuleCard(title: "Appointments"),
          ModuleCard(title: "Daily Activity"),
          ModuleCard(title: "Caregiver Chat"),
          ModuleCard(title: "Profile"),
        ],
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  final String title;
  const ModuleCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
