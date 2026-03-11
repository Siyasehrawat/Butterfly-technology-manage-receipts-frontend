class BannerModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? icon;
  final String? backgroundColor;
  final String? textColor;
  final String? actionType;
  final String? actionUrl;
  final String? actionText;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final String? startsAt;
  final String? endsAt;

  BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.actionType,
    this.actionUrl,
    this.actionText,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
    this.startsAt,
    this.endsAt,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      icon: json['icon'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      textColor: json['textColor'] as String?,
      actionType: json['actionType'] as String?,
      actionUrl: json['actionUrl'] as String?,
      actionText: json['actionText'] as String?,
      imageUrl: json['imageUrl'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      startsAt: json['startsAt'] as String?,
      endsAt: json['endsAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'icon': icon,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'actionType': actionType,
      'actionUrl': actionUrl,
      'actionText': actionText,
      'imageUrl': imageUrl,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'startsAt': startsAt,
      'endsAt': endsAt,
    };
  }

  /// Check if banner is currently visible based on date range
  bool get isVisible {
    if (!isActive) return false;

    final now = DateTime.now();

    if (startsAt != null) {
      try {
        final startDate = DateTime.parse(startsAt!);
        if (now.isBefore(startDate)) return false;
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    if (endsAt != null) {
      try {
        final endDate = DateTime.parse(endsAt!);
        if (now.isAfter(endDate)) return false;
      } catch (e) {
        // Invalid date format, ignore
      }
    }

    return true;
  }
}

