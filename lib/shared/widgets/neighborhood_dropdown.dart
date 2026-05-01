import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/data/neighborhoods_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';

class NeighborhoodDropdown extends StatefulWidget {
  final Neighborhood? selectedNeighborhood;
  final Function(Neighborhood?) onChanged;
  final String label;
  final bool isRequired;
  final String hint;
  final double? storeLatitude;
  final double? storeLongitude;
  final VoidCallback? onLocationPickerTap;

  const NeighborhoodDropdown({
    super.key,
    this.selectedNeighborhood,
    required this.onChanged,
    required this.label,
    this.isRequired = false,
    required this.hint,
    this.storeLatitude,
    this.storeLongitude,
    this.onLocationPickerTap,
  });

  @override
  State<NeighborhoodDropdown> createState() => _NeighborhoodDropdownState();
}

// Helper class to store neighborhood with distance
class _NeighborhoodWithDistance {
  final Neighborhood neighborhood;
  final double distance;

  _NeighborhoodWithDistance({
    required this.neighborhood,
    required this.distance,
  });
}

// Calculate distance between two coordinates using Haversine formula
double _calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371; // Earth radius in kilometers

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final double distance = earthRadius * c;

  return distance;
}

double _degreesToRadians(double degrees) {
  return degrees * (math.pi / 180);
}

// Sort neighborhoods by distance from store location
List<Neighborhood> _sortNeighborhoodsByDistance(
  List<Neighborhood> neighborhoods,
  double? storeLat,
  double? storeLng,
) {
  if (storeLat == null || storeLng == null) {
    return neighborhoods; // Return unsorted if no store location
  }

  final List<_NeighborhoodWithDistance> neighborhoodsWithDistance =
      neighborhoods.map((neighborhood) {
    final distance = _calculateDistance(
      storeLat,
      storeLng,
      neighborhood.latitude,
      neighborhood.longitude,
    );
    return _NeighborhoodWithDistance(
      neighborhood: neighborhood,
      distance: distance,
    );
  }).toList();

  // Sort by distance (closest first)
  neighborhoodsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

  return neighborhoodsWithDistance
      .map((item) => item.neighborhood)
      .toList();
}

class _NeighborhoodDropdownState extends State<NeighborhoodDropdown> {
  final TextEditingController _searchController = TextEditingController();
  List<Neighborhood> _filteredNeighborhoods = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredNeighborhoods();
    _searchController.addListener(_filterNeighborhoods);
  }

  void _updateFilteredNeighborhoods() {
    final allNeighborhoods = NeighborhoodsData.getAll();
    _filteredNeighborhoods = _sortNeighborhoodsByDistance(
      allNeighborhoods,
      widget.storeLatitude,
      widget.storeLongitude,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterNeighborhoods() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _updateFilteredNeighborhoods();
      } else {
        final allNeighborhoods = NeighborhoodsData.getAll();
        final filtered = allNeighborhoods.where((neighborhood) {
          return neighborhood.name.toLowerCase().contains(query);
        }).toList();
        _filteredNeighborhoods = _sortNeighborhoodsByDistance(
          filtered,
          widget.storeLatitude,
          widget.storeLongitude,
        );
      }
    });
  }

  void _showNeighborhoodSearchDialog() {
    // Reset search when opening dialog
    _searchController.clear();
    _updateFilteredNeighborhoods();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.sizeOf(context).width * 0.9,
              height: MediaQuery.sizeOf(context).height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) {
                      setDialogState(() {
                        _filterNeighborhoods();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث عن المنطقة...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setDialogState(() {
                                  _filterNeighborhoods();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: context.themeSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Neighborhoods list
                  Expanded(
                    child: _filteredNeighborhoods.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد نتائج',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredNeighborhoods.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: AppColors.border.withOpacity(0.5),
                            ),
                            itemBuilder: (context, index) {
                              final neighborhood = _filteredNeighborhoods[index];
                              // Calculate distance if store location is available
                              double? distance;
                              if (widget.storeLatitude != null &&
                                  widget.storeLongitude != null) {
                                distance = _calculateDistance(
                                  widget.storeLatitude!,
                                  widget.storeLongitude!,
                                  neighborhood.latitude,
                                  neighborhood.longitude,
                                );
                              }
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  neighborhood.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.themeTextPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: distance != null
                                    ? Text(
                                        '${distance.toStringAsFixed(1)} كم',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textTertiary,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  widget.onChanged(neighborhood);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                  // Close button
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.themeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showNeighborhoodSearchDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.themeSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.selectedNeighborhood != null
                          ? AppColors.success
                          : context.themeBorder,
                      width: widget.selectedNeighborhood != null ? 2 : 1,
                    ),
                    boxShadow: widget.selectedNeighborhood != null
                        ? [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (widget.selectedNeighborhood != null
                                ? AppColors.success
                                : AppColors.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: widget.selectedNeighborhood != null
                                ? AppColors.success
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      // Selected neighborhood or hint
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            widget.selectedNeighborhood?.name ?? widget.hint,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: widget.selectedNeighborhood != null
                                  ? context.themeTextPrimary
                                  : AppColors.textTertiary,
                              fontWeight: widget.selectedNeighborhood != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      // Search icon
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.search,
                          color: context.themeTextPrimary,
                          size: 20,
                        ),
                      ),
                      // Success indicator
                      if (widget.selectedNeighborhood != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Location picker button
            if (widget.onLocationPickerTap != null) ...[
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: widget.onLocationPickerTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

