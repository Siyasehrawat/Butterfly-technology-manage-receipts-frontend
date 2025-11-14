import 'package:flutter/material.dart';

// Centralized helpers for mapping categories and merchants to icons/colors.

IconData getCategoryIcon(String? rawCategory) {
  final category = (rawCategory ?? '').toLowerCase();
  if (category.contains('advertis')) return Icons.campaign_rounded;
  if (category.contains('benefit')) return Icons.volunteer_activism_rounded;
  if (category.contains('bill')) return Icons.receipt_rounded;
  if (category.contains('business')) return Icons.business_center_rounded;
  if (category.contains('car')) return Icons.directions_car_rounded;
  if (category.contains('dining') || category.contains('meal') || category.contains('food')) return Icons.restaurant_rounded;
  if (category.contains('education')) return Icons.school_rounded;
  if (category.contains('entertain')) return Icons.theaters_rounded;
  if (category.contains('equipment') || category.contains('material')) return Icons.home_repair_service_rounded;
  if (category.contains('fee')) return Icons.payments_rounded;
  if (category.contains('fitness') || category.contains('gym')) return Icons.fitness_center_rounded;
  if (category.contains('fuel')) return Icons.local_gas_station_rounded;
  if (category.contains('grocery') || category.contains('grocer')) return Icons.local_grocery_store_rounded;
  if (category.contains('health') || category.contains('healthcare') || category.contains('personal care')) return Icons.local_hospital_rounded;
  if (category.contains('home office') || category.contains('office')) return Icons.chair_rounded;
  if (category.contains('insur')) return Icons.policy_rounded;
  if (category.contains('interest')) return Icons.savings_rounded;
  if (category.contains('labor') || category.contains('professional')) return Icons.badge_rounded;
  if (category.contains('mainten')) return Icons.build_circle_rounded;
  if (category.contains('meals and entertain')) return Icons.emoji_food_beverage_rounded;
  if (category.contains('office suppl')) return Icons.inventory_2_rounded;
  if (category.contains('rent')) return Icons.home_work_rounded;
  if (category.contains('service')) return Icons.design_services_rounded;
  if (category.contains('shopping')) return Icons.shopping_bag_rounded;
  if (category.contains('subscription')) return Icons.autorenew_rounded;
  if (category.contains('travel')) return Icons.travel_explore_rounded;
  if (category.contains('other') || category.isEmpty) return Icons.category_rounded;
  // Fallback
  return Icons.category_rounded;
}

Color getCategoryColor(String? rawCategory) {
  final category = (rawCategory ?? '').toLowerCase();
  if (category.contains('advertis')) return const Color(0xFF7B1FA2); // purple
  if (category.contains('benefit')) return const Color(0xFF2E7D32); // green
  if (category.contains('bill')) return const Color(0xFF00838F); // teal
  if (category.contains('business')) return const Color(0xFF455A64); // blue grey
  if (category.contains('car')) return const Color(0xFF5D4037); // brown
  if (category.contains('dining') || category.contains('meal') || category.contains('food')) return const Color(0xFFD84315); // deep orange
  if (category.contains('education')) return const Color(0xFF0D47A1); // dark blue
  if (category.contains('entertain')) return const Color(0xFFF9A825); // amber
  if (category.contains('equipment') || category.contains('material')) return const Color(0xFF6D4C41); // brown
  if (category.contains('fee')) return const Color(0xFF1E88E5); // blue
  if (category.contains('fitness') || category.contains('gym')) return const Color(0xFF2E7D32); // green
  if (category.contains('fuel')) return const Color(0xFFBF360C); // burnt orange
  if (category.contains('grocery') || category.contains('grocer')) return const Color(0xFF2E7D32); // green
  if (category.contains('health') || category.contains('healthcare') || category.contains('personal care')) return const Color(0xFFC62828); // red
  if (category.contains('home office') || category.contains('office')) return const Color(0xFF283593); // indigo
  if (category.contains('insur')) return const Color(0xFF6A1B9A); // purple
  if (category.contains('interest')) return const Color(0xFF8E24AA); // purple
  if (category.contains('labor') || category.contains('professional')) return const Color(0xFF3949AB); // indigo
  if (category.contains('mainten')) return const Color(0xFF00796B); // teal dark
  if (category.contains('meals and entertain')) return const Color(0xFF8D6E63); // brown
  if (category.contains('office suppl')) return const Color(0xFF455A64);
  if (category.contains('rent')) return const Color(0xFF5C6BC0);
  if (category.contains('service')) return const Color(0xFF546E7A);
  if (category.contains('shopping')) return const Color(0xFFAD1457); // pink
  if (category.contains('subscription')) return const Color(0xFF5D4037); // brown
  if (category.contains('travel')) return const Color(0xFF6A1B9A); // purple
  if (category.contains('other') || category.isEmpty) return const Color(0xFF7E5EFD); // brand default
  return const Color(0xFF7E5EFD);
}

