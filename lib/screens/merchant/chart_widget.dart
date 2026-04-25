import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../config/api.dart';
import '../../config/app_colors.dart';

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
  String _period = '30j';

  static const blue   = Color(0xFF2C7BE5);
  static const purple = Color(0xFFA78BFA);

  Color get _kWhite  => context.cSurface;
  Color get _kBorder => context.cBorder;
  Color get _kText   => context.cText;
  Color get _kSub    => context.cSub;

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

  List<dynamic> get _filtered {
    final d = dailyStats;
    if (_period == '7j') return d.take(7).toList().reversed.toList();
    if (_period == '30j') return d.take(30).toList().reversed.toList();
    return d.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text("Évolution de l'activité",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kText)),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          // Period switcher
          Row(
            children: ['7j', '30j', '3m'].map((p) => GestureDetector(
              onTap: () => setState(() => _period = p),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _period == p ? blue : _kWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _period == p ? blue : _kBorder),
                ),
                child: Text(p, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: _period == p ? Colors.white : _kSub,
                )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: CircularProgressIndicator(color: blue),
            ))
          else if (_filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune donnée sur cette période',
                    style: TextStyle(color: _kSub, fontSize: 13)),
              ),
            )
          else
            _buildLineChart(),

          if (!loading && _filtered.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _legend(blue, 'Tampons'),
                const SizedBox(width: 12),
                _legend(purple, 'Scans'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final data = _filtered;
    final maxVal = data.map((e) => (e['scans'] as int? ?? 0)).fold(0, (a, b) => a > b ? a : b).toDouble();
    final maxY = (maxVal < 5 ? 5 : maxVal + 2).toDouble();

    final stampSpots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), ((e.value['scans'] as int? ?? 0) * 1.4).roundToDouble())
    ).toList();

    final scanSpots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['scans'] as int? ?? 0).toDouble())
    ).toList();

    final labels = List<String>.filled(data.length, '');
    final indices = <int>{0, data.length ~/ 2, data.length - 1};
    for (final i in indices) {
      if (i < 0 || i >= data.length) continue;
      final raw = data[i]['date'] as String? ?? '';
      if (raw.isNotEmpty) {
        try {
          final dt = DateTime.parse(raw);
          labels[i] = '${dt.day}/${dt.month}';
        } catch (_) {}
      }
    }

    final chartMaxY = (maxY * 1.4 + 2).toDouble();
    final gridColor = _kBorder;
    final labelColor = _kSub;

    return ClipRect(
      child: SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            minY: 0, maxY: chartMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= labels.length || labels[i].isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(labels[i], style: TextStyle(fontSize: 8, color: labelColor)),
                  );
                },
                reservedSize: 20,
              )),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: stampSpots,
                isCurved: true,
                color: blue,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [blue.withOpacity(0.2), blue.withOpacity(0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              LineChartBarData(
                spots: scanSpots,
                isCurved: true,
                color: purple,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [purple.withOpacity(0.15), purple.withOpacity(0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 9, color: _kSub)),
      ],
    );
  }
}
