import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final PageController _carouselController = PageController();
  int _carouselIndex = 0;
  bool _loadingCompanies = false;

  @override
  void initState() {
    super.initState();
    _companyService.initialize();
  }

  Future<void> _ensureMyCompanies() async {
    if (!_auth.isLoggedIn) return;
    setState(() => _loadingCompanies = true);
    await _companyService.fetchMyCompanies();
    if (mounted) setState(() => _loadingCompanies = false);
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isLoggedIn) {
      return AuthScreen(onSuccess: () {
        _ensureMyCompanies();
        setState(() {});
      });
    }

    final companies = _companyService.myCompanies;
    final hasCompany = companies.isNotEmpty;
    final company = hasCompany ? companies.first : null;

    if (_loadingCompanies && !hasCompany) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mein Unternehmen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            if (company.images.isNotEmpty) _buildImageCarousel(company),
            if (company.images.isNotEmpty) const SizedBox(height: 16),
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

  Widget _buildImageCarousel(Company company) {
    final images = company.images;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 800;
    final bool isVeryNarrow = screenWidth < 480;

    // Sehr schmale Bildschirme: nur ein Bild anzeigen.
    if (isVeryNarrow && images.length > 1) {
      return SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTap: () => _openFullscreenGallery(company, 0),
            child: Image.network(
              images[0],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (ctx, err, _) => Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
              ),
            ),
          ),
        ),
      );
    }

    // Auf grossen Bildschirmen: Airbnb-Raster (grosses Bild + 2x2 Grid).
    if (isWide && images.length > 1) {
      final double maxContentWidth = 1100;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: _buildGalleryGrid(company, images, 460),
        ),
      );
    }

    // Mittlere Bildschirme (oder nur 1 Bild): wischbares Karussell mit Pfeilen.
    final canGoPrev = _carouselIndex > 0;
    final canGoNext = _carouselIndex < images.length - 1;

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              child: PageView.builder(
                controller: _carouselController,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _openFullscreenGallery(company, i),
                  child: Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (ctx, err, _) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (images.length > 1 && canGoPrev)
            Positioned(
              left: 4, top: 0, bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38, padding: const EdgeInsets.all(2)),
                  onPressed: () => _carouselController.previousPage(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          if (images.length > 1 && canGoNext)
            Positioned(
              right: 4, top: 0, bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38, padding: const EdgeInsets.all(2)),
                  onPressed: () => _carouselController.nextPage(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _carouselIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _carouselIndex ? Theme.of(context).colorScheme.primary : Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(Company company, List<String> images, double height) {
    const gap = 8.0;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: _galleryTile(company, images, 0),
            ),
            const SizedBox(width: gap),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _galleryTile(company, images, 1)),
                        if (images.length > 2) ...[
                          const SizedBox(width: gap),
                          Expanded(child: _galleryTile(company, images, 2)),
                        ],
                      ],
                    ),
                  ),
                  if (images.length > 3) ...[
                    const SizedBox(height: gap),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _galleryTile(company, images, 3)),
                          if (images.length > 4) ...[
                            const SizedBox(width: gap),
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _galleryTile(company, images, 4),
                                  if (images.length > 5)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () => _openFullscreenGallery(company, 4),
                                        child: Container(
                                          color: Colors.black.withAlpha(110),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '+${images.length - 5}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _galleryTile(Company company, List<String> images, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openFullscreenGallery(company, index),
        child: Image.network(
          images[index],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (ctx, err, _) => Container(
            color: Colors.grey[200],
            child: Center(child: Icon(Icons.broken_image, size: 36, color: Colors.grey[400])),
          ),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }

  void _openFullscreenGallery(Company company, int initialIndex) {
    final controller = PageController(initialPage: initialIndex);
    int current = initialIndex;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isWide = MediaQuery.of(ctx).size.width >= 800;
            final canPrev = current > 0;
            final canNext = current < company.images.length - 1;

            void goPrev() => controller.previousPage(
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            void goNext() => controller.nextPage(
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                title: Text(
                  '${current + 1} / ${company.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              body: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: company.images.length,
                    onPageChanged: (i) => setDialogState(() => current = i),
                    itemBuilder: (ctx, i) => InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          company.images[i],
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, _) => const Icon(
                            Icons.broken_image, size: 64, color: Colors.white24),
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white));
                          },
                        ),
                      ),
                    ),
                  ),
                  if (company.images.length > 1 && canPrev)
                    Positioned(
                      left: isWide ? 24 : 8,
                      child: _galleryArrow(Icons.chevron_left, goPrev),
                    ),
                  if (company.images.length > 1 && canNext)
                    Positioned(
                      right: isWide ? 24 : 8,
                      child: _galleryArrow(Icons.chevron_right, goNext),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Widget _galleryArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(235),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 30, color: Colors.black87),
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
              child: company.logoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(company.logoUrl, fit: BoxFit.cover,
                        width: 64, height: 64,
                        errorBuilder: (_, __, ___) => _buildLetter(company),
                      ),
                    )
                  : _buildLetter(company),
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
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: company.categories.map((cat) => Chip(
                      label: Text(cat, style: const TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    )).toList(),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: _statCardWidth(),
          child: _buildStatCard(
            icon: Icons.star_rounded,
            label: 'Bewertung',
            value: company.reviewCount > 0
                ? company.averageRating.toStringAsFixed(1)
                : '–',
            sub: company.reviewCount > 0
                ? '${company.reviewCount} Bewertungen'
                : 'Noch keine',
            color: Colors.amber,
          ),
        ),
        SizedBox(
          width: _statCardWidth(),
          child: _buildStatCard(
            icon: Icons.visibility_rounded,
            label: 'Aufrufe',
            value: _formatNumber(company.viewCount),
            sub: 'Profilaufrufe',
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(
          width: _statCardWidth(),
          child: _buildStatCard(
            icon: Icons.calendar_today_rounded,
            label: 'Aktiv seit',
            value: _formatDateShort(company.createdAt),
            sub: 'Erstellt am',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  double _statCardWidth() {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return (width - 56) / 3;
    return (width - 56) / 2;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              sub,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
            if (company.serviceRadius != null && company.serviceRadius! > 0)
              _buildDetailTile(Icons.radar, 'Servicebereich', '${company.serviceRadius!.toInt()} km'),
            if (company.isUnlimitedRadius)
              _buildDetailTile(Icons.radar, 'Servicebereich', 'Unbegrenzt'),
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
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: Colors.grey[500]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
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
    var selectedCategories = List<String>.from(company?.categories ?? []);
    var selectedPriceLevel = company?.priceLevel;
    final isEditing = company != null;
    final addressService = AddressService();
    final imagePicker = ImagePicker();

    var currentStep = 0;
    var workLocation = company != null ? ((company.serviceRadius ?? 0) > 0 ? 1 : 0) : 0;
    var serviceRadius = company?.serviceRadius ?? 0.0;
    var isUnlimited = company?.isUnlimitedRadius ?? false;
    var selectedImages = List<String>.from(company?.images ?? []);
    var hideAddress = company?.hideAddress ?? false;
    var hasWhatsapp = company?.hasWhatsapp ?? false;
    var wantsAdvertising = company?.wantsAdvertising ?? false;
    var selectedLogo = company?.logoUrl ?? '';

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
          builder: (ctx, setDialogState) {
            Widget stepIndicator() {
              const labels = ['Arbeitsort', 'Tätigkeit', 'Details'];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: List.generate(labels.length, (i) {
                    final isActive = i == currentStep;
                    final isDone = i < currentStep;
                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (i > 0)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: isDone
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.grey[300],
                                  ),
                                ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone
                                      ? Theme.of(ctx).colorScheme.primary
                                      : isActive
                                          ? Theme.of(ctx).colorScheme.primaryContainer
                                          : Colors.grey[200],
                                ),
                                child: Center(
                                  child: isDone
                                      ? Icon(Icons.check, size: 16, color: Colors.white)
                                      : Text('${i + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Theme.of(ctx).colorScheme.primary
                                                : Colors.grey[600],
                                          )),
                                ),
                              ),
                              if (i < labels.length - 1)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: isDone
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.grey[300],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              color: isActive
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              );
            }

            Widget locationStep() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Wo arbeiten Sie?',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Wählen Sie aus, wie Sie Ihre Dienstleistung anbieten.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  _buildOptionCard(
                    ctx: ctx, icon: Icons.store, title: 'In meinem Geschäft/Büro',
                    subtitle: 'Kunden besuchen mich an meinem Standort',
                    isSelected: workLocation == 0,
                    onTap: () => setDialogState(() {
                      workLocation = 0;
                      serviceRadius = 0.0;
                      isUnlimited = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    ctx: ctx, icon: Icons.directions_car, title: 'Beim Kunden vor Ort',
                    subtitle: 'Ich fahre zu meinen Kunden',
                    isSelected: workLocation == 1,
                    onTap: () => setDialogState(() {
                      workLocation = 1;
                      if (serviceRadius == 0) serviceRadius = 10;
                    }),
                  ),
                  if (workLocation == 1) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.radar, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Servicebereich',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isUnlimited
                                ? 'Unbegrenzter Radius'
                                : 'Im Umkreis von ${serviceRadius.toInt()} km',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            isUnlimited ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                          ),
                          label: const Text('Unbegrenzt'),
                          onPressed: () => setDialogState(() {
                            isUnlimited = !isUnlimited;
                          }),
                        ),
                      ],
                    ),
                    if (!isUnlimited) ...[
                      Slider(
                        value: serviceRadius,
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: '${serviceRadius.toInt()} km',
                        onChanged: (v) => setDialogState(() => serviceRadius = v),
                      ),
                      Text(
                        'Sie werden Kunden im Umkreis von ${serviceRadius.toInt()} km angezeigt.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    ] else
                      Text(
                        'Sie werden allen Kunden in der gesamten Region angezeigt.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                  ],
                ],
              );
            }

            Widget categoryStep() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Was ist Ihre Tätigkeit?',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Wählen Sie eine oder mehrere Kategorien aus.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() {
                          if (isSelected) {
                            selectedCategories.remove(cat);
                          } else {
                            selectedCategories.add(cat);
                          }
                        }),
                        selectedColor: Theme.of(ctx).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(ctx).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  if (selectedCategories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                        const SizedBox(width: 6),
                        Text('${selectedCategories.length} Kategorie${selectedCategories.length != 1 ? 'n' : ''} ausgewählt',
                          style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              );
            }

            Widget detailsStep() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Kontakt & Details',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Geben Sie Ihren Unternehmensnamen und Kontaktdaten ein.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
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
                                child: Text(addressError!,
                                  style: const TextStyle(fontSize: 12, color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(phoneCtrl, 'Telefon (optional)', Icons.phone, 'z.B. +49 123 456789', keyboardType: TextInputType.text),
                  const SizedBox(height: 16),
                  _buildFormField(emailCtrl, 'E-Mail (optional)', Icons.email, 'z.B. info@firma.de', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  Text('Telefon oder E-Mail – mindestens eines erforderlich',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  _buildFormField(websiteCtrl, 'Webseite (optional)', Icons.language, 'z.B. https://firma.de'),
                  const SizedBox(height: 16),
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
                          value: pl, child: Text('$pl  –  ${_priceRangeLabel(pl)}'),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedPriceLevel = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildSwitchTile(
                    ctx: ctx,
                    value: hideAddress,
                    icon: Icons.visibility_off,
                    title: 'Adresse verstecken',
                    subtitle: 'Adresse wird nicht öffentlich angezeigt (z.B. bei Fahrservice)',
                    onChanged: (v) => setDialogState(() => hideAddress = v),
                  ),
                  const Divider(),
                  _buildSwitchTile(
                    ctx: ctx,
                    value: hasWhatsapp,
                    icon: Icons.chat,
                    title: 'WhatsApp Kontakt',
                    subtitle: 'Über WhatsApp erreichbar',
                    onChanged: (v) => setDialogState(() => hasWhatsapp = v),
                  ),
                  const Divider(),
                  _buildSwitchTile(
                    ctx: ctx,
                    value: wantsAdvertising,
                    icon: Icons.campaign,
                    title: 'Werbung buchen',
                    subtitle: 'Ich möchte über Werbemöglichkeiten kontaktiert werden',
                    onChanged: (v) => setDialogState(() => wantsAdvertising = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Bilder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...selectedImages.map((url) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 100, height: 100,
                                  color: Colors.grey[200],
                                  child: Image.network(url, width: 100, height: 100, fit: BoxFit.contain),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => selectedImages.remove(url)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            try {
                              final pickedFiles = await imagePicker.pickMultipleMedia();
                              if (pickedFiles.isNotEmpty) {
                                for (final picked in pickedFiles) {
                                  final mimeType = picked.mimeType;
                                  if (mimeType == null || !mimeType.startsWith('image/')) continue;
                                  final bytes = await picked.readAsBytes();
                                  final b64 = base64Encode(bytes);
                                  final dataUrl = 'data:$mimeType;base64,$b64';
                                  setDialogState(() => selectedImages.add(dataUrl));
                                }
                                if (pickedFiles.every((f) => f.mimeType == null || !f.mimeType!.startsWith('image/'))) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Nur Bilddateien sind erlaubt')),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Fehler beim Laden: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(60),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(ctx).colorScheme.primary.withAlpha(80),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 28,
                                  color: Theme.of(ctx).colorScheme.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hinzufügen',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(ctx).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                      const Spacer(),
                      if (selectedLogo.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Entfernen'),
                          onPressed: () => setDialogState(() => selectedLogo = ''),
                          style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final picked = await imagePicker.pickImage(source: ImageSource.gallery);
                        if (picked == null) return;
                        final mimeType = picked.mimeType;
                        if (mimeType == null || !mimeType.startsWith('image/')) return;
                        final bytes = await picked.readAsBytes();
                        final b64 = base64Encode(bytes);
                        setDialogState(() => selectedLogo = 'data:$mimeType;base64,$b64');
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Fehler: $e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: selectedLogo.isEmpty ? Theme.of(ctx).colorScheme.primaryContainer.withAlpha(60) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedLogo.isEmpty ? Theme.of(ctx).colorScheme.primary.withAlpha(80) : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: selectedLogo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(selectedLogo, fit: BoxFit.cover, width: 100, height: 100),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 28, color: Theme.of(ctx).colorScheme.primary),
                                const SizedBox(height: 4),
                                Text('Logo', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Quadratisches Bild empfohlen (wird im Kreis angezeigt)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                ],
              );
            }

            Widget navigation() {
              final isLast = currentStep == 2;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    if (currentStep > 0)
                      OutlinedButton.icon(
                        onPressed: () => setDialogState(() => currentStep--),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Zurück'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: isSaving ? null : () async {
                        if (currentStep == 0 && workLocation == -1) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte wählen Sie eine Option aus.')),
                          );
                          return;
                        }
                        if (currentStep == 1 && selectedCategories.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte wählen Sie mindestens eine Kategorie aus.')),
                          );
                          return;
                        }
                        if (!isLast) {
                          setDialogState(() => currentStep++);
                          return;
                        }

                        setDialogState(() { isSaving = true; addressError = null; });

                        if (nameCtrl.text.trim().isEmpty) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte geben Sie einen Unternehmensnamen ein.')),
                          );
                          return;
                        }
                        if (addressCtrl.text.trim().isEmpty) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte geben Sie eine Adresse ein.')),
                          );
                          return;
                        }
                        if (workLocation == 1 && serviceRadius <= 0 && !isUnlimited) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte wählen Sie einen Servicebereich aus.')),
                          );
                          return;
                        }
                        if (selectedPriceLevel == null) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte wählen Sie eine Preisklasse aus.')),
                          );
                          return;
                        }
                        if (phoneCtrl.text.trim().isEmpty && emailCtrl.text.trim().isEmpty) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Bitte geben Sie mindestens Telefon oder E-Mail an.')),
                          );
                          return;
                        }

                        double? lat, lng;
                        String resolvedAddress = addressCtrl.text.trim();
                        final result = await addressService.validateAddress(addressCtrl.text.trim());
                        if (!result.isValid) {
                          setDialogState(() { isSaving = false; addressError = result.error; });
                          return;
                        }
                        lat = result.latitude;
                        lng = result.longitude;
                        resolvedAddress = result.displayName ?? addressCtrl.text.trim();

                        final now = DateTime.now();
                        final userEmail = AuthService().currentUser?.email ?? '';
                        final effectiveRadius = workLocation == 1
                            ? (isUnlimited ? -1.0 : serviceRadius)
                            : null;

                        if (isEditing) {
                          company
                            ..name = nameCtrl.text.trim()
                            ..description = descCtrl.text.trim()
                            ..address = resolvedAddress
                            ..phoneNumber = phoneCtrl.text.trim()
                            ..email = emailCtrl.text.trim()
                            ..website = websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim()
                            ..categories = List.from(selectedCategories)
                            ..priceLevel = selectedPriceLevel!
                            ..latitude = lat
                            ..longitude = lng
                            ..serviceRadius = effectiveRadius
                            ..images = List.from(selectedImages)
                            ..hideAddress = hideAddress
                            ..hasWhatsapp = hasWhatsapp
                            ..wantsAdvertising = wantsAdvertising
                            ..logoUrl = selectedLogo;
                          await _companyService.updateCompany(company);
                        } else {
                          final newCompany = Company(
                            id: 'cmp_${now.millisecondsSinceEpoch}',
                            userEmail: userEmail,
                            ownerId: AuthService().currentUser?.uid ?? '',
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            address: resolvedAddress,
                            phoneNumber: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
                            categories: List.from(selectedCategories),
                            priceLevel: selectedPriceLevel!,
                            latitude: lat,
                            longitude: lng,
                            serviceRadius: effectiveRadius,
                            images: List.from(selectedImages),
                            hideAddress: hideAddress,
                            hasWhatsapp: hasWhatsapp,
                            wantsAdvertising: wantsAdvertising,
                            logoUrl: selectedLogo,
                          );
                          await _companyService.addCompany(newCompany);
                        }
                        addressService.dispose();
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                      icon: isLast
                          ? (isSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save))
                          : const Icon(Icons.arrow_forward),
                      label: Text(isLast ? 'Speichern' : 'Weiter'),
                    ),
                  ],
                ),
              );
            }

            final steps = [locationStep(), categoryStep(), detailsStep()];

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.85,
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(isEditing ? 'Unternehmen bearbeiten' : 'Unternehmen anlegen'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  body: Column(
                    children: [
                      stepIndicator(),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: steps[currentStep],
                        ),
                      ),
                      navigation(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionCard({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(ctx).colorScheme.primaryContainer.withAlpha(40)
              : Colors.grey[50],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(ctx).colorScheme.primary.withAlpha(20)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.grey[600]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.black87,
                    )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildLetter(Company company) {
    return Center(
      child: Text(
        company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      ),
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

  Widget _buildSwitchTile({
    required BuildContext ctx,
    required bool value,
    required IconData icon,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: Theme.of(ctx).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
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
            onPressed: () async {
              await _companyService.deleteCompany(company.id);
              if (ctx.mounted) Navigator.pop(ctx);
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

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
