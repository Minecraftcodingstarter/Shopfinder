import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressValidationResult {
  final bool isValid;
  final double? latitude;
  final double? longitude;
  final String? displayName;
  final String? error;

  AddressValidationResult({
    required this.isValid,
    this.latitude,
    this.longitude,
    this.displayName,
    this.error,
  });
}

class AddressService {
  final http.Client _client = http.Client();

  Future<AddressValidationResult> validateAddress(String address) async {
    if (address.trim().isEmpty) {
      return AddressValidationResult(
        isValid: false,
        error: 'Adresse darf nicht leer sein.',
      );
    }

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': address.trim(),
          'format': 'jsonv2',
          'limit': '1',
          'addressdetails': '1',
        },
      );

      final response = await _client.get(url, headers: {
        'User-Agent': 'ShopFinder/1.0',
        'Accept-Language': 'de',
      });

      if (response.statusCode != 200) {
        return AddressValidationResult(
          isValid: false,
          error: 'Adressprüfung fehlgeschlagen (${response.statusCode}).',
        );
      }

      final results = jsonDecode(response.body) as List? ?? [];
      if (results.isEmpty) {
        return AddressValidationResult(
          isValid: false,
          error: 'Adresse nicht gefunden. Bitte geben Sie eine vollständige und existierende Adresse ein.',
        );
      }

      final place = results[0] as Map<String, dynamic>;
      final lat = double.tryParse(place['lat']?.toString() ?? '');
      final lng = double.tryParse(place['lon']?.toString() ?? '');
      final displayName = place['display_name']?.toString();

      if (lat == null || lng == null) {
        return AddressValidationResult(
          isValid: false,
          error: 'Konnte Koordinaten nicht ermitteln.',
        );
      }

      return AddressValidationResult(
        isValid: true,
        latitude: lat,
        longitude: lng,
        displayName: displayName,
      );
    } catch (e) {
      return AddressValidationResult(
        isValid: false,
        error: 'Netzwerkfehler bei Adressprüfung: $e',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