// Merchant-specific mapping; use brand-leaning colors (not exact brand colors)
IconData? getMerchantIcon(String? rawMerchant) {
  final merchant = (rawMerchant ?? '').toLowerCase();
  if (merchant.contains('walmart')) return Icons.shopping_cart_rounded;
  if (merchant.contains('starbucks')) return Icons.local_cafe_rounded;
  if (merchant.contains('amazon')) return Icons.storefront_rounded;
  if (merchant.contains('uber') || merchant.contains('lyft')) return Icons.local_taxi_rounded;
  if (merchant.contains('shell') || merchant.contains('chevron') || merchant.contains('exxon')) return Icons.local_gas_station_rounded;
  if (merchant.contains('mcdonald') || merchant.contains('kfc') || merchant.contains('subway')) return Icons.fastfood_rounded;
  if (merchant.contains('apple')) return Icons.apple_rounded;
  if (merchant.contains('google')) return Icons.android_rounded;
  if (merchant.contains('microsoft')) return Icons.laptop_windows_rounded;
  if (merchant.contains('netflix') || merchant.contains('spotify') || merchant.contains('adobe')) return Icons.subscriptions_rounded;
  if (merchant.contains('at&t') || merchant.contains('verizon') || merchant.contains('t-mobile')) return Icons.network_cell_rounded;
  if (merchant.contains('delta') || merchant.contains('united') || merchant.contains('southwest')) return Icons.flight_rounded;
  if (merchant.contains('airbnb') || merchant.contains('booking')) return Icons.villa_rounded;
  if (merchant.contains('paypal') || merchant.contains('stripe')) return Icons.account_balance_wallet_rounded;
  return null; // fall back to category icon/color
}

Color? getMerchantColor(String? rawMerchant) {
  final merchant = (rawMerchant ?? '').toLowerCase();
  if (merchant.contains('walmart')) return const Color(0xFF1976D2);
  if (merchant.contains('starbucks')) return const Color(0xFF1B5E20);
  if (merchant.contains('amazon')) return const Color(0xFFF57C00);
  if (merchant.contains('uber') || merchant.contains('lyft')) return const Color(0xFF424242);
  if (merchant.contains('shell') || merchant.contains('chevron') || merchant.contains('exxon')) return const Color(0xFFBF360C);
  if (merchant.contains('mcdonald') || merchant.contains('kfc') || merchant.contains('subway')) return const Color(0xFFD84315);
  if (merchant.contains('apple')) return const Color(0xFF263238);
  if (merchant.contains('google')) return const Color(0xFF0F9D58);
  if (merchant.contains('microsoft')) return const Color(0xFF2962FF);
  if (merchant.contains('netflix') || merchant.contains('spotify') || merchant.contains('adobe')) return const Color(0xFFC62828);
  if (merchant.contains('at&t') || merchant.contains('verizon') || merchant.contains('t-mobile')) return const Color(0xFF512DA8);
  if (merchant.contains('delta') || merchant.contains('united') || merchant.contains('southwest')) return const Color(0xFF6A1B9A);
  if (merchant.contains('airbnb') || merchant.contains('booking')) return const Color(0xFFE91E63);
  if (merchant.contains('paypal') || merchant.contains('stripe')) return const Color(0xFF1565C0);
  return null;
}


// Emoji helpers (optional UI enhancement)
String? getCategoryEmoji(String? rawCategory) {
  final category = (rawCategory ?? '').toLowerCase();
  if (category.contains('advertis')) return '📣';
  if (category.contains('benefit')) return '🤝';
  if (category.contains('dining') || category.contains('meal') || category.contains('food')) return '🍽️';
  if (category.contains('grocery') || category.contains('grocer')) return '🛒';
  if (category.contains('fuel') || category.contains('gas')) return '⛽️';
  if (category.contains('travel')) return '✈️';
  if (category.contains('subscription')) return '♾️';
  if (category.contains('shopping')) return '🛍️';
  if (category.contains('health') || category.contains('healthcare') || category.contains('personal care')) return '🏥';
  if (category.contains('fitness') || category.contains('gym')) return '🏋️';
  if (category.contains('education')) return '🎓';
  if (category.contains('entertain')) return '🎬';
  if (category.contains('office')) return '🖇️';
  if (category.contains('rent')) return '🏠';
  if (category.contains('insur')) return '🛡️';
  if (category.contains('car') || category.contains('auto')) return '🚗';
  if (category.contains('fee') || category.contains('bill')) return '💳';
  if (category.contains('interest') || category.contains('savings')) return '💰';
  if (category.contains('mainten') || category.contains('repair')) return '🛠️';
  if (category.isEmpty || category.contains('other')) return '🗂️';
  return null;
}

String? getMerchantEmoji(String? rawMerchant) {
  final merchant = (rawMerchant ?? '').toLowerCase();
  if (merchant.contains('walmart') || merchant.contains('target')) return '🛒';
  if (merchant.contains('starbucks')) return '☕️';
  if (merchant.contains('amazon')) return '📦';
  if (merchant.contains('uber') || merchant.contains('lyft')) return '🚕';
  if (merchant.contains('shell') || merchant.contains('chevron') || merchant.contains('exxon')) return '⛽️';
  if (merchant.contains('mcdonald') || merchant.contains('kfc') || merchant.contains('subway')) return '🍔';
  if (merchant.contains('apple')) return '🍎';
  if (merchant.contains('google')) return '🤖';
  if (merchant.contains('microsoft')) return '💼';
  if (merchant.contains('netflix') || merchant.contains('spotify') || merchant.contains('adobe')) return '🎧';
  if (merchant.contains('at&t') || merchant.contains('verizon') || merchant.contains('t-mobile')) return '📶';
  if (merchant.contains('delta') || merchant.contains('united') || merchant.contains('southwest')) return '✈️';
  if (merchant.contains('airbnb') || merchant.contains('booking')) return '🏡';
  if (merchant.contains('paypal') || merchant.contains('stripe')) return '💳';
  if (merchant.contains('walmart') || merchant.contains('target')) return '🛒';
  return null;
}




