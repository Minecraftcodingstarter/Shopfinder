import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_model.dart';
import '../models/shop_model.dart';
import '../services/company_service.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Shop shop;
  final Company company;

  const CompanyDetailScreen({
    super.key,
    required this.shop,
    required this.company,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  int _currentImageIndex = 0;
  Company _company = Company(id: '', name: '', address: '', userEmail: '');
  bool _loadingReviews = true;
  final PageController _pageController = PageController();

  Shop get shop => widget.shop;
  Company get company => _company;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _company = widget.company;
    _loadFullCompany();
  }

  Future<void> _loadFullCompany() async {
    final full = await CompanyService().fetchCompanyById(widget.company.id);
    if (full != null && mounted) {
      setState(() {
        _company = full;
        _loadingReviews = false;
      });
    } else if (mounted) {
      setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareCompany,
          ),
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.red),
            onPressed: _showReportDialog,
            tooltip: 'Melden',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageCarousel(),
            _buildHeaderSection(),
            const Divider(height: 1),
            _buildInfoSection(),
            const Divider(height: 1),
            _buildDescriptionSection(),
            const Divider(height: 1),
            _buildContactSection(),
            if (!_loadingReviews) ...[
              const Divider(height: 1),
              _buildReviewsSection(),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showReportDialog,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(60)),
                    color: Colors.red.withAlpha(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.red[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Dieses Unternehmen melden',
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500, fontSize: 14)),
                      ),
                      Icon(Icons.chevron_right, color: Colors.red[400], size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyLetter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.store, size: 64, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
        const SizedBox(height: 12),
        Text(shop.name[0].toUpperCase(),
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary.withAlpha(80)),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    if (company.images.isEmpty) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Center(
          child: company.logoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(company.logoUrl, width: 100, height: 100, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildEmptyLetter(),
                  ),
                )
              : _buildEmptyLetter(),
        ),
      );
    }

    final canGoPrev = _currentImageIndex > 0;
    final canGoNext = _currentImageIndex < company.images.length - 1;

    return Stack(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            itemCount: company.images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (ctx, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey[200],
                child: Image.network(
                company.images[i],
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, _) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                  ),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey[100],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ),
        ),
        ),
        if (company.images.length > 1 && canGoPrev)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, size: 32, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  padding: const EdgeInsets.all(4),
                ),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        if (company.images.length > 1 && canGoNext)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 32, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  padding: const EdgeInsets.all(4),
                ),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        if (company.images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(company.images.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentImageIndex ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentImageIndex ? Theme.of(context).colorScheme.primary : Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Eingetragen',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: company.categories.map((cat) => Chip(
              label: Text(cat, style: const TextStyle(fontSize: 12)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )).toList(),
          ),
            const SizedBox(height: 8),
          if (company.logoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipOval(
                child: Image.network(company.logoUrl, width: 64, height: 64, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (shop.rating != null) ...[
            Row(
              children: [
                ...List.generate(5, (i) => Icon(
                  i < shop.rating!.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                )),
                const SizedBox(width: 6),
                Text(
                  shop.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (shop.userRatingsTotal != null && shop.userRatingsTotal! > 0)
                  Text(
                    ' (${shop.userRatingsTotal})',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (shop.distance != null)
            Row(
              children: [
                Icon(Icons.near_me, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${(shop.distance! / 1000).toStringAsFixed(1)} km entfernt',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (!company.hideAddress)
            _infoTile(Icons.location_on_outlined, 'Adresse', shop.address),
          if (company.hideAddress && company.isDelivery)
            _infoTile(Icons.directions_car_outlined, 'Service', 'Beim Kunden vor Ort'),
          if (company.priceLevel != null)
            _infoTile(Icons.attach_money, 'Preisklasse',
                '${company.priceLevel}  –  ${_priceRangeLabel(company.priceLevel!)}'),
          if (company.isUnlimitedRadius)
            _infoTile(Icons.radar, 'Liefergebiet', 'Unbegrenzt (gesamte Region)')
          else if (company.serviceRadius != null && company.serviceRadius! > 0)
            _infoTile(Icons.radar, 'Liefergebiet', '${company.serviceRadius!.toInt()} km Umkreis'),
          if (company.viewCount > 0)
            _infoTile(Icons.visibility_outlined, 'Profilaufrufe', '${company.viewCount}'),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 10),
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

  Widget _buildDescriptionSection() {
    if (shop.description == null || shop.description!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Beschreibung', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            shop.description!,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final hasPhone = shop.phoneNumber != null && shop.phoneNumber!.isNotEmpty;
    final hasEmail = shop.email != null && shop.email!.isNotEmpty;
    final hasWebsite = shop.website != null && shop.website!.isNotEmpty;

    if (!hasPhone && !hasEmail && !hasWebsite && !company.wantsAdvertising) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kontakt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (hasPhone)
            _contactTile(Icons.phone_outlined, shop.phoneNumber!, () => _launchUrl('tel:${shop.phoneNumber!}')),
          if (hasEmail)
            _contactTile(Icons.email_outlined, shop.email!, () => _launchUrl('mailto:${shop.email!}')),
          if (hasWebsite)
            _contactTile(Icons.language_outlined, shop.website!, () => _launchUrl(shop.website!)),
          if (hasPhone && company.hasWhatsapp) ...[
            const SizedBox(height: 8),
            _contactTile(Icons.chat_outlined, 'WhatsApp', () => _launchUrl('https://wa.me/${shop.phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '')}')),
          ],
          if (company.wantsAdvertising) ...[
            const SizedBox(height: 8),
            _contactTile(Icons.campaign_outlined, 'Werbung buchen', () {}),
          ],
        ],
      ),
    );
  }

  Widget _contactTile(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 15)),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final isLoggedIn = AuthService().isLoggedIn;

    if (company.reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, size: 20, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'Bewertungen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Bewertungen vorhanden.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            if (isLoggedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text('Bewertung schreiben'),
                onPressed: _showWriteReviewDialog,
              ),
            ],
          ],
        ),
      );
    }

    final sorted = List<CompanyReview>.from(company.reviews)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text(
                'Bewertungen (${sorted.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isLoggedIn)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Bewerten'),
                  onPressed: _showWriteReviewDialog,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...sorted.map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            _formatDateShort(review.timestamp),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < review.rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        )),
                      ),
                      if (review.comment != null && review.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(review.comment!, style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showWriteReviewDialog() {
    int rating = 5;
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Bewertung schreiben',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Deine Bewertung'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () => setDialogState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Kommentar (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Bewertung absenden'),
                    onPressed: () => _submitReview(rating, commentController.text.trim(), ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview(int rating, String comment, BuildContext sheetContext) async {
    final id = DateTime.now().toIso8601String() + Random().nextInt(99999).toString();
    final review = CompanyReview(
      id: id,
      companyId: company.id,
      userName: AuthService().currentUser?.name ?? 'Unbekannt',
      rating: rating.toDouble(),
      comment: comment.isNotEmpty ? comment : null,
      timestamp: DateTime.now(),
    );

    await CompanyService().addReview(company.id, review);
    Navigator.pop(sheetContext);
    await _loadFullCompany();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bewertung wurde gespeichert!')),
      );
    }
  }

  void _showReportDialog() {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unternehmen melden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warum möchtest du "${shop.name}" melden?',
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Grund der Meldung (z.B. falsche Informationen, unangemessene Inhalte)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              _submitReport(reasonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Melden'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      final email = AuthService().currentUser?.email ?? '';
      await BackendService().post('/api/reports/companies/${company.id}/report', body: {
        'reason': reason,
        'reporterEmail': email,
      }, auth: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meldung eingegangen. Wir werden uns darum kümmern.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Senden: $e')),
        );
      }
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showContactMenu(context),
              icon: const Icon(Icons.chat),
              label: const Text('Kontaktieren'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToShop(),
              icon: const Icon(Icons.navigation),
              label: const Text('Route'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactMenu(BuildContext context) {
    final hasPhone = shop.phoneNumber != null && shop.phoneNumber!.isNotEmpty;
    final hasEmail = shop.email != null && shop.email!.isNotEmpty;
    final whatsappNumber = shop.phoneNumber?.replaceAll(RegExp(r'[^\d+]'), '');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text('Kontaktieren', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(shop.name, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 20),
              if (hasPhone && company.hasWhatsapp) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat, color: Colors.green),
                  ),
                  title: const Text('WhatsApp'),
                  subtitle: const Text('Sofortige Nachricht senden'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchUrl('https://wa.me/$whatsappNumber');
                  },
                ),
                const Divider(indent: 72, endIndent: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone, color: Colors.blue),
                  ),
                  title: const Text('Anrufen'),
                  subtitle: Text(shop.phoneNumber!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchUrl('tel:${shop.phoneNumber!}');
                  },
                ),
              ],
              if (hasPhone && hasEmail) const Divider(indent: 72, endIndent: 16),
              if (hasEmail) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.email, color: Colors.orange),
                  ),
                  title: const Text('E-Mail'),
                  subtitle: Text(shop.email!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchUrl('mailto:${shop.email!}');
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _navigateToShop() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _shareCompany() {
    final text = '${shop.name}\n${shop.address}\n'
        '${shop.phoneNumber != null ? "Tel: ${shop.phoneNumber}\n" : ""}'
        '${shop.email != null ? "Email: ${shop.email}\n" : ""}'
        'https://www.google.com/maps?q=${shop.latitude},${shop.longitude}';
    // In a real app, use share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Teilen: $text')),
    );
  }

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

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
