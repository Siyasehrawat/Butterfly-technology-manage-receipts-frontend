/// Pagination metadata model for API responses
class PaginationMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;

  PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: json['page'] is int ? json['page'] : int.tryParse(json['page'].toString()) ?? 1,
      limit: json['limit'] is int ? json['limit'] : int.tryParse(json['limit'].toString()) ?? 50,
      total: json['total'] is int ? json['total'] : int.tryParse(json['total'].toString()) ?? 0,
      totalPages: json['totalPages'] is int ? json['totalPages'] : int.tryParse(json['totalPages'].toString()) ?? 0,
      hasMore: json['hasMore'] is bool ? json['hasMore'] : (json['hasMore']?.toString().toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
      'hasMore': hasMore,
    };
  }

  /// Get the starting index for the current page (1-indexed)
  int get startIndex => (page - 1) * limit + 1;

  /// Get the ending index for the current page
  int get endIndex => (page * limit).clamp(0, total);

  /// Check if there's a previous page
  bool get hasPrevious => page > 1;

  /// Check if there's a next page
  bool get hasNext => hasMore && page < totalPages;
}
