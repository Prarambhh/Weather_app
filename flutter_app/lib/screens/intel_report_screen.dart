import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import 'advisory_screen.dart';

class IntelReportScreen extends StatefulWidget {
  final String nearestLocationId;
  final bool isMumbaiToPune;

  const IntelReportScreen({
    super.key,
    required this.nearestLocationId,
    required this.isMumbaiToPune,
  });

  @override
  State<IntelReportScreen> createState() => _IntelReportScreenState();
}

class _IntelReportScreenState extends State<IntelReportScreen> {
  String _rainfall = 'Low Rainfall';
  String _visibility = 'Clear';
  String _temperature = 'High';
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? "anonymous";

      final body = {
        "user_id": userId,
        "location": widget.nearestLocationId,
        "rainfall": _rainfall,
        "visibility": _visibility,
        "temperature": _temperature,
      };

      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/v1/report'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intel submitted successfully!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AdvisoryScreen(isMumbaiToPune: widget.isMumbaiToPune),
            ),
          );
        }
      } else {
        throw Exception('Failed to submit (Status: ${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String locName = kCorridorLocations[widget.nearestLocationId]?['name'] ?? widget.nearestLocationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Intel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reporting for $locName',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report helps keep other commuters safe.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            _buildDropdown(
              label: 'Rainfall',
              value: _rainfall,
              options: ['No Rainfall', 'Low Rainfall', 'Medium', 'High', 'Very High'],
              onChanged: (val) => setState(() => _rainfall = val!),
            ),
            const SizedBox(height: 24),
            _buildDropdown(
              label: 'Visibility',
              value: _visibility,
              options: ['Clear', 'Low'],
              onChanged: (val) => setState(() => _visibility = val!),
            ),
            const SizedBox(height: 24),
            _buildDropdown(
              label: 'Temperature',
              value: _temperature,
              options: ['Low', 'High', 'Very High'],
              onChanged: (val) => setState(() => _temperature = val!),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit & View Advisory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: kCardColor,
              items: options.map((String dropDownStringItem) {
                return DropdownMenuItem<String>(
                  value: dropDownStringItem,
                  child: Text(dropDownStringItem),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
