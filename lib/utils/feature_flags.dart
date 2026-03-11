class FeatureFlags {
  final bool walletEnabled; // maps to config.docWalletEnabled
  final bool docWalletPinRequired; // maps to config.docWalletPinRequired
  final bool taxReportsEnabled; // maps to config.taxReportsEnabled
  final bool splitBillEnabled; // maps to config.splitBillEnabled
  final bool remindersEnabled; // maps to config.remindersEnabled
  final bool googleAuthEnabled; // maps to config.googleAuthEnabled
  final bool appleAuthEnabled; // maps to config.appleAuthEnabled
  final bool calendarSyncEnabled; // maps to config.calendarSyncEnabled
  final bool analyticsEnabled; // maps to config.analyticsEnabled
  final bool expenseReportsEnabled; // maps to config.expenseReportsEnabled
  final bool customReportsEnabled; // maps to config.customReportsEnabled
  final bool emailReceiptsEnabled; // maps to config.emailReceiptsEnabled
  final bool mrBucksEnabled; // maps to config.mrBucksEnabled

  const FeatureFlags({
    this.walletEnabled = false,
    this.docWalletPinRequired = true,
    this.taxReportsEnabled = false,
    this.splitBillEnabled = false,
    this.remindersEnabled = false,
    this.googleAuthEnabled = true,
    this.appleAuthEnabled = true,
    this.calendarSyncEnabled = false,
    this.analyticsEnabled = true,
    this.expenseReportsEnabled = true,
    this.customReportsEnabled = true,
    this.emailReceiptsEnabled = true,
    this.mrBucksEnabled = true,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    // Support multiple response shapes:
    // 1) New API: { screensHidden: [], config: { ...camelCase flags... } }
    // 2) Direct config map: { ...camelCase flags... }
    // 3) Legacy: { features: { doc_wallet, tax_reports, doc_wallet_pin_required } }

    final Map<String, dynamic> config =
        (json['config'] as Map<String, dynamic>?) ?? json;
    final Map<String, dynamic> legacy =
        (json['features'] as Map<String, dynamic>?) ?? const {};

    bool readBool(dynamic value, {bool defaultValue = false}) {
      if (value is bool) return value;
      return defaultValue;
    }

    return FeatureFlags(
      walletEnabled: readBool(
        config['docWalletEnabled'] ?? legacy['doc_wallet'],
        defaultValue: false,
      ),
      docWalletPinRequired: readBool(
        config['docWalletPinRequired'] ?? legacy['doc_wallet_pin_required'],
        defaultValue: true,
      ),
      taxReportsEnabled: readBool(
        config['taxReportsEnabled'] ?? legacy['tax_reports'],
        defaultValue: false,
      ),
      splitBillEnabled: readBool(
        config['splitBillEnabled'],
        defaultValue: false,
      ),
      remindersEnabled: readBool(
        config['remindersEnabled'],
        defaultValue: false,
      ),
      googleAuthEnabled: readBool(
        config['googleAuthEnabled'],
        defaultValue: true,
      ),
      appleAuthEnabled: readBool(
        config['appleAuthEnabled'],
        defaultValue: true,
      ),
      calendarSyncEnabled: readBool(
        config['calendarSyncEnabled'],
        defaultValue: false,
      ),
      analyticsEnabled: readBool(
        config['analyticsEnabled'],
        defaultValue: true,
      ),
      expenseReportsEnabled: readBool(
        config['expenseReportsEnabled'],
        defaultValue: true,
      ),
      customReportsEnabled: readBool(
        config['customReportsEnabled'],
        defaultValue: true,
      ),
      emailReceiptsEnabled: readBool(
        config['emailReceiptsEnabled'],
        defaultValue: true,
      ),
      mrBucksEnabled: readBool(
        config['mrBucksEnabled'],
        defaultValue: true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'docWalletEnabled': walletEnabled,
      'docWalletPinRequired': docWalletPinRequired,
      'taxReportsEnabled': taxReportsEnabled,
      'splitBillEnabled': splitBillEnabled,
      'remindersEnabled': remindersEnabled,
      'googleAuthEnabled': googleAuthEnabled,
      'appleAuthEnabled': appleAuthEnabled,
      'calendarSyncEnabled': calendarSyncEnabled,
      'analyticsEnabled': analyticsEnabled,
      'expenseReportsEnabled': expenseReportsEnabled,
      'customReportsEnabled': customReportsEnabled,
      'emailReceiptsEnabled': emailReceiptsEnabled,
      'mrBucksEnabled': mrBucksEnabled,
    };
  }

  @override
  String toString() {
    return 'FeatureFlags(walletEnabled: $walletEnabled, docWalletPinRequired: $docWalletPinRequired, taxReportsEnabled: $taxReportsEnabled, splitBillEnabled: $splitBillEnabled, remindersEnabled: $remindersEnabled, googleAuthEnabled: $googleAuthEnabled, appleAuthEnabled: $appleAuthEnabled, calendarSyncEnabled: $calendarSyncEnabled, analyticsEnabled: $analyticsEnabled, expenseReportsEnabled: $expenseReportsEnabled, customReportsEnabled: $customReportsEnabled, emailReceiptsEnabled: $emailReceiptsEnabled, mrBucksEnabled: $mrBucksEnabled)';
  }
}