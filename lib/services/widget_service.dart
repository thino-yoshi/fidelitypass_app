import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidWidgetName = 'com.example.fidelitypass_app.QartaWidgetProvider';

  /// Met à jour le widget avec les données de la première carte disponible.
  static Future<void> updateWidget({
    required String merchantName,
    required int stampsCount,
    required int stampsRequired,
    required String rewardDescription,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_merchant_name', merchantName);
      await HomeWidget.saveWidgetData<int>('widget_stamps_count', stampsCount);
      await HomeWidget.saveWidgetData<int>('widget_stamps_required', stampsRequired);
      await HomeWidget.saveWidgetData<String>('widget_reward_description', rewardDescription);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
    } catch (e) {
      // Widget not installed — silently ignore
    }
  }

  /// Appelé après chaque refresh des cartes client.
  static Future<void> updateFromCards(List<dynamic> cards) async {
    if (cards.isEmpty) return;
    // Prend la première carte (ou la carte avec le plus de tampons)
    final card = cards.reduce((a, b) {
      final sa = (a['stamps_count'] as int? ?? 0);
      final sb = (b['stamps_count'] as int? ?? 0);
      return sa >= sb ? a : b;
    });
    final merchantName = card['merchants']?['business_name'] as String? ?? 'Mon commerce';
    final stampsCount = card['stamps_count'] as int? ?? 0;
    final stampsRequired = card['merchants']?['stamps_required'] as int? ?? 10;
    final rewardDescription = card['merchants']?['reward_description'] as String? ?? 'Récompense';

    await updateWidget(
      merchantName: merchantName,
      stampsCount: stampsCount,
      stampsRequired: stampsRequired,
      rewardDescription: rewardDescription,
    );
  }
}
