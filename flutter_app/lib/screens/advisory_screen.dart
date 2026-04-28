import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class AdvisoryScreen extends StatefulWidget {
  final bool isMumbaiToPune;

  const AdvisoryScreen({super.key, required this.isMumbaiToPune});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  Map<String, dynamic>? _corridorData;
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchCorridorData();
  }

  Future<void> _fetchCorridorData() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/api/v1/corridor'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _corridorData = jsonDecode(res.body);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load data (Status: ${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Advisory'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { _isLoading = true; _errorMsg = ''; });
              _fetchCorridorData();
            },
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg.isNotEmpty) {
      return Center(child: Text('Error: $_errorMsg', textAlign: TextAlign.center));
    }

    final waypoints = _corridorData?['waypoints'] as List<dynamic>? ?? [];
    final overallStatus = _corridorData?['overall_status'] ?? 'Status Unknown';

    // Calculate Overall Score (The lowest score along the route determines safety)
    int overallScore = 100;
    String detailedReason = 'All clear.';
    String worstLocationName = '';
    
    if (waypoints.isNotEmpty) {
      var worstWaypoint = waypoints.reduce((curr, next) => (curr['score'] as num) < (next['score'] as num) ? curr : next);
      overallScore = (worstWaypoint['score'] as num).toInt();
      detailedReason = worstWaypoint['detailed_status'] ?? 'No specific details.';
      worstLocationName = worstWaypoint['name'] ?? 'Unknown';
    }

    // Determine Theme Color based on Score
    Color themeColor = Colors.redAccent;
    IconData statusIcon = Icons.warning_rounded;
    if (overallScore >= 80) {
      themeColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_outline;
      detailedReason = 'Conditions are excellent across the entire route.';
    } else if (overallScore >= 40) {
      themeColor = Colors.orangeAccent;
      statusIcon = Icons.info_outline;
    }

    String directionText = widget.isMumbaiToPune ? 'MUMBAI → PUNE' : 'PUNE → MUMBAI';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Direction Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                directionText,
                style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

            const SizedBox(height: 64),

            // Massive Score Display with Glow
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.15),
                        blurRadius: 60,
                        spreadRadius: 20,
                      )
                    ],
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds),
                
                // Inner Circle
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCardColor,
                    border: Border.all(color: themeColor.withOpacity(0.5), width: 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('OVERALL\nSAFENESS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text(
                        '$overallScore',
                        style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: themeColor, height: 1),
                      ),
                      const SizedBox(height: 4),
                      const Text('/ 100', style: TextStyle(color: Colors.white30, fontSize: 16)),
                    ],
                  ),
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              ],
            ),

            const SizedBox(height: 64),

            // Status Message Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: themeColor, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          overallStatus,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  const Text('Route Conditions Breakdown', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    'The lowest score detected was near $worstLocationName ($overallScore/100).\nReason: $detailedReason',
                    style: const TextStyle(color: Colors.white54, height: 1.5),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 24),
            
            const Text(
              'This score is a real-time blend of Machine Learning predictions, live OpenWeather API data, and crowdsourced Trust Engine reports.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 40),

            // Subtle About Us Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Column(
                children: [
                  Text('About Us', style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1)),
                  SizedBox(height: 12),
                  Text('Prarambh', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('prarambh.n@somaiya.edu', style: TextStyle(color: Colors.white30, fontSize: 11)),
                  SizedBox(height: 8),
                  Text('Devansh', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('shashdevansh@somaiya.edu', style: TextStyle(color: Colors.white30, fontSize: 11)),
                  SizedBox(height: 8),
                  Text('Meet', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('meet.sangani@somaiya.edu', style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
