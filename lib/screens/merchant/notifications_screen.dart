import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  bool editMode = false;
  static const blue = Color(0xFF2C7BE5);

  List<Map<String, String>> templates = [
    {'title': '🎁 Offre spéciale', 'message': 'Profitez de notre offre du jour ! Venez nous rendre visite.'},
    {'title': '⭐ Double tampons', 'message': 'Aujourd\'hui seulement : chaque achat rapporte 2 tampons !'},
    {'title': '🎉 Nouveau menu', 'message': 'Découvrez nos nouveautés du moment. On vous attend !'},
    {'title': '🏆 Récompense disponible', 'message': 'Vous êtes proche de votre récompense, plus qu\'un peu !'},
  ];

  @override
  void initState() {
    super.initState();
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('notif_templates');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      setState(() {
        templates = list.map((e) => Map<String, String>.from(e)).toList();
      });
    }
  }

  Future<void> saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_templates', jsonEncode(templates));
  }

  void addTemplate() {
    if (titleController.text.isEmpty || messageController.text.isEmpty) {
      setState(() => feedback = '⚠️ Remplis le titre et le message d\'abord');
      return;
    }
    setState(() {
      templates.add({
        'title': titleController.text,
        'message': messageController.text,
      });
      feedback = '✅ Template ajouté !';
      titleController.clear();
      messageController.clear();
    });
    saveTemplates();
  }

  void deleteTemplate(int index) {
    setState(() => templates.removeAt(index));
    saveTemplates();
  }

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

          // ── Header templates ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Templates rapides',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1828))),
              GestureDetector(
                onTap: () => setState(() => editMode = !editMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: editMode ? Colors.red.withOpacity(0.1) : blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    editMode ? '✅ Terminer' : '✏️ Modifier',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: editMode ? Colors.red : blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Grille templates ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: templates.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: editMode ? null : () {
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
                  ),
                  if (editMode)
                    Positioned(
                      top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () => deleteTemplate(i),
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Message personnalisé ──
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

                // ── Boutons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: addTemplate,
                        icon: const Text('➕', style: TextStyle(fontSize: 13)),
                        label: const Text('Ajouter template',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          side: const BorderSide(color: blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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

          // ── Feedback ──
          if (feedback != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feedback!.contains('✅') ? Colors.green.withOpacity(0.1) :
                feedback!.contains('⚠️') ? Colors.orange.withOpacity(0.1) :
                Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(feedback!,
                style: TextStyle(
                  color: feedback!.contains('✅') ? Colors.green[700] :
                  feedback!.contains('⚠️') ? Colors.orange[700] :
                  Colors.red[700],
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