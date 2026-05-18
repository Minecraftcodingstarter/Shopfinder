import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../services/auth_service.dart';
import '../services/address_service.dart';
import 'auth_screen.dart';

class MyCompanyScreen extends StatefulWidget {
  const MyCompanyScreen({super.key});

  @override
  State<MyCompanyScreen> createState() => _MyCompanyScreenState();
}

class _MyCompanyScreenState extends State<MyCompanyScreen> {
  final CompanyService _companyService = CompanyService();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _companyService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isLoggedIn) {
      return AuthScreen(onSuccess: () => setState(() {}));
    }

    final companies = _companyService.myCompanies;
    final hasCompany = companies.isNotEmpty;
    final company = hasCompany ? companies.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Unternehmen'),
        actions: [
          if (hasCompany) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Bearbeiten',
              onPressed: () => _showCompanyForm(company: company),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(company!),
            ),
          ],
        ],
      ),
      body: hasCompany ? _buildCompanyView(company!) : _buildEmptyState(),
      floatingActionButton: !hasCompany
          ? FloatingActionButton.extended(
              onPressed: () => _showCompanyForm(),
              icon: const Icon(Icons.add),
              label: const Text('Unternehmen hinzufügen'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_center_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Noch kein Unternehmen registriert',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Füge dein Unternehmen hinzu, damit Kunden es finden und bewerten können.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showCompanyForm(),
              icon: const Icon(Icons.add),
              label: const Text('Unternehmen anlegen'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyView(Company company) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyHeader(company),
            const SizedBox(height: 20),
            _buildStatsRow(company),
            const SizedBox(height: 20),
            _buildDetailSection(company),
            if (company.reviews.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildReviewsSection(company),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader(Company company) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primaryContainer,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        company.category,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (company.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      company.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Company company) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          icon: Icons.star_rounded,
          label: 'Bewertung',
          value: company.reviewCount > 0
              ? company.averageRating.toStringAsFixed(1)
              : '–',
          sub: company.reviewCount > 0
              ? '${company.reviewCount} Bewertungen'
              : 'Noch keine',
          color: Colors.amber,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          icon: Icons.visibility_rounded,
          label: 'Aufrufe',
          value: _formatNumber(company.viewCount),
          sub: 'Profilaufrufe',
          color: theme.colorScheme.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          icon: Icons.calendar_today_rounded,
          label: 'Aktiv seit',
          value: _formatDate(company.createdAt),
          sub: 'Erstellt am',
          color: Colors.green,
        )),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(40), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(Company company) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Unternehmensdetails',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailTile(Icons.location_on_outlined, 'Adresse', company.address),
            if (company.priceLevel != null)
              _buildDetailTile(Icons.attach_money, 'Preisklasse', '${company.priceLevel}  –  ${_priceRangeLabel(company.priceLevel!)}'),
            if (company.phoneNumber.isNotEmpty)
              _buildDetailTile(Icons.phone_outlined, 'Telefon', company.phoneNumber),
            if (company.email.isNotEmpty)
              _buildDetailTile(Icons.email_outlined, 'E-Mail', company.email),
            if (company.website != null && company.website!.isNotEmpty)
              _buildDetailTile(Icons.language_outlined, 'Webseite', company.website!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(Company company) {
    final reviews = company.reviews
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, size: 20, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'Bewertungen (${reviews.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...reviews.map((review) => _buildReviewItem(review)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(CompanyReview review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      _formatDateShort(review.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  )),
                ),
                if (review.comment != null && review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.comment!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _categories = [
    'Restaurant',
    'Supermarkt',
    'Dienstleistung',
    'Einzelhandel',
    'Gesundheit',
    'Freizeit',
    'Sonstiges',
  ];

  static const _priceLevels = [
    '€',
    '€€',
    '€€€',
    '€€€€',
  ];

  String _priceRangeLabel(String priceLevel) {
    switch (priceLevel) {
      case '€':
      case 'Kostenlos':
        return '0\u202f€ – 10\u202f€';
      case '€€':
        return '10\u202f€ – 30\u202f€';
      case '€€€':
        return '30\u202f€ – 60\u202f€';
      case '€€€€':
        return '60\u202f€ +';
      default:
        return priceLevel;
    }
  }

  void _showCompanyForm({Company? company}) {
    final nameCtrl = TextEditingController(text: company?.name ?? '');
    final descCtrl = TextEditingController(text: company?.description ?? '');
    final addressCtrl = TextEditingController(text: company?.address ?? '');
    final phoneCtrl = TextEditingController(text: company?.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: company?.email ?? '');
    final websiteCtrl = TextEditingController(text: company?.website ?? '');
    var selectedCategory = company?.category;
    var selectedPriceLevel = company?.priceLevel;
    var serviceRadius = company?.serviceRadius ?? 0.0;
    final isEditing = company != null;
    final addressService = AddressService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var isSaving = false;
        String? addressError;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(isEditing ? 'Unternehmen bearbeiten' : 'Unternehmen anlegen'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Bitte geben Sie einen Unternehmensnamen ein.')),
                                );
                                return;
                              }
                              if (addressCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Bitte geben Sie eine Adresse ein.')),
                                );
                                return;
                              }
                              if (selectedCategory == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Bitte wählen Sie eine Kategorie aus.')),
                                );
                                return;
                              }
                              if (selectedPriceLevel == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Bitte wählen Sie eine Preisklasse aus.')),
                                );
                                return;
                              }
                              if (phoneCtrl.text.trim().isEmpty && emailCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Bitte geben Sie mindestens Telefon oder E-Mail an.')),
                                );
                                return;
                              }

                              setDialogState(() {
                                isSaving = true;
                                addressError = null;
                              });

                              final result = await addressService.validateAddress(addressCtrl.text.trim());

                              if (!result.isValid) {
                                setDialogState(() {
                                  isSaving = false;
                                  addressError = result.error;
                                });
                                return;
                              }

                              final now = DateTime.now();
                              final userEmail = AuthService().currentUser?.email ?? '';
                              if (isEditing) {
                                company
                                  ..name = nameCtrl.text.trim()
                                  ..description = descCtrl.text.trim()
                                  ..address = result.displayName ?? addressCtrl.text.trim()
                                  ..phoneNumber = phoneCtrl.text.trim()
                                  ..email = emailCtrl.text.trim()
                                  ..website = websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim()
                                  ..category = selectedCategory!
                                  ..priceLevel = selectedPriceLevel!
                                  ..latitude = result.latitude
                                  ..longitude = result.longitude
                                  ..serviceRadius = serviceRadius > 0 ? serviceRadius : null;
                                _companyService.updateCompany(company);
                              } else {
                                final newCompany = Company(
                                  id: 'cmp_${now.millisecondsSinceEpoch}',
                                  userEmail: userEmail,
                                  name: nameCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  address: result.displayName ?? addressCtrl.text.trim(),
                                  phoneNumber: phoneCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
                                  category: selectedCategory!,
                                  priceLevel: selectedPriceLevel!,
                                  latitude: result.latitude,
                                  longitude: result.longitude,
                                  serviceRadius: serviceRadius > 0 ? serviceRadius : null,
                                );
                                _companyService.addCompany(newCompany);
                              }
                              addressService.dispose();
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormField(nameCtrl, 'Unternehmensname *', Icons.business, 'z.B. Müller GmbH'),
                      const SizedBox(height: 16),
                      _buildFormField(descCtrl, 'Beschreibung', Icons.description, 'Kurze Beschreibung Ihres Unternehmens', maxLines: 3),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(addressCtrl, 'Adresse *', Icons.location_on, 'z.B. Musterstraße 12, 10115 Berlin'),
                          if (addressError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      addressError!,
                                      style: const TextStyle(fontSize: 12, color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(phoneCtrl, 'Telefon *', Icons.phone, 'z.B. +49 123 456789', keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildFormField(emailCtrl, 'E-Mail *', Icons.email, 'z.B. info@firma.de', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      Text('* Telefon oder E-Mail ist erforderlich', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                      const SizedBox(height: 16),
                      _buildFormField(websiteCtrl, 'Webseite (optional)', Icons.language, 'z.B. https://firma.de'),
                      const SizedBox(height: 16),
                      // Kategorie Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text('Kategorie *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                              color: Colors.grey[50],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                hint: const Text('Kategorie auswählen'),
                                isExpanded: true,
                                items: _categories.map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                )).toList(),
                                onChanged: (v) => setDialogState(() => selectedCategory = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Preisklasse Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_money, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text('Preisklasse *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                              color: Colors.grey[50],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedPriceLevel,
                                hint: const Text('Preisklasse auswählen'),
                                isExpanded: true,
                                items: _priceLevels.map((pl) => DropdownMenuItem(
                                  value: pl,
                                  child: Text('$pl  –  ${_priceRangeLabel(pl)}'),
                                )).toList(),
                                onChanged: (v) => setDialogState(() => selectedPriceLevel = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.radar, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text('Servicebereich', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceRadius > 0
                                ? 'Im Umkreis von ${serviceRadius.toInt()} km'
                                : 'Nur am Standort (kein Umkreis)',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                          Slider(
                            value: serviceRadius,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: serviceRadius > 0 ? '${serviceRadius.toInt()} km' : 'Nur Standort',
                            onChanged: (v) {
                              setDialogState(() => serviceRadius = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  void _confirmDelete(Company company) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unternehmen löschen'),
        content: Text('Möchten Sie "${company.name}" wirklich löschen? Alle Daten gehen verloren.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              _companyService.deleteCompany(company.id);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unternehmen gelöscht')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
