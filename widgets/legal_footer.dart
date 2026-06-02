import 'package:flutter/material.dart';
import '../data/legal_content.dart';
import '../screens/legal_page_screen.dart';

class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Text(
            'ServicePlace © ${DateTime.now().year}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _link(context, 'Impressum', LegalContent.impressum),
              Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              _link(context, 'Datenschutz', LegalContent.datenschutz),
              Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              _link(context, 'Nutzungsbedingungen', LegalContent.nutzungsbedingungen),
              Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              _link(context, 'AGB', LegalContent.agb),
              Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              _link(context, 'Cookies', LegalContent.cookieRichtlinie),
            ],
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, String label, LegalContent content) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalPageScreen(content: content)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
