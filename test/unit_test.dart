import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelitypass_app/services/auth_service.dart';

void main() {
  group('AuthService.networkErrorMessage', () {
    test('SocketException → message pas de connexion', () {
      final msg = AuthService.networkErrorMessage(
        const SocketException('Connection refused'),
      );
      expect(msg, 'Pas de connexion internet.');
    });

    test('HttpException → message erreur serveur', () {
      final msg = AuthService.networkErrorMessage(
        const HttpException('404'),
      );
      expect(msg, 'Erreur serveur. Réessayez.');
    });

    test('TimeoutException → message timeout', () {
      final msg = AuthService.networkErrorMessage(
        Exception('TimeoutException after 10s'),
      );
      expect(msg, 'Le serveur met trop de temps à répondre.');
    });

    test('Erreur inconnue → message générique', () {
      final msg = AuthService.networkErrorMessage(
        Exception('Unexpected error'),
      );
      expect(msg, 'Erreur réseau. Réessayez.');
    });
  });
}
