import 'package:flutter/material.dart';
import '../data/legal_content.dart';
import '../services/company_service.dart';
import '../services/auth_service.dart';
import 'legal_page_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            _buildSection(
              title: 'Konto',
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  title: const Text('Angemeldet als', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(user.email, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ),
                _buildSettingTile(
                  icon: Icons.logout,
                  title: 'Abmelden',
                  subtitle: 'Von Ihrem Konto abmelden',
                  onTap: _confirmLogout,
                  iconColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          _buildSection(
            title: 'Daten',
            children: [
              _buildSettingTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Unternehmensdaten zurücksetzen',
                subtitle: 'Alle gespeicherten Firmendaten löschen',
                onTap: _confirmResetCompanies,
                iconColor: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Rechtliches',
            children: [
              _buildSettingTile(
                icon: Icons.info_outline,
                title: 'Über ServicePlace',
                subtitle: 'Version 1.0.0',
                onTap: () => _showAboutDialog(),
              ),
              _buildSettingTile(
                icon: Icons.business,
                title: 'Impressum',
                subtitle: 'Angaben gemäß §5 DDG',
                onTap: () => _openLegal(LegalContent.impressum),
              ),
              _buildSettingTile(
                icon: Icons.shield_outlined,
                title: 'Datenschutzerklärung',
                subtitle: 'Informationen gemäß DSGVO',
                onTap: () => _openLegal(LegalContent.datenschutz),
              ),
              _buildSettingTile(
                icon: Icons.description_outlined,
                title: 'Nutzungsbedingungen',
                subtitle: 'Bedingungen für Nutzer',
                onTap: () => _openLegal(LegalContent.nutzungsbedingungen),
              ),
              _buildSettingTile(
                icon: Icons.article_outlined,
                title: 'AGB',
                subtitle: 'Allgemeine Geschäftsbedingungen',
                onTap: () => _openLegal(LegalContent.agb),
              ),
              _buildSettingTile(
                icon: Icons.cookie_outlined,
                title: 'Cookie-Richtlinie',
                subtitle: 'Verwendung von Cookies',
                onTap: () => _openLegal(LegalContent.cookieRichtlinie),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).colorScheme.primary).withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchten Sie sich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              _auth.logout();
              Navigator.pop(ctx);
              setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  void _confirmResetCompanies() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daten zurücksetzen'),
        content: const Text('Möchten Sie wirklich alle gespeicherten Firmendaten löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final service = CompanyService();
              for (final c in service.companies) {
                await service.deleteCompany(c.id);
              }
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alle Daten wurden gelöscht')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Alles löschen'),
          ),
        ],
      ),
    );
  }

  void _openLegal(LegalContent content) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalPageScreen(content: content)),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'ServicePlace',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 ServicePlace',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.store, color: Colors.white, size: 24),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'Finden Sie Geschäfte und Dienstleistungen in Ihrer Nähe. '
          'Registrieren Sie Ihr Unternehmen und erhalten Sie Bewertungen von Kunden.',
        ),
      ],
    );
  }
}
