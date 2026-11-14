/// Mode démo : utilisé UNIQUEMENT par l'aperçu design (lib/main_preview_client.dart).
/// Dans l'appli normale, [enabled] reste toujours à false et rien ne change.
///
/// Quand il est actif, aucun appel serveur n'est fait pour le QR, le scan ou
/// les récompenses : on simule un tampon, un scan ou une validation pour voir
/// les écrans et les animations dans le simulateur.
class QartaDemo {
  static bool enabled = false;

  /// Réponse simulée d'un scan de QR commerçant (carte + commerce).
  static Map<String, dynamic> Function()? fakeJoin;
}
