import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;
  final Map? merchantInfo;
  const NotificationsScreen({super.key, required this.token, this.merchantInfo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  bool sending = false;
  String? feedback;
  static const blue = Color(0xFF2C7BE5);

  final List<Map<String, String>> templates = [
    {'title': '🎁 Offre spéciale', 'message': 'Profitez de notre offre du jour ! Venez nous rendre visite.'},
    {'title': '⭐ Double tampons', 'message': 'Aujourd\'hui seulement : chaque achat rapporte 2 tampons !'},
    {'title': '🎉 Nouveau menu', 'message': 'Découvrez nos nouveautés du moment. On vous attend !'},
    {'title': '🏆 Récompense disponible', 'message': 'Vous êtes proche de votre récompense, plus qu\'un peu !'},
  ];

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> sendNotification() async {
    if (titleController.text.isEmpty || messageController.text.isEmpty) return;
    setState(() { sending = true; feedback = null; });

    try {
      final res = await http.post(
        Uri.parse('$apiUrl/notifications/send'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': titleController.text,
          'message': messageController.text,
        }),
      );

      if (res.statusCode == 200) {
        setState(() => feedback = '✅ Notification envoyée !');
        titleController.clear();
        messageController.clear();
      } else {
        setState(() => feedback = '❌ Erreur lors de l\'envoi');
      }
    } catch (e) {
      setState(() => feedback = '❌ Erreur : $e');
    } finally {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Templates
          const Text('Templates rapides',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1828))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: templates.map((t) => GestureDetector(
              onTap: () {
                titleController.text = t['title']!;
                messageController.text = t['message']!;
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: blue.withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(t['title']!,
                      style: TextStyle(color: blue, fontWeight: FontWeight.w700, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),

          // Formulaire
          const Text('Message personnalisé',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1828))),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Titre',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sending ? null : sendNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: sending
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('🔔 Envoyer à tous mes clients',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),

          // Feedback
          if (feedback != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feedback!.contains('✅') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(feedback!,
                style: TextStyle(
                  color: feedback!.contains('✅') ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}