class ReminderSettings {
  final bool isEnabled;
  final bool emailReminder;
  final bool pushNotification;
  final String? reminderMessage;
  final DateTime? customReminderDate; // This is the date selected in the dialog
  final String? recurrence; // Monthly, Weekly, Daily, etc.
  final String? remindBefore; // 1 day before, 2 days before, etc.
  final bool syncToCalendar; // Sync to calendar option
  final String? billType; // Optional bill type/category chosen in dialog

  ReminderSettings({
    this.isEnabled = false,
    this.emailReminder = false,
    this.pushNotification = false,
    this.reminderMessage,
    this.customReminderDate,
    this.recurrence,
    this.remindBefore,
    this.syncToCalendar = false,
    this.billType,
  });

  // No changes needed here, as the API payload will be constructed in the screen
  // to include the formatted reminderDate string and userId/receiptId.
  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'emailReminder': emailReminder,
      'pushReminder': pushNotification,
      'reminderMessage': reminderMessage,
      // customReminderDate is not directly sent in this format to the new API
      // It's used to derive the 'reminderDate' string in the screen.
      'customReminderDate': customReminderDate?.toIso8601String(),
      'recurrence': recurrence,
      'remindBefore': remindBefore,
      'syncToCalendar': syncToCalendar,
      'billType': billType,
    };
  }

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      isEnabled: json['isEnabled'] ?? false,
      emailReminder: json['emailReminder'] ?? false,
      pushNotification: json['pushReminder'] ?? false,
      reminderMessage: json['message'],
      // The API might return 'reminderDate' as a string,
      // so we parse it back into customReminderDate for internal use.
      customReminderDate: json['reminderDate'] != null
          ? DateTime.tryParse(json['reminderDate'])
          : null,
      recurrence: json['recurrence'],
      remindBefore: json['remindBefore'],
      syncToCalendar: json['syncToCalendar'] ?? false,
      billType: json['billType']?.toString(),
    );
  }
}
