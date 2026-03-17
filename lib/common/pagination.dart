import 'package:flutter/material.dart';
import 'theme.dart';

// ── AppPagination ──────────────────────────────────────────────────────────
// Reusable smart pagination widget.
//
// Usage:
//   AppPagination(
//     currentPage: _currentPage,
//     totalPages:  _totalPages,
//     onPageChanged: (page) => setState(() => _currentPage = page),
//   )
//
// Pagination renders:  ‹  1  …  4  [5]  6  …  10  ›
// Always shows: first, last, current ±1, with … gaps in between.
// ──────────────────────────────────────────────────────────────────────────
class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final void Function(int page) onPageChanged;
  final double horizontalPadding;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, 10, horizontalPadding, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: _buildButtons(),
        ),
      ),
    );
  }

  List<Widget> _buildButtons() {
    final buttons = <Widget>[];

    // Compute which page numbers to show
    final Set<int> show = {1, totalPages};
    for (int p = currentPage - 1; p <= currentPage + 1; p++) {
      if (p >= 1 && p <= totalPages) show.add(p);
    }
    final sorted = show.toList()..sort();

    // ← Prev arrow
    buttons.add(_ArrowButton(
      icon:    Icons.chevron_left_rounded,
      enabled: currentPage > 1,
      onTap:   () => onPageChanged(currentPage - 1),
    ));

    // Page number buttons + ellipsis gaps
    int? prev;
    for (final page in sorted) {
      if (prev != null && page - prev > 1) {
        buttons.add(const _EllipsisWidget());
      }
      buttons.add(_PageNumButton(
        page:     page,
        isActive: page == currentPage,
        onTap:    () => onPageChanged(page),
      ));
      prev = page;
    }

    // Next → arrow
    buttons.add(_ArrowButton(
      icon:    Icons.chevron_right_rounded,
      enabled: currentPage < totalPages,
      onTap:   () => onPageChanged(currentPage + 1),
    ));

    return buttons;
  }
}

// ── Helper: pagination utility ─────────────────────────────────────────────
// Mixin-style helper to keep _currentPage, _totalPages, _pageItems
// boilerplate out of each page. Just call these as top-level functions.

/// Returns total page count given [itemCount] and [pageSize].
int paginationTotalPages(int itemCount, int pageSize) =>
    (itemCount / pageSize).ceil().clamp(1, 9999);

/// Slices [items] to the current page.
List<T> paginationPageItems<T>(
    List<T> items, int currentPage, int pageSize) {
  final start = (currentPage - 1) * pageSize;
  final end   = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primaryLight
                : AppColors.borderLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size:  20,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;

  const _PageNumButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                color:      isActive ? Colors.white : AppColors.textLabel,
                fontSize:   12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EllipsisWidget extends StatelessWidget {
  const _EllipsisWidget();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 20,
        height: 32,
        child: Center(
          child: Text(
            '…',
            style: TextStyle(
              color:      AppColors.textMuted,
              fontSize:   14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}