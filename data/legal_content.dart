class LegalSection {
  final String heading;
  final String content;
  const LegalSection({required this.heading, required this.content});
}

class LegalContent {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalContent({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  static const impressum = LegalContent(
    title: 'Impressum',
    lastUpdated: '30.05.2026',
    sections: [
      LegalSection(
        heading: 'Hinweis',
        content: 'Hierbei handelt es sich um einen Platzhalter. Bitte ersetzen Sie diese Angaben durch Ihre tatsächlichen Geschäftsdaten und lassen Sie diese von einem Rechtsanwalt prüfen.',
      ),
      LegalSection(
        heading: 'Angaben gemäß §5 DDG',
        content: '[Name des Betreibers]\n[Straße und Hausnummer]\n[PLZ Ort]',
      ),
      LegalSection(
        heading: 'Kontakt',
        content: 'Telefon: [Telefonnummer]\nE-Mail: [E-Mail-Adresse]',
      ),
      LegalSection(
        heading: 'Vertreten durch',
        content: '[Name des/der Geschäftsführer/Vorstand]',
      ),
    ],
  );

  static const datenschutz = LegalContent(
    title: 'Datenschutzerklärung',
    lastUpdated: '30.05.2026',
    sections: [
      LegalSection(
        heading: 'Hinweis',
        content: 'Dies ist ein Platzhalter-Text. Bitte ersetzen Sie diese Angaben durch Ihre tatsächlichen Daten und lassen Sie diese von einem Rechtsanwalt prüfen.',
      ),
      LegalSection(
        heading: '1. Verantwortlicher',
        content: '[Name des Betreibers]\n[Straße und Hausnummer]\n[PLZ Ort]\n\nE-Mail: [E-Mail-Adresse]\nTelefon: [Telefonnummer]',
      ),
      LegalSection(
        heading: '2. Überblick über die Verarbeitungen',
        content: 'Die folgende Übersicht fasst die Arten der verarbeiteten Daten und die Zwecke ihrer Verarbeitung zusammen.',
      ),
      LegalSection(
        heading: '3. Arten der verarbeiteten Daten',
        content: '• Bestandsdaten (z. B. Namen, Adressen)\n• Kontaktdaten (z. B. E-Mail, Telefonnummern)\n• Inhaltsdaten (z. B. Texteingaben, Fotografien)\n• Nutzungsdaten (z. B. besuchte Seiten, Zugriffszeiten)\n• Meta-/Kommunikationsdaten (z. B. Geräte-Informationen, IP-Adressen)\n• Standortdaten (z. B. GPS-Daten)\n• Bewertungsdaten (z. B. Sternebewertungen und Textrezensionen)',
      ),
      LegalSection(
        heading: '4. Zwecke der Verarbeitung',
        content: '• Bereitstellung der App und Website\n• Suche nach Dienstleistungen in der Nähe\n• Registrierung und Verwaltung von Benutzerkonten\n• Registrierung und Verwaltung von Unternehmenseinträgen\n• Veröffentlichung und Verwaltung von Bewertungen\n• Kommunikation mit Nutzern\n• Sicherheitsmaßnahmen und Missbrauchsbekämpfung',
      ),
      LegalSection(
        heading: '5. Rechtsgrundlagen der Verarbeitung',
        content: '• **Einwilligung (Art. 6 Abs. 1 lit. a DSGVO)** – für Standortdaten, Cookies und Analyse\n• **Vertragserfüllung (Art. 6 Abs. 1 lit. b DSGVO)** – für die Erbringung der Plattformdienste\n• **Rechtliche Verpflichtung (Art. 6 Abs. 1 lit. c DSGVO)** – für gesetzliche Aufbewahrungspflichten\n• **Berechtigte Interessen (Art. 6 Abs. 1 lit. f DSGVO)** – für Sicherheitsmaßnahmen',
      ),
      LegalSection(
        heading: '6. Registrierung und Nutzerkonto',
        content: 'Für bestimmte Funktionen ist eine Registrierung erforderlich. Erhoben werden:\n• E-Mail-Adresse\n• Passwort (verschlüsselt)\n• Name (optional)\n• Telefonnummer (bei Anmeldung per Telefon)',
      ),
      LegalSection(
        heading: '7. Google Sign-In',
        content: 'Bei Anmeldung mit Google erhalten wir Ihren Namen und Ihre E-Mail-Adresse. Mehr unter: https://policies.google.com/privacy',
      ),
      LegalSection(
        heading: '8. Standortdaten',
        content: 'Standortdaten werden nur mit Ihrer Einwilligung verarbeitet und nicht dauerhaft gespeichert. Sie können die Standortfreigabe jederzeit deaktivieren.',
      ),
      LegalSection(
        heading: '9. Firebase',
        content: 'Wir nutzen Firebase (Google LLC) für Authentifizierung und Hosting. Firebase kann Daten in die USA übermitteln (EU-US Data Privacy Framework). Mehr: https://firebase.google.com/support/privacy',
      ),
      LegalSection(
        heading: '10. Kartendienste',
        content: 'Wir verwenden Google Maps und OpenStreetMap. Dabei können IP-Adresse, Standortdaten und Suchanfragen an die Anbieter übermittelt werden.',
      ),
      LegalSection(
        heading: '11. KI-Funktionen',
        content: 'Für erweiterte Suchfunktionen nutzen wir KI-Dienste wie Google Gemini und Grok (xAI). Mehr:\n• https://support.google.com/gemini/\n• https://x.ai/legal/privacy',
      ),
      LegalSection(
        heading: '12. Speicherdauer',
        content: 'Daten werden gelöscht, sobald sie nicht mehr benötigt werden, sofern keine gesetzlichen Aufbewahrungspflichten entgegenstehen.',
      ),
      LegalSection(
        heading: '13. Ihre Rechte (DSGVO)',
        content: 'Sie haben das Recht auf Auskunft (Art. 15), Berichtigung (Art. 16), Löschung (Art. 17), Einschränkung (Art. 18), Datenübertragbarkeit (Art. 20), Widerspruch (Art. 21) sowie Beschwerde bei einer Aufsichtsbehörde (Art. 77).',
      ),
      LegalSection(
        heading: '14. Kontakt',
        content: 'Bei Fragen: [E-Mail-Adresse]',
      ),
    ],
  );

  static const nutzungsbedingungen = LegalContent(
    title: 'Nutzungsbedingungen',
    lastUpdated: '30.05.2026',
    sections: [
      LegalSection(
        heading: 'Hinweis',
        content: 'Dies ist ein Platzhalter-Text. Bitte ersetzen Sie diese Angaben durch Ihre tatsächlichen Daten und lassen Sie diese von einem Rechtsanwalt prüfen.',
      ),
      LegalSection(
        heading: '1. Geltungsbereich',
        content: 'Diese Nutzungsbedingungen regeln das Verhältnis zwischen dem Betreiber von ServicePlace (nachfolgend "Betreiber") und den Nutzern der App und der Website (nachfolgend "Nutzer").',
      ),
      LegalSection(
        heading: '2. Leistungsbeschreibung',
        content: 'ServicePlace ist eine Plattform zur Suche nach Geschäften, Dienstleistungen und Restaurants in der Nähe mit:\n• Kartenbasierter Suche\n• Detailansichten zu Unternehmen\n• Bewertungs- und Rezensionssystem\n• Registrierung und Verwaltung von Unternehmenseinträgen',
      ),
      LegalSection(
        heading: '3. Registrierung und Benutzerkonto',
        content: 'Der Nutzer ist verpflichtet, wahrheitsgemäße Angaben zu machen und die Vertraulichkeit seiner Zugangsdaten zu wahren. Es besteht kein Anspruch auf Registrierung.',
      ),
      LegalSection(
        heading: '4. Pflichten der Nutzer',
        content: 'Der Nutzer verpflichtet sich, keine rechtswidrigen, beleidigenden oder irreführenden Inhalte zu veröffentlichen, keine automatisierten Systeme zu verwenden und keine falschen Bewertungen abzugeben. Bei Verstößen kann das Konto gesperrt oder gelöscht werden.',
      ),
      LegalSection(
        heading: '5. Bewertungen',
        content: 'Bewertungen müssen auf tatsächlichen Erfahrungen beruhen. Gefälschte Bewertungen sind verboten. Nutzer können Bewertungen als unangemessen melden.',
      ),
      LegalSection(
        heading: '6. Haftung',
        content: 'Der Betreiber haftet unbeschränkt für Vorsatz, grobe Fahrlässigkeit sowie für Verletzung von Leben, Körper und Gesundheit. Für einfache Fahrlässigkeit nur bei Verletzung wesentlicher Vertragspflichten.',
      ),
      LegalSection(
        heading: '7. Kündigung und Löschung',
        content: 'Der Nutzer kann sein Konto jederzeit löschen. Der Betreiber kann das Konto bei Verstoß gegen diese Bedingungen mit sofortiger Wirkung sperren oder löschen.',
      ),
      LegalSection(
        heading: '8. Schlussbestimmungen',
        content: 'Es gilt das Recht der Bundesrepublik Deutschland.',
      ),
    ],
  );

  static const agb = LegalContent(
    title: 'Allgemeine Geschäftsbedingungen für Unternehmen',
    lastUpdated: '30.05.2026',
    sections: [
      LegalSection(
        heading: 'Hinweis',
        content: 'Dies ist ein Platzhalter-Text. Bitte ersetzen Sie diese Angaben durch Ihre tatsächlichen Daten und lassen Sie diese von einem Rechtsanwalt prüfen.',
      ),
      LegalSection(
        heading: '1. Geltungsbereich',
        content: 'Diese AGB gelten für alle Verträge zwischen dem Betreiber von ServicePlace und Unternehmen, die einen Eintrag auf der Plattform erstellen.',
      ),
      LegalSection(
        heading: '2. Vertragsgegenstand',
        content: 'Der Betreiber stellt eine Plattform zur Präsentation von Unternehmen mit Kontaktdaten, Beschreibungen, Bildern und weiteren Informationen bereit. Die grundlegende Listung ist kostenlos.',
      ),
      LegalSection(
        heading: '3. Pflichten des Unternehmens',
        content: 'Das Unternehmen verpflichtet sich, wahrheitsgemäße und aktuelle Informationen bereitzustellen, keine irreführenden Angaben zu machen und geltende Gesetze einzuhalten.',
      ),
      LegalSection(
        heading: '4. Bewertungen',
        content: 'Das Unternehmen kann auf Bewertungen antworten. Der Betreiber ist berechtigt, Bewertungen bei Verstoß gegen diese AGB zu löschen.',
      ),
      LegalSection(
        heading: '5. Haftung',
        content: 'Der Betreiber haftet unbeschränkt für Vorsatz, grobe Fahrlässigkeit sowie für Verletzung von Leben, Körper und Gesundheit. Für einfache Fahrlässigkeit nur bei Verletzung wesentlicher Vertragspflichten.',
      ),
      LegalSection(
        heading: '6. Kündigung',
        content: 'Der Vertrag läuft auf unbestimmte Zeit. Das Unternehmen kann den Eintrag jederzeit löschen. Der Betreiber kann den Eintrag bei Verstoß gegen diese AGB mit sofortiger Wirkung löschen.',
      ),
      LegalSection(
        heading: '7. Schlussbestimmungen',
        content: 'Es gilt das Recht der Bundesrepublik Deutschland.',
      ),
    ],
  );

  static const cookieRichtlinie = LegalContent(
    title: 'Cookie-Richtlinie',
    lastUpdated: '30.05.2026',
    sections: [
      LegalSection(
        heading: 'Hinweis',
        content: 'Dies ist ein Platzhalter-Text. Bitte ersetzen Sie diese Angaben durch Ihre tatsächlichen Daten und lassen Sie diese von einem Rechtsanwalt prüfen.',
      ),
      LegalSection(
        heading: '1. Was sind Cookies?',
        content: 'Cookies sind kleine Textdateien, die auf Ihrem Gerät gespeichert werden, wenn Sie eine Website besuchen oder eine App nutzen.',
      ),
      LegalSection(
        heading: '2. Welche Cookies verwenden wir?',
        content: '**Notwendige Cookies:** Für den Betrieb der App erforderlich (Authentifizierung, Navigation).\n\n**Drittanbieter-Cookies:** Durch Firebase, Google Maps und Google Sign-In können Cookies von Google LLC gesetzt werden.',
      ),
      LegalSection(
        heading: '3. Verwaltung',
        content: 'Sie können Cookies in Ihren Browser-Einstellungen verwalten. Bei Deaktivierung können bestimmte Funktionen eingeschränkt sein.',
      ),
      LegalSection(
        heading: '4. Kontakt',
        content: 'Bei Fragen: [E-Mail-Adresse]',
      ),
    ],
  );

  static final List<LegalContent> all = [
    impressum,
    datenschutz,
    nutzungsbedingungen,
    agb,
    cookieRichtlinie,
  ];
}
