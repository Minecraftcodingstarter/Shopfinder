import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shop_model.dart';
import '../models/app_state.dart';
import '../models/company_model.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../services/company_service.dart';
import '../services/service_marketplace.dart';
import '../widgets/shop_card.dart';
import 'company_detail_screen.dart';

enum _SearchMode { delivery, pickup }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AppState _appState = AppState();
  final PlacesService _placesService = PlacesService();
  final GeminiService _geminiService = GeminiService();
  final LocationService _locationService = LocationService();
  final CompanyService _companyService = CompanyService();
  final ServiceMarketplace _marketplace = ServiceMarketplace();

  _SearchMode _searchMode = _SearchMode.pickup;
  double _radius = 5000;
  String _sortBy = 'quality';
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int _autoExpandCount = 0;
  List<Shop> _results = [];
  final MapController _mapController = MapController();
  int? _hoveredIndex;
  Shop? _selectedShop;

  String? _selectedCategory;

  static const _categories = [
    'Alle',
    'Restaurant',
    'Supermarkt',
    'Dienstleistung',
    'Einzelhandel',
    'Gesundheit',
    'Freizeit',
    'Sonstiges',
  ];

  String _getCategory(Shop shop) {
    final name = shop.name.toLowerCase();
    final types = shop.types.map((t) => t.toLowerCase());
    final tags = shop.tags.map((t) => t.toLowerCase());
    final cuisine = shop.cuisine?.toLowerCase() ?? '';
    final all = [...types, ...tags, name, cuisine].join(' ');

    if (types.contains('company')) {
      if (_selectedCategory != null && tags.contains(_selectedCategory!.toLowerCase())) {
        return _selectedCategory!;
      }
      return tags.isNotEmpty ? tags.first : 'Eingetragen';
    }
    if (types.contains('service')) {
      return 'Dienstleistung';
    }
    if (all.contains('restaurant') || all.contains('gastronomie') || all.contains('imbiss')
        || all.contains('cafe') || all.contains('bistro') || all.contains('fast food')
        || all.contains('pizza') || all.contains('döner') || all.contains('currywurst')
        || cuisine.contains('italian') || cuisine.contains('asian') || cuisine.contains('mexican')
        || cuisine.contains('indian') || cuisine.contains('türkisch') || cuisine.contains('deutsch')) {
      return 'Restaurant';
    }
    if (all.contains('supermarkt') || all.contains('supermarket') || all.contains('lebensmittel')
        || all.contains('laden') || all.contains('markt') || all.contains('bäckerei')
        || all.contains('baker') || all.contains('konditorei') || all.contains('fleischerei')
        || all.contains('getränke') || all.contains('biomarkt')) {
      return 'Supermarkt';
    }
    if (all.contains('friseur') || all.contains('hairdresser') || all.contains('kosmetik')
        || all.contains('nail') || all.contains('nagel') || all.contains('massage')
        || all.contains('wäscherei') || all.contains('reinigung') || all.contains('schneiderei')
        || all.contains('reparatur') || all.contains('handwerk') || all.contains('dienstleistung')) {
      return 'Dienstleistung';
    }
    if (all.contains('kleidung') || all.contains('mode') || all.contains('bekleidung')
        || all.contains('schuh') || all.contains('accessoires') || all.contains('geschenk')
        || all.contains('buchhandlung') || all.contains('bücher') || all.contains('spielzeug')
        || all.contains('elektronik') || all.contains('möbel') || all.contains('blumen')
        || all.contains('schmuck') || all.contains('optician') || all.contains('optiker')) {
      return 'Einzelhandel';
    }
    if (all.contains('apotheke') || all.contains('pharmacy') || all.contains('arzt')
        || all.contains('zahnarzt') || all.contains('klinik') || all.contains('physiotherapie')
        || all.contains('gesundheit') || all.contains('heilpraktiker')) {
      return 'Gesundheit';
    }
    if (all.contains('kino') || all.contains('museum') || all.contains('park')
        || all.contains('spielplatz') || all.contains('sport') || all.contains('fitness')
        || all.contains('bibliothek') || all.contains('galerie') || all.contains('freizeit')) {
      return 'Freizeit';
    }
    return 'Sonstiges';
  }

  List<Shop> get _filteredResults {
    if (_selectedCategory == null || _selectedCategory == 'Alle') return _results;
    return _results.where((s) => _getCategory(s) == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _companyService.initialize();
    _locationService.requestPermission().then((granted) {
      debugPrint('Location permission granted: $granted');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
      _autoExpandCount = 0;
    });

    try {
      var position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      position ??= _locationService.getDefaultPosition();

      _appState.currentLatitude = position.latitude;
      _appState.currentLongitude = position.longitude;

      await _searchWithRadius(_radius);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Fehler bei der Suche: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _searchWithRadius(double radius) async {
    if (_appState.currentLatitude == null || _appState.currentLongitude == null) {
      _appState.currentLatitude = LocationService.defaultLat;
      _appState.currentLongitude = LocationService.defaultLng;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _appState.searchRadius = radius;
    });

    try {
      String keyword = _searchController.text.trim();
      final latitude = _appState.currentLatitude!;
      final longitude = _appState.currentLongitude!;

      // Unternehmen aus dem Backend holen
      var matchedCompanies = _companyService.companies
          .where((c) => keyword.isEmpty ||
              c.name.toLowerCase().contains(keyword.toLowerCase()) ||
              c.categories.any((cat) => cat.toLowerCase().contains(keyword.toLowerCase())) ||
              c.address.toLowerCase().contains(keyword.toLowerCase()));

      if (_searchMode == _SearchMode.delivery) {
        final deliveryCompanies = matchedCompanies.where((c) {
          if (c.serviceRadius == null) return false;
          if (c.serviceRadius! < 0) return true;
          if (c.latitude == null || c.longitude == null) return false;
          final distance = LocationService.calculateDistance(
            latitude, longitude, c.latitude!, c.longitude!,
          );
          return distance <= c.serviceRadius! * 1000;
        }).toList();

        final deliveryShops = deliveryCompanies.map(_convertCompanyToShop).toList();
        for (final shop in deliveryShops) {
          if (shop.priceLevel == null) {
            shop.priceLevel = _estimatePriceLevel(shop);
          }
        }

        if (!mounted) return;
        if (deliveryShops.isEmpty) {
          setState(() {
            _errorMessage = 'Keine Unternehmen gefunden, die zu Ihnen kommen können.';
            _results = [];
            _isSearching = false;
          });
          return;
        }
        setState(() {
          _results = deliveryShops;
          _isSearching = false;
        });
        return;
      }

      final companyShops = matchedCompanies
          .where((c) => c.serviceRadius == null || c.serviceRadius! < 0 ||
              c.serviceRadius! <= 0 ||
              (c.latitude != null && c.longitude != null &&
               LocationService.calculateDistance(
                 latitude, longitude, c.latitude!, c.longitude!,
               ) <= (c.serviceRadius! * 1000)))
          .map(_convertCompanyToShop)
          .toList();

      if (keyword.isEmpty) {
        final iosmResults = await _placesService.getPopularShops(latitude, longitude);
        final geminiPopular = await _geminiService.searchShops(
          query: 'Beliebte Läden Restaurants Supermärkte',
          latitude: latitude,
          longitude: longitude,
          radius: radius,
        );

        final enrichedNearby = iosmResults.map((shop) {
          if (shop.priceLevel != null && shop.rating != null) return shop;
          final match = geminiPopular.where((g) =>
            g.name.toLowerCase().contains(shop.name.substring(0, min(shop.name.length, 4)).toLowerCase()) ||
            shop.name.toLowerCase().contains(g.name.substring(0, min(g.name.length, 4)).toLowerCase())
          ).firstOrNull;
          if (match == null) return shop;
          return Shop(id: shop.id, name: shop.name, address: shop.address,
            latitude: shop.latitude, longitude: shop.longitude,
            rating: shop.rating ?? match.rating,
            userRatingsTotal: shop.userRatingsTotal ?? match.userRatingsTotal,
            phoneNumber: shop.phoneNumber, email: shop.email, website: shop.website,
            types: shop.types, photoReference: shop.photoReference,
            distance: shop.distance,
            priceLevel: shop.priceLevel ?? match.priceLevel,
            openingHours: shop.openingHours, isOpen: shop.isOpen,
            description: shop.description ?? match.description,
            tags: shop.tags, cuisine: shop.cuisine,
            imageUrl: shop.imageUrl, facebook: shop.facebook,
            instagram: shop.instagram, rawData: shop.rawData,
          );
        }).toList();

        final resultsWithPrices = [...companyShops, ...enrichedNearby, ...geminiPopular];
        for (final shop in resultsWithPrices) {
          if (shop.priceLevel == null) {
            shop.priceLevel = _estimatePriceLevel(shop);
          }
        }

        setState(() {
          _results = resultsWithPrices;
          _isSearching = false;
        });
        return;
      }

      final results = await _placesService.searchNearbyShops(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        keyword: keyword,
      );
      final geminiFuture = _geminiService.searchShops(
        query: keyword,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );
      final geminiResults = await geminiFuture;
      final serviceResults = _marketplace
          .searchServices(query: keyword)
          .map(_convertServiceToShop)
          .toList();

      final combinedResults = [
        ...companyShops,
        ...results,
        ...geminiResults,
        ...serviceResults,
      ];

      final uniqueResults = <String>{};
      final mergedResults = combinedResults.where((shop) {
        final key = '${shop.name}|${shop.latitude}|${shop.longitude}';
        return uniqueResults.add(key);
      }).toList();

      final enriched = mergedResults.map((shop) {
        if (shop.priceLevel != null && shop.rating != null) return shop;
        final geminiMatch = geminiResults.where((g) =>
          g.name.toLowerCase().contains(shop.name.substring(0, min(shop.name.length, 4)).toLowerCase()) ||
          shop.name.toLowerCase().contains(g.name.substring(0, min(g.name.length, 4)).toLowerCase())
        ).firstOrNull;
        if (geminiMatch == null) return shop;
        return Shop(
          id: shop.id,
          name: shop.name,
          address: shop.address,
          latitude: shop.latitude,
          longitude: shop.longitude,
          rating: shop.rating ?? geminiMatch.rating,
          userRatingsTotal: shop.userRatingsTotal ?? geminiMatch.userRatingsTotal,
          phoneNumber: shop.phoneNumber,
          email: shop.email,
          website: shop.website,
          types: shop.types,
          photoReference: shop.photoReference,
          distance: shop.distance,
          priceLevel: shop.priceLevel ?? geminiMatch.priceLevel,
          openingHours: shop.openingHours,
          isOpen: shop.isOpen,
          description: shop.description ?? geminiMatch.description,
          tags: shop.tags,
          cuisine: shop.cuisine,
          imageUrl: shop.imageUrl,
          facebook: shop.facebook,
          instagram: shop.instagram,
          rawData: shop.rawData,
        );
      }).toList();

      for (final shop in enriched) {
        if (shop.priceLevel == null) {
          shop.priceLevel = _estimatePriceLevel(shop);
        }
      }

      if (!mounted) return;
      if (mergedResults.isEmpty && _autoExpandCount < 3) {
        _autoExpandCount++;
        await _searchWithRadius(radius * 2);
        return;
      }

      if (mergedResults.isEmpty && _autoExpandCount >= 3) {
        setState(() {
          _errorMessage = 'Keine Ergebnisse gefunden, auch nicht in erweitertem Radius.';
          _results = [];
          _isSearching = false;
        });
        return;
      }

      _appState.addToHistory(_searchController.text.trim());
      _appState.searchResults = enriched;
      _appState.setSortBy(_sortBy);
      _results = enriched;

      setState(() {
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Netzwerkfehler: $e';
        _isSearching = false;
      });
    }
  }

  Shop _convertCompanyToShop(Company c) {
    final distance = (c.latitude != null && c.longitude != null &&
            _appState.currentLatitude != null && _appState.currentLongitude != null)
        ? LocationService.calculateDistance(
            _appState.currentLatitude!,
            _appState.currentLongitude!,
            c.latitude!,
            c.longitude!,
          )
        : null;

    return Shop(
      id: c.id,
      name: c.name,
      address: c.hideAddress ? '(Adresse nicht öffentlich)' : c.address,
      logoUrl: c.logoUrl.isNotEmpty ? c.logoUrl : null,
      latitude: c.latitude ?? _appState.currentLatitude ?? LocationService.defaultLat,
      longitude: c.longitude ?? _appState.currentLongitude ?? LocationService.defaultLng,
      rating: c.reviewCount > 0 ? c.averageRating : null,
      userRatingsTotal: c.reviewCount,
      phoneNumber: c.phoneNumber.isNotEmpty ? c.phoneNumber : null,
      email: c.email.isNotEmpty ? c.email : null,
      website: c.website,
      types: ['company'],
      photoReference: null,
      distance: distance,
      priceLevel: c.priceLevel,
      openingHours: null,
      isOpen: null,
      description: c.description.isNotEmpty ? c.description : null,
      tags: c.categories,
      fromDb: true,
    );
  }

  Widget _buildLetterIcon(Shop shop, bool isCompany) {
    return Center(
      child: Text(
        shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isCompany ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Shop _convertServiceToShop(Service service) {
    return Shop(
      id: service.id,
      name: service.title,
      address: service.location,
      latitude: service.latitude ?? _appState.currentLatitude ?? LocationService.defaultLat,
      longitude: service.longitude ?? _appState.currentLongitude ?? LocationService.defaultLng,
      rating: service.rating,
      userRatingsTotal: null,
      phoneNumber: service.providerPhone,
      website: null,
      types: ['service'],
      photoReference: null,
      distance: null,
      priceLevel: null,
      openingHours: null,
      isOpen: null,
    );
  }

  void _onSortChanged(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      _appState.setSortBy(sortBy);
      _results = List.from(_appState.filteredResults);
    });
  }

  double _getMapHeight() {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 380;
    if (width >= 600) return 300;
    return 220;
  }

  Widget _buildResultMap() {
    final center = LatLng(
      _appState.currentLatitude ?? LocationService.defaultLat,
      _appState.currentLongitude ?? LocationService.defaultLng,
    );

    final markers = <Marker>[
      Marker(
        point: center,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.my_location, color: Colors.white, size: 18),
          ),
        ),
      ),
      ..._results.asMap().entries.map((entry) => _buildShopMarker(entry.key, entry.value)),
    ];

    return SizedBox(
      height: _getMapHeight(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onTap: (tapPosition, point) {
              setState(() {
                _selectedShop = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.nearby_shop_finder',
            ),
            MarkerLayer(markers: markers),
            CircleLayer(
              circles: [
                if (_searchMode == _SearchMode.pickup)
                  CircleMarker(
                    point: center,
                    radius: _radius,
                    useRadiusInMeter: true,
                    color: Theme.of(context).colorScheme.primary.withAlpha(30),
                    borderColor: Theme.of(context).colorScheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ..._results.where((s) => s.types.contains('company')).map((s) {
                  final company = _companyService.getCompany(s.id);
                  if (company == null || company.serviceRadius == null || company.serviceRadius! <= 0) return null;
                  return CircleMarker(
                    point: LatLng(company.latitude ?? s.latitude, company.longitude ?? s.longitude),
                    radius: company.serviceRadius! * 1000,
                    useRadiusInMeter: true,
                    color: Theme.of(context).colorScheme.secondary.withAlpha(20),
                    borderColor: Theme.of(context).colorScheme.secondary.withAlpha(80),
                    borderStrokeWidth: 2,
                  );
                }).whereType<CircleMarker>(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildShopMarker(int index, Shop shop) {
    final isHovered = _hoveredIndex == index;
    final isSelected = _selectedShop?.id == shop.id;
    final isCompany = shop.types.contains('company');
    final letter = shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?';
    final size = (isHovered || isSelected) ? 36.0 : 28.0;
    final bgColor = isCompany
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.primary;

    return Marker(
      point: LatLng(shop.latitude, shop.longitude),
      width: size + 12,
      height: size + 12,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedShop = shop;
          });
          _showShopDetails(shop);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size + 8,
          height: size + 8,
          decoration: BoxDecoration(
            color: isHovered || isSelected ? bgColor : bgColor.withAlpha(200),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: (isHovered || isSelected) ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: bgColor.withAlpha(100),
                blurRadius: (isHovered || isSelected) ? 8 : 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: shop.logoUrl != null
              ? ClipOval(
                  child: Image.network(shop.logoUrl!, fit: BoxFit.cover,
                    width: size, height: size,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(letter, style: TextStyle(color: Colors.white,
                        fontSize: (isHovered || isSelected) ? 18 : 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              : Center(
                  child: Text(letter, style: TextStyle(color: Colors.white,
                    fontSize: (isHovered || isSelected) ? 18 : 14, fontWeight: FontWeight.bold)),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ServicePlace'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: _performSearch,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildModeToggle(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 16),
            if (_searchMode == _SearchMode.pickup) _buildRadiusSlider(),
            if (_searchMode == _SearchMode.pickup) const SizedBox(height: 8),
            _buildSortDropdown(),
            const SizedBox(height: 4),
            _buildCategoryFilter(),
            const SizedBox(height: 12),
            if (_searchController.text.trim().isEmpty && _results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Beliebt in Ihrer Nähe',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            if (!_hasSearched)
              Expanded(child: _buildSearchPrompt())
            else if (_isSearching)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorWidget()
            else
              Expanded(
                child: Column(
                  children: [
                    _buildResultMap(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildResultsList()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _searchMode = _SearchMode.pickup;
                  _results = [];
                  _hasSearched = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _searchMode == _SearchMode.pickup
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 18,
                      color: _searchMode == _SearchMode.pickup
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ich gehe zum Geschäft',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _searchMode == _SearchMode.pickup
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _searchMode = _SearchMode.delivery;
                  _results = [];
                  _hasSearched = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _searchMode == _SearchMode.delivery
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 18,
                      color: _searchMode == _SearchMode.delivery
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sie kommen zu mir',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _searchMode == _SearchMode.delivery
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Suche nach Geschäften, Restaurants...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _performSearch(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _performSearch,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Suchradius', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatRadius(_radius),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _radius,
          min: 500,
          max: 50000,
          divisions: 99,
          label: _formatRadius(_radius),
          onChanged: (value) {
            setState(() => _radius = value);
          },
          onChangeEnd: (value) {
            _performSearch();
          },
        ),
      ],
    );
  }

  String _formatRadius(double radius) {
    if (radius >= 1000) {
      return '${(radius / 1000).toStringAsFixed(0)} km';
    }
    return '${radius.toInt()} m';
  }

  Widget _buildSortDropdown() {
    return Row(
      children: [
        Icon(Icons.sort, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        const Text('Sortieren:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            value: _sortBy,
            isExpanded: true,
            underline: const SizedBox(),
            onChanged: (value) => _onSortChanged(value!),
            items: const [
              DropdownMenuItem(value: 'quality', child: Text('Gesamtbewertung')),
              DropdownMenuItem(value: 'rating', child: Text('Bewertung')),
              DropdownMenuItem(value: 'price', child: Text('Preis (günstigste)')),
              DropdownMenuItem(value: 'popularity', child: Text('Beliebtheit')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat || (cat == 'Alle' && _selectedCategory == null);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat, style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
              )),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = cat == 'Alle' ? null : cat;
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              backgroundColor: Colors.grey[100],
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsList() {
    final filtered = _filteredResults;

    if (filtered.isEmpty && _searchController.text.trim().isNotEmpty && _results.isEmpty) {
      return _buildEmptyState(Icons.search_off, 'Keine Ergebnisse', 'Versuchen Sie einen anderen Suchbegriff.');
    }

    if (filtered.isEmpty && _results.isEmpty) {
      return _buildEmptyState(Icons.store_outlined, 'Keine Läden in der Nähe', 'Erhöhen Sie den Suchradius oder versuchen Sie es später erneut.');
    }

    if (filtered.isEmpty && _results.isNotEmpty) {
      return _buildEmptyState(Icons.filter_alt_off, 'Keine Treffer für diesen Filter', 'Versuchen Sie eine andere Kategorie.');
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final shop = filtered[index];
        return MouseRegion(
          onEnter: (_) {
            setState(() {
              _hoveredIndex = index;
            });
          },
          onExit: (_) {
            setState(() {
              _hoveredIndex = null;
            });
          },
          child: ShopCard(
            shop: shop,
            isSelected: _selectedShop?.id == shop.id,
            isHovered: _hoveredIndex == index,
            onTap: () {
              setState(() {
                _selectedShop = shop;
              });
              _showShopDetails(shop);
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search, size: 48, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          ),
          const SizedBox(height: 24),
          Text(
            'Suche nach einem Laden',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'um hier die Ergebnisse zu sehen',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              if (_searchController.text.trim().isNotEmpty) {
                _performSearch();
              }
            },
            icon: const Icon(Icons.trending_up),
            label: const Text('Beliebte Läden in der Nähe anzeigen'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _performSearch,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enrichShopIfNeeded(Shop shop) async {
    if (shop.types.contains('company') || shop.types.contains('service')) return;

    // For Gemini/AI shops: generate short description on tap only
    if (shop.types.contains('gemini')) {
      if (shop.description != null) return;
      final desc = await _geminiService.generateShortDescription(shop.name, shop.address);
      if (!mounted || desc == null) return;
      setState(() {
        final idx = _results.indexWhere((r) => r.id == shop.id);
        if (idx < 0) return;
        final old = _results[idx];
        _results[idx] = Shop(
          id: old.id, name: old.name, address: old.address,
          latitude: old.latitude, longitude: old.longitude,
          rating: old.rating, userRatingsTotal: old.userRatingsTotal,
          phoneNumber: old.phoneNumber, email: old.email, website: old.website,
          types: old.types, photoReference: old.photoReference,
          distance: old.distance, priceLevel: old.priceLevel,
          openingHours: old.openingHours, isOpen: old.isOpen,
          description: desc, tags: old.tags, cuisine: old.cuisine,
          imageUrl: old.imageUrl, facebook: old.facebook,
          instagram: old.instagram, rawData: old.rawData,
        );
      });
      return;
    }

    if (shop.priceLevel != null && shop.rating != null && shop.description != null) return;
    final data = await _geminiService.enrichShopInfo(shop.name, shop.address);
    if (!mounted) return;
    final priceLevel = data['priceLevel']?.toString();
    final rating = double.tryParse(data['rating']?.toString() ?? '');
    final priceInfo = data['priceInfo']?.toString();
    final reviewSummary = data['reviewSummary']?.toString();
    setState(() {
      final idx = _results.indexWhere((r) => r.id == shop.id);
      if (idx < 0) return;
      final old = _results[idx];
      _results[idx] = Shop(
        id: old.id, name: old.name, address: old.address,
        latitude: old.latitude, longitude: old.longitude,
        rating: old.rating ?? rating,
        userRatingsTotal: old.userRatingsTotal,
        phoneNumber: old.phoneNumber, email: old.email, website: old.website,
        types: old.types, photoReference: old.photoReference,
        distance: old.distance,
        priceLevel: old.priceLevel ?? priceLevel ?? _estimatePriceLevel(old),
        openingHours: old.openingHours, isOpen: old.isOpen,
        description: [
          if (priceInfo != null) priceInfo,
          if (reviewSummary != null) reviewSummary,
          if (old.description != null) old.description!,
        ].join(' - '),
        tags: old.tags, cuisine: old.cuisine,
        imageUrl: old.imageUrl, facebook: old.facebook,
        instagram: old.instagram, rawData: old.rawData,
      );
    });
  }

  String _estimatePriceLevel(Shop shop) {
    final types = shop.types.map((t) => t.toLowerCase());
    final name = shop.name.toLowerCase();
    final all = [...types, name];

    if (all.any((t) => t.contains('supermarkt') || t.contains('discount') || t.contains('lidl')
        || t.contains('aldi') || t.contains('netto') || t.contains('rewe')
        || t.contains('tankstelle') || t.contains('fast food') || t.contains('imbiss')
        || t.contains('mc donald') || t.contains('burger king') || t.contains('döner')
        || t.contains('bäckerei') || t.contains('street food'))) {
      return '€';
    }
    if (all.any((t) => t.contains('restaurant') || t.contains('cafe') || t.contains('bistro')
        || t.contains('friseur') || t.contains('kiosk') || t.contains('apotheke')
        || t.contains('buchhandlung') || t.contains('kleidung') || t.contains('mode'))) {
      return '€€';
    }
    if (all.any((t) => t.contains('feinkost') || t.contains('fine dining') || t.contains('hotel')
        || t.contains('weinhandlung') || t.contains('schmuck') || t.contains('fitness'))) {
      return '€€€';
    }
    if (all.any((t) => t.contains('luxury') || t.contains('designer') || t.contains('exklusiv'))) {
      return '€€€€';
    }
    return '€€';
  }

  void _showShopDetails(Shop shop) {
    final isCompany = shop.types.contains('company');
    _companyService.recordView(isCompany ? shop.id : 'external_${shop.id}');
    final isFromCompanyService = isCompany && _companyService.getCompany(shop.id) != null;
    _enrichShopIfNeeded(shop);

    if (isCompany && isFromCompanyService) {
      final company = _companyService.getCompany(shop.id)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDetailScreen(shop: shop, company: company),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isCompany
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: shop.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(shop.logoUrl!, fit: BoxFit.cover,
                                width: 56, height: 56,
                                errorBuilder: (_, __, ___) => _buildLetterIcon(shop, isCompany),
                              ),
                            )
                          : _buildLetterIcon(shop, isCompany),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
                              ),
                              if (isCompany)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          const SizedBox(height: 4),
                          if (shop.rating != null)
                            _buildRatingRow(
                              shop.rating!,
                              shop.userRatingsTotal,
                              sourceLabel: isCompany ? 'App' : _getRatingSource(shop),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                if (shop.description != null && shop.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      shop.description!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                if (shop.address.isNotEmpty) _buildInfoRow(Icons.location_on, shop.address),
                if (shop.phoneNumber != null) _buildInfoRow(Icons.phone, shop.phoneNumber!),
                if (shop.email != null) _buildInfoRow(Icons.email, shop.email!),
                if (shop.website != null) _buildInfoRow(Icons.link, shop.website!),
                _buildInfoRow(
                  Icons.attach_money,
                  shop.priceLevel != null
                      ? shop.fromDb
                          ? _priceRangeLabel(shop.priceLevel!)
                          : '${_priceRangeLabel(shop.priceLevel!)} (geschätzt)'
                      : 'Keine Preisangabe',
                ),
                if (shop.distance != null)
                  _buildInfoRow(Icons.directions_car,
                      '${(shop.distance! / 1000).toStringAsFixed(1)} km entfernt'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _navigateToShop(shop),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Route öffnen (Maps)'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getRatingSource(Shop shop) {
    if (shop.types.contains('company')) return '';
    if (shop.types.contains('gemini')) return 'KI';
    if (shop.types.contains('service')) return 'Service';
    if (shop.rating != null) return 'Google';
    return '';
  }

  Widget _buildRatingRow(double rating, int? total, {String sourceLabel = ''}) {
    return Row(
      children: [
        ...List.generate(5, (i) => Icon(
          i < rating.round() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        )),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        if (total != null && total > 0)
          Text(
            ' ($total)',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        if (sourceLabel.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sourceLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToShop(Shop shop) async {
    final currentLat = _appState.currentLatitude ?? _locationService.currentPosition?.latitude ?? LocationService.defaultLat;
    final currentLng = _appState.currentLongitude ?? _locationService.currentPosition?.longitude ?? LocationService.defaultLng;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLng&destination=${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _priceRangeLabel(String priceLevel) {
    switch (priceLevel) {
      case '€':
      case 'Kostenlos':
        return '0€ – 10€';
      case '€€':
        return '10€ – 30€';
      case '€€€':
        return '30€ – 60€';
      case '€€€€':
        return '60€+';
      default:
        return priceLevel;
    }
  }

  Widget _buildReviewsSection(String companyId) {
    final company = _companyService.getCompany(companyId);
    if (company == null || company.reviews.isEmpty) return const SizedBox.shrink();
    final reviews = company.reviews
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, size: 20, color: Colors.amber[700]),
            const SizedBox(width: 8),
            Text(
              'Bewertungen (${reviews.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.map((review) => Padding(
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
    );
  }

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }

  void _showReviewDialog(String companyId, String companyName) {
    final nameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    double selectedRating = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber[700], size: 22),
              const SizedBox(width: 8),
              const Text('Bewertung abgeben'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ihr Name *',
                      hintText: 'z.B. Max Mustermann',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Bewertung *', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starIdx = i + 1;
                      return IconButton(
                        icon: Icon(
                          starIdx <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = starIdx.toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Kommentar (optional)',
                      hintText: 'Ihre Erfahrungen teilen...',
                      prefixIcon: Icon(Icons.comment_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Bitte geben Sie Ihren Namen ein.')),
                  );
                  return;
                }
                final review = CompanyReview(
                  id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
                  companyId: companyId,
                  userName: nameCtrl.text.trim(),
                  rating: selectedRating,
                  comment: commentCtrl.text.trim().isNotEmpty ? commentCtrl.text.trim() : null,
                  timestamp: DateTime.now(),
                );
                await _companyService.addReview(companyId, review);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bewertung für "$companyName" gespeichert!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Bewertung speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatDialog(Shop shop) {
    final messages = <Map<String, String>>[];
    final msgCtrl = TextEditingController();
    final scrollCtrl = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: shop.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(shop.logoUrl!, fit: BoxFit.cover,
                                  width: 40, height: 40,
                                  errorBuilder: (_, __, ___) => _buildLetterIcon(shop, false),
                                ),
                              )
                            : Center(
                                child: Text(
                                  shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(ctx).colorScheme.secondary,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Online',
                              style: TextStyle(fontSize: 12, color: Colors.green[600])),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                if (shop.phoneNumber != null || shop.email != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[50],
                    child: Row(
                      children: [
                        Icon(Icons.contact_mail, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        if (shop.phoneNumber != null) ...[
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('tel:${shop.phoneNumber!}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(shop.phoneNumber!,
                              style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                          ),
                          if (shop.email != null) Text('  |  ', style: TextStyle(color: Colors.grey[400])),
                        ],
                        if (shop.email != null)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('mailto:${shop.email!}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(shop.email!,
                              style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Schreiben Sie eine Nachricht',
                                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('Die Firma wird per E-Mail oder Telefon kontaktiert',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = messages[i];
                            final isMe = msg['sender'] == 'me';
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                                    bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(ctx).size.width * 0.7,
                                ),
                                child: Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: msgCtrl,
                          decoration: InputDecoration(
                            hintText: 'Nachricht eingeben...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendChatMessage(setDialogState, msgCtrl, messages, scrollCtrl, shop),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          onPressed: () => _sendChatMessage(setDialogState, msgCtrl, messages, scrollCtrl, shop),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendChatMessage(void Function(void Function()) setDialogState, TextEditingController msgCtrl, List<Map<String, String>> messages, ScrollController scrollCtrl, Shop shop) {
    if (msgCtrl.text.trim().isEmpty) return;
    setDialogState(() {
      messages.add({'sender': 'me', 'text': msgCtrl.text.trim()});
      msgCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
