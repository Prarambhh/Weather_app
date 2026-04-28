import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'advisory_screen.dart';
import 'intel_report_screen.dart';

class DirectionPickerScreen extends StatelessWidget {
  final FlowType flowType;
  final String? nearestLocationId;

  const DirectionPickerScreen({
    super.key,
    required this.flowType,
    required this.nearestLocationId,
  });

  void _selectDirection(BuildContext context, bool isMumbaiToPune) {
    if (flowType == FlowType.planning) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdvisoryScreen(isMumbaiToPune: isMumbaiToPune),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IntelReportScreen(
            nearestLocationId: nearestLocationId ?? 'mumbai',
            isMumbaiToPune: isMumbaiToPune,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Direction'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Which way are you heading?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildDirectionCard(
              context,
              title: 'Mumbai → Pune',
              subtitle: 'Via Khopoli & Lonavala Ghats',
              onTap: () => _selectDirection(context, true),
            ),
            const SizedBox(height: 24),
            _buildDirectionCard(
              context,
              title: 'Pune → Mumbai',
              subtitle: 'Via Lonavala & Khopoli',
              onTap: () => _selectDirection(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionCard(BuildContext context, {required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
