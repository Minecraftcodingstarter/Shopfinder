import 'package:flutter/material.dart';
import '../models/shop_model.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isHovered;

  const ShopCard({
    super.key,
    required this.shop,
    this.onTap,
    this.isSelected = false,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final distance = shop.distance;
    final theme = Theme.of(context);
    final isCompany = shop.types.contains('company');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isHovered ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isSelected ? 4 : 0,
        shadowColor: Colors.black.withAlpha(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(80)
                    : isCompany
                        ? theme.colorScheme.secondary.withAlpha(40)
                        : Colors.grey[200]!,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isCompany
                          ? theme.colorScheme.secondaryContainer
                          : _getIconBgColor(theme).withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isCompany && shop.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(shop.logoUrl!, fit: BoxFit.cover,
                              width: 52, height: 52,
                              errorBuilder: (_, __, ___) => _buildLetter(shop, theme, isCompany),
                            ),
                          )
                        : _buildLetter(shop, theme, isCompany),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompany)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Eingetragen',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            if (distance != null && !isCompany)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(distance / 1000).toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (shop.rating != null)
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < shop.rating!.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              )),
                              const SizedBox(width: 6),
                              Text(
                                shop.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (shop.userRatingsTotal != null && shop.userRatingsTotal! > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${shop.userRatingsTotal})',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shop.address,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shop.priceLevel != null && shop.priceLevel!.isNotEmpty
                              ? '${_priceRangeLabel(shop.priceLevel!)} (geschätzt)'
                              : 'Keine Preisangabe',
                          style: TextStyle(
                            fontSize: 12,
                            color: shop.priceLevel != null ? Colors.green[700] : Colors.grey[400],
                            fontWeight: FontWeight.w600,
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
      ),
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
        return 'Keine Preisangabe';
    }
  }

  Widget _buildLetter(Shop shop, ThemeData theme, bool isCompany) {
    return Center(
      child: Text(
        shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isCompany ? theme.colorScheme.secondary : _getIconBgColor(theme),
        ),
      ),
    );
  }

  Color _getIconBgColor(ThemeData theme) {
    final type = shop.types.isNotEmpty ? shop.types.first.toLowerCase() : '';
    switch (type) {
      case 'restaurant':
      case 'food':
        return Colors.orange;
      case 'cafe':
        return Colors.brown;
      case 'bakery':
        return Colors.amber;
      case 'supermarket':
      case 'store':
        return Colors.teal;
      case 'book_store':
        return Colors.indigo;
      case 'gym':
        return Colors.red;
      case 'florist':
        return Colors.pink;
      case 'electronics_store':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }
}
