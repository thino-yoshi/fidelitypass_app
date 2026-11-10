import 'package:flutter/material.dart';
import '../merchant_tokens.dart';
import '../logic/merchant_stats_logic.dart';
import '../../../config/app_colors.dart';
import 'merchant_google_bubble.dart';
import 'merchant_period_toggle.dart';
import 'merchant_kpi_grid.dart';
import 'merchant_retention_card.dart';
import 'merchant_graph_card.dart';
import 'merchant_card_preview.dart';

class MerchantDashboard extends StatelessWidget {
  final Map merchantInfo;
  final Map? stats;
  final List<dynamic> daily;
  final List<dynamic> scanHistory;
  final List<dynamic> recentClients;
  final Map? cardDesign;
  final String period;
  final String graphRange;
  final String retPeriod;
  final bool isPoints;
  final void Function(String) onPeriodChanged;
  final void Function(String) onGraphRangeChanged;
  final void Function(String) onRetPeriodChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onNavigateToCarteEditor;
  final String token;

  const MerchantDashboard({
    super.key,
    required this.merchantInfo,
    required this.stats,
    required this.daily,
    required this.scanHistory,
    required this.recentClients,
    required this.cardDesign,
    required this.period,
    required this.graphRange,
    required this.retPeriod,
    required this.isPoints,
    required this.onPeriodChanged,
    required this.onGraphRangeChanged,
    required this.onRetPeriodChanged,
    required this.onRefresh,
    required this.onNavigateToCarteEditor,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final agg = computePeriodAgg(daily, period);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kPrimary,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            MerchantGoogleBubble(token: token, merchantInfo: merchantInfo),
            const SizedBox(height: 12),
            MerchantPeriodToggle(period: period, onChanged: onPeriodChanged),
            const SizedBox(height: 12),
            MerchantKpiGrid(agg: agg, period: period, isPoints: isPoints),
            const SizedBox(height: 12),
            MerchantRetentionCard(
              scanHistory: scanHistory,
              retPeriod: retPeriod,
              onPeriodChanged: onRetPeriodChanged,
            ),
            const SizedBox(height: 14),
            Center(child: Text('Statistiques générales',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText))),
            const SizedBox(height: 8),
            MerchantGraphCard(
              daily: daily,
              graphRange: graphRange,
              onRangeChanged: onGraphRangeChanged,
              token: token,
              merchantInfo: merchantInfo,
              stats: stats,
              scanHistory: scanHistory,
              recentClients: recentClients,
            ),
            const SizedBox(height: 12),
            MerchantCardPreview(
              cardDesign: cardDesign,
              merchantInfo: merchantInfo,
              onEditTap: onNavigateToCarteEditor,
            ),
          ],
        ),
      )),
    );
  }
}
