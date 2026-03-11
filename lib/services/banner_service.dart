import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banner_model.dart';
import 'api_service_bypass.dart';

class BannerService {
  static const String _cacheKey = 'cached_banners';
  static const String _cacheTimestampKey = 'cached_banners_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Fetch active banners from API
  Future<List<BannerModel>> fetchBanners({bool forceRefresh = false}) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedBanners = await _getCachedBanners();
        if (cachedBanners != null && cachedBanners.isNotEmpty) {
          debugPrint('BannerService: Returning cached banners (${cachedBanners.length} items)');
          return cachedBanners;
        }
      }

      debugPrint('BannerService: Fetching banners from API...');
      final response = await ApiService.get('/banners');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> bannersJson = responseData['data'] as List<dynamic>;
          final List<BannerModel> banners = bannersJson
              .map((json) => BannerModel.fromJson(json as Map<String, dynamic>))
              .toList();

          // Cache the banners
          await _cacheBanners(banners);

          debugPrint('BannerService: Successfully fetched ${banners.length} banners');
          return banners;
        } else {
          debugPrint('BannerService: API returned success=false or no data');
          return [];
        }
      } else {
        debugPrint('BannerService: API returned status ${response.statusCode}');
        // Return cached banners if available, even if API fails
        final cachedBanners = await _getCachedBanners();
        return cachedBanners ?? [];
      }
    } catch (e) {
      debugPrint('BannerService: Error fetching banners: $e');
      // Return cached banners if available
      final cachedBanners = await _getCachedBanners();
      return cachedBanners ?? [];
    }
  }

  /// Get cached banners if still valid
  Future<List<BannerModel>?> _getCachedBanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final timestampStr = prefs.getString(_cacheTimestampKey);

      if (cachedJson == null || timestampStr == null) {
        return null;
      }

      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();

      // Check if cache is still valid
      if (now.difference(timestamp) > _cacheDuration) {
        debugPrint('BannerService: Cache expired');
        return null;
      }

      final List<dynamic> bannersJson = json.decode(cachedJson) as List<dynamic>;
      final List<BannerModel> banners = bannersJson
          .map((json) => BannerModel.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('BannerService: Returning valid cached banners');
      return banners;
    } catch (e) {
      debugPrint('BannerService: Error reading cache: $e');
      return null;
    }
  }

  /// Cache banners with timestamp
  Future<void> _cacheBanners(List<BannerModel> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bannersJson = json.encode(
        banners.map((banner) => banner.toJson()).toList(),
      );
      await prefs.setString(_cacheKey, bannersJson);
      await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
      debugPrint('BannerService: Cached ${banners.length} banners');
    } catch (e) {
      debugPrint('BannerService: Error caching banners: $e');
    }
  }

  /// Clear cached banners
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('BannerService: Cleared banner cache');
    } catch (e) {
      debugPrint('BannerService: Error clearing cache: $e');
    }
  }
}

