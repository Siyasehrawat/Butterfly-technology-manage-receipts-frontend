/// Models for Calendar Sync functionality

/// Calendar Connection Status Model
class CalendarStatus {
  final bool calendarSyncEnabled;
  final bool hasAccessToken;
  final bool hasRefreshToken;
  
  CalendarStatus({
    required this.calendarSyncEnabled,
    required this.hasAccessToken,
    required this.hasRefreshToken,
  });
  
  factory CalendarStatus.fromJson(Map<String, dynamic> json) {
    return CalendarStatus(
      calendarSyncEnabled: json['calendarSyncEnabled'] ?? false,
      hasAccessToken: json['hasAccessToken'] ?? false,
      hasRefreshToken: json['hasRefreshToken'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'calendarSyncEnabled': calendarSyncEnabled,
      'hasAccessToken': hasAccessToken,
      'hasRefreshToken': hasRefreshToken,
    };
  }
  
  /// Check if calendar is fully connected
  bool get isFullyConnected => 
      calendarSyncEnabled && hasAccessToken && hasRefreshToken;
}

/// Calendar Auth URL Response Model
class CalendarAuthResponse {
  final String authUrl;
  final String userId;
  final String? message;
  
  CalendarAuthResponse({
    required this.authUrl,
    required this.userId,
    this.message,
  });
  
  factory CalendarAuthResponse.fromJson(Map<String, dynamic> json) {
    return CalendarAuthResponse(
      authUrl: json['authUrl'] ?? '',
      userId: json['userId'] ?? '',
      message: json['message'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'authUrl': authUrl,
      'userId': userId,
      if (message != null) 'message': message,
    };
  }
}

/// Reminder Model
class Reminder {
  final String id;
  final String userId;
  final int receiptId;
  final DateTime reminderDate;
  final String? billType;
  final String recurrence;
  final String remindBefore;
  final bool syncToCalendar;
  final String? calendarEventId;
  final bool isEnabled;
  final bool emailReminder;
  final bool pushReminder;
  final String? message;
  final Receipt? receipt;
  
  Reminder({
    required this.id,
    required this.userId,
    required this.receiptId,
    required this.reminderDate,
    this.billType,
    required this.recurrence,
    required this.remindBefore,
    required this.syncToCalendar,
    this.calendarEventId,
    required this.isEnabled,
    required this.emailReminder,
    required this.pushReminder,
    this.message,
    this.receipt,
  });
  
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? '',
      receiptId: json['receiptId'] ?? 0,
      reminderDate: DateTime.parse(json['reminderDate']),
      billType: json['billType'],
      recurrence: json['recurrence'] ?? 'One-time',
      remindBefore: json['remindBefore'] ?? 'On due date',
      syncToCalendar: json['syncToCalendar'] ?? false,
      calendarEventId: json['calendarEventId'],
      isEnabled: json['isEnabled'] ?? true,
      emailReminder: json['emailReminder'] ?? true,
      pushReminder: json['pushReminder'] ?? true,
      message: json['message'],
      receipt: json['receipt'] != null 
          ? Receipt.fromJson(json['receipt']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'receiptId': receiptId,
      'reminderDate': reminderDate.toIso8601String(),
      if (billType != null) 'billType': billType,
      'recurrence': recurrence,
      'remindBefore': remindBefore,
      'syncToCalendar': syncToCalendar,
      if (calendarEventId != null) 'calendarEventId': calendarEventId,
      'isEnabled': isEnabled,
      'emailReminder': emailReminder,
      'pushReminder': pushReminder,
      if (message != null) 'message': message,
      if (receipt != null) 'receipt': receipt!.toJson(),
    };
  }
}

/// Receipt Model (for use in Reminder)
class Receipt {
  final int id;
  final String merchant;
  final String amount;
  final String? category;
  final String? receiptDate;
  final String? tags;
  
  Receipt({
    required this.id,
    required this.merchant,
    required this.amount,
    this.category,
    this.receiptDate,
    this.tags,
  });
  
  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] ?? 0,
      merchant: json['merchant'] ?? 'Unknown',
      amount: json['amount']?.toString() ?? '0',
      category: json['category'],
      receiptDate: json['receiptDate'],
      tags: json['tags'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      if (category != null) 'category': category,
      if (receiptDate != null) 'receiptDate': receiptDate,
      if (tags != null) 'tags': tags,
    };
  }
}

/// Reminder Creation Response Model
class ReminderCreateResponse {
  final String message;
  final Reminder reminder;
  final int deletedCount;
  final bool calendarSynced;
  
  ReminderCreateResponse({
    required this.message,
    required this.reminder,
    required this.deletedCount,
    required this.calendarSynced,
  });
  
  factory ReminderCreateResponse.fromJson(Map<String, dynamic> json) {
    return ReminderCreateResponse(
      message: json['message'] ?? '',
      reminder: Reminder.fromJson(json['reminder']),
      deletedCount: json['deletedCount'] ?? 0,
      calendarSynced: json['calendarSynced'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'reminder': reminder.toJson(),
      'deletedCount': deletedCount,
      'calendarSynced': calendarSynced,
    };
  }
}

/// Reminder Request Payload
class ReminderRequest {
  final String userId;
  final int receiptId;
  final String reminderDate;
  final String? billType;
  final String recurrence;
  final String remindBefore;
  final bool syncToCalendar;
  final bool isEnabled;
  final bool emailReminder;
  final bool pushReminder;
  final String? message;
  
  ReminderRequest({
    required this.userId,
    required this.receiptId,
    required this.reminderDate,
    this.billType,
    this.recurrence = 'One-time',
    this.remindBefore = 'On due date',
    this.syncToCalendar = false,
    this.isEnabled = true,
    this.emailReminder = true,
    this.pushReminder = true,
    this.message,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'receiptId': receiptId,
      'reminderDate': reminderDate,
      if (billType != null) 'billType': billType,
      'recurrence': recurrence,
      'remindBefore': remindBefore,
      'syncToCalendar': syncToCalendar,
      'isEnabled': isEnabled,
      'emailReminder': emailReminder,
      'pushReminder': pushReminder,
      if (message != null) 'message': message,
    };
  }
}



