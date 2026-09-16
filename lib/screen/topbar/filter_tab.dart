import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/screen/topbar/filter_provider.dart';

class FilterTab extends ConsumerWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String filterType; // e.g., 'location' or 'category'

  const FilterTab({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filterType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. WATCH the current filter state
    final currentFilters = ref.watch(filterProvider);

    // 2. DETERMINE if this specific tab is active
    bool isActive = false;
    if (filterType == 'location') {
      isActive = currentFilters.location != null && currentFilters.location!.isNotEmpty;
    } else if (filterType == 'category') {
      isActive = currentFilters.category != null && currentFilters.category!.isNotEmpty;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          // White background opacity when active for the "Bikroy" look
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? Colors.white : Colors.white54,
              width: 1
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                // Use the state value if active, otherwise use default label
                isActive ? _getActiveLabel(currentFilters) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  String _getActiveLabel(FilterState state) {
    if (filterType == 'location') return state.location ?? label;
    if (filterType == 'category') return state.subCategory ?? state.category ?? label;
    return label;
  }
}