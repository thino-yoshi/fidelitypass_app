import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../config/api.dart';

class StatsChartWidget extends StatefulWidget {
  final String token;
  final Color accentColor;

  const StatsChartWidget({super.key, required this.token, required this.accentColor});

  @override
  State<StatsChartWidget> createState() => _StatsChartWidgetState();
}

class _StatsChartWidgetState extends State<StatsChartWidget> {
  List<dynamic> dailyStats = [];
  bool loading = true;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/stats/daily'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() { dailyStats = jsonDecode(res.body); loading = false; });
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => exporting = true);
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/cards/export-csv'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/clients.csv');
        await file.writeAsBytes(res.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Liste de mes clients');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'export')));
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  int get _maxScans {
    if (dailyStats.isEmpty) return 1;
    return dailyStats.map((d) => d['scans'] as int).reduce((a, b) => a > b ? a : b).clamp(1, 9999);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE9E3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scans — 30 derniers jours',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1828))),
              GestureDetector(
                onTap: exporting ? null : _exportCsv,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: exporting
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: widget.accentColor))
                      : Row(
                          children: [
                            Icon(Icons.download_rounded, size: 14, color: widget.accentColor),
                            const SizedBox(width: 4),
                            Text('Export CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.accentColor)),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: CircularProgressIndicator(color: Color(0xFF2C7BE5)),
            ))
          else if (dailyStats.isEmpty || _maxScans == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucun scan sur les 30 derniers jours',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_maxScans * 1.3).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = dailyStats[group.x];
                        final date = (d['date'] as String).substring(5); // MM-DD
                        return BarTooltipItem(
                          '$date\n${rod.toY.round()} scan${rod.toY > 1 ? 's' : ''}',
                          TextStyle(color: widget.accentColor, fontWeight: FontWeight.w700, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          // Afficher seulement tous les 7 jours
                          if (i % 7 != 0) return const SizedBox.shrink();
                          final d = dailyStats[i]['date'] as String;
                          return Text(d.substring(5), style: TextStyle(color: Colors.grey[400], fontSize: 9));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFF4F2EE), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: dailyStats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    final scans = (d['scans'] as int).toDouble();
                    final rewards = (d['rewards'] as int).toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: scans,
                          color: widget.accentColor.withOpacity(0.8),
                          width: 6,
                          borderRadius: BorderRadius.circular(3),
                          rodStackItems: rewards > 0 ? [
                            BarChartRodStackItem(0, rewards, const Color(0xFFFBBF24).withOpacity(0.9)),
                          ] : [],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

          if (!loading && _maxScans > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _legend(widget.accentColor, 'Scans'),
                const SizedBox(width: 16),
                _legend(const Color(0xFFFBBF24), 'Récompenses'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }
}
