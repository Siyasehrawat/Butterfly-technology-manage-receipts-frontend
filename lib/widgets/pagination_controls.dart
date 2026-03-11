import 'package:flutter/material.dart';
import '../models/pagination_model.dart';

/// Reusable pagination controls widget
class PaginationControls extends StatelessWidget {
  final PaginationMeta pagination;
  final int currentPage;
  final bool isLoading;
  final Function(int page) onPageChanged;
  final bool showPageInfo;

  const PaginationControls({
    super.key,
    required this.pagination,
    required this.currentPage,
    required this.onPageChanged,
    this.isLoading = false,
    this.showPageInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        color: Colors.grey.shade50,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          if (showPageInfo)
            Text(
              'Page ${pagination.page} of ${pagination.totalPages} (${pagination.total} total)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            )
          else
            const SizedBox.shrink(),

          // Navigation buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: pagination.hasPrevious && !isLoading
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Previous page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pagination.page}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: pagination.hasMore && !isLoading
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
