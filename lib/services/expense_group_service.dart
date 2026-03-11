import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';
import '../models/pagination_model.dart';
import '../models/pagination_model.dart';

/// Service for managing Expense Groups API endpoints
/// All routes are prefixed with `/api/expense-groups`
class ExpenseGroupService {
  /// Create a new expense group
  /// POST /api/expense-groups
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    required String createdBy,
    String? description,
    List<Map<String, dynamic>>? members,
    String? token,
  }) async {
    try {
      debugPrint('📤 Create Group Request:');
      debugPrint('   name: $name');
      debugPrint('   createdBy: $createdBy');
      debugPrint('   description: $description');
      debugPrint('   members: ${members?.length ?? 0}');

      final body = <String, dynamic>{
        'name': name,
        'createdBy': createdBy,
      };

      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }

      if (members != null && members.isNotEmpty) {
        body['members'] = members.map((m) => {
          'email': m['email']?.toString().toLowerCase() ?? '',
          if (m['name'] != null) 'name': m['name'],
        }).toList();
      }

      final response = await ApiService.post(
        '/expense-groups',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Create Group Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['group'] ?? data,
        };
      } else {
        String errorMessage = 'Failed to create group';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.createGroup error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all groups where the user is a member
  /// GET /api/expense-groups/user-groups?userId={userId}&page={page}&limit={limit}&search={search}
  static Future<Map<String, dynamic>> getUserGroups({
    required String userId,
    String? search,
    int page = 1,
    int limit = 20,
    String? token,
  }) async {
    try {
      debugPrint('📤 Get User Groups Request:');
      debugPrint('   userId: $userId');
      debugPrint('   search: $search');
      debugPrint('   page: $page');
      debugPrint('   limit: $limit');

      final queryParams = <String, String>{
        'userId': userId,
        'page': page.toString(),
        'limit': limit.clamp(1, 50).toString(), // Max 50
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await ApiService.get(
        '/expense-groups/user-groups',
        token: token,
        queryParameters: queryParams,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Get User Groups Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse pagination
        PaginationMeta? pagination;
        if (data['pagination'] != null) {
          pagination = PaginationMeta.fromJson(data['pagination']);
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['groups'] ?? [],
          'pagination': pagination,
        };
      } else {
        String errorMessage = 'Failed to fetch groups';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.getUserGroups error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get detailed information about a group including expenses and balances
  /// GET /api/expense-groups/:groupId?userId={userId}
  /// 
  /// Response structure:
  /// {
  ///   "group": {...},
  ///   "expenses": [...],
  ///   "balances": [
  ///     {
  ///       "memberId": "...",
  ///       "userId": "...",
  ///       "email": "...",
  ///       "name": "...",
  ///       "balance": "100.00",           // Net balance (formatted)
  ///       "balanceRaw": 100,            // Net balance (raw number)
  ///       "owes": 0,                     // Total amount this member owes
  ///       "owed": 100,                   // Total amount owed to this member
  ///       "owesBreakdown": [             // Individual breakdown of who this member owes
  ///         {
  ///           "toEmail": "...",
  ///           "toName": "...",
  ///           "amount": 200,
  ///           "amountFormatted": "200.00"
  ///         }
  ///       ],
  ///       "owedBreakdown": [             // Individual breakdown of who owes this member
  ///         {
  ///           "fromEmail": "...",
  ///           "fromName": "...",
  ///           "amount": 100,
  ///           "amountFormatted": "100.00"
  ///         }
  ///       ]
  ///     }
  ///   ]
  /// }
  static Future<Map<String, dynamic>> getGroupDetails({
    required String groupId,
    String? userId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Get Group Details Request:');
      debugPrint('   groupId: $groupId');
      debugPrint('   userId: $userId');

      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }

      final response = await ApiService.get(
        '/expense-groups/$groupId',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Get Group Details Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': {
            'group': data['group'] ?? {},
            'expenses': data['expenses'] ?? [],
            'balances': data['balances'] ?? [],
          },
        };
      } else {
        String errorMessage = 'Failed to fetch group details';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.getGroupDetails error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update group name and/or description
  /// PUT /api/expense-groups/:groupId
  static Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? token,
  }) async {
    try {
      debugPrint('📤 Update Group Request:');
      debugPrint('   groupId: $groupId');
      debugPrint('   name: $name');
      debugPrint('   description: $description');

      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        body['name'] = name;
      }
      if (description != null) {
        body['description'] = description;
      }

      final response = await ApiService.put(
        '/expense-groups/$groupId',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Update Group Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['group'] ?? data,
        };
      } else {
        String errorMessage = 'Failed to update group';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.updateGroup error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Delete an expense group
  /// DELETE /api/expense-groups/:groupId
  static Future<Map<String, dynamic>> deleteGroup({
    required String groupId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Delete Group Request:');
      debugPrint('   groupId: $groupId');

      final response = await ApiService.delete(
        '/expense-groups/$groupId',
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Delete Group Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'message': data['message'] ?? 'Group deleted successfully',
        };
      } else {
        String errorMessage = 'Failed to delete group';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.deleteGroup error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add one or more members to an existing group
  /// POST /api/expense-groups/:groupId/members
  static Future<Map<String, dynamic>> addMembers({
    required String groupId,
    required String addedBy,
    required List<Map<String, dynamic>> members,
    String? token,
  }) async {
    try {
      debugPrint('📤 Add Members Request:');
      debugPrint('   groupId: $groupId');
      debugPrint('   addedBy: $addedBy');
      debugPrint('   members: ${members.length}');

      final body = {
        'addedBy': addedBy,
        'members': members.map((m) => {
          'email': m['email']?.toString().toLowerCase() ?? '',
          if (m['name'] != null) 'name': m['name'],
        }).toList(),
      };

      final response = await ApiService.post(
        '/expense-groups/$groupId/members',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Add Members Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['group'] ?? data,
        };
      } else {
        String errorMessage = 'Failed to add members';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.addMembers error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Remove a member from a group
  /// DELETE /api/expense-groups/:groupId/members/:memberId
  static Future<Map<String, dynamic>> removeMember({
    required String groupId,
    required String memberId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Remove Member Request:');
      debugPrint('   groupId: $groupId');
      debugPrint('   memberId: $memberId');

      final response = await ApiService.delete(
        '/expense-groups/$groupId/members/$memberId',
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Remove Member Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'message': data['message'] ?? 'Member removed successfully',
        };
      } else {
        String errorMessage = 'Failed to remove member';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.removeMember error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a receipt directly in an expense group
  /// This endpoint automatically creates both the receipt and the associated split bill
  /// in a single atomic transaction. All participants must be group members.
  /// 
  /// Endpoint: POST /api/expense-groups/:groupId/receipts
  /// Used in:
  /// - GroupSplitOptionsScreen (after creating group, "+ add manually", "+ add receipt to group")
  /// 
  /// API Documentation: See POST /api/expense-groups/:groupId/receipts
  /// 
  /// ⚠️ BREAKING CHANGE: paidBy → paidByEmail
  /// - Use paidByEmail (email string) instead of paidBy (userId)
  /// - Optional: defaults to createdBy user's email if not provided
  static Future<Map<String, dynamic>> createReceiptInGroup({
    required String groupId,
    required String merchant,
    required double amount,
    required String receiptDate,
    String? paidByEmail,
    required String createdBy,
    required List<Map<String, dynamic>> participants,
    String? category,
    String? tags,
    String? comments,
    bool? showInPersonalReceipts,
    String? token,
  }) async {
    try {
      debugPrint('📤 Create Receipt in Group Request:');
      debugPrint('   Endpoint: POST /api/expense-groups/');
      debugPrint('   groupId: $groupId');
      debugPrint('   merchant: $merchant');
      debugPrint('   amount: $amount');
      debugPrint('   receiptDate: $receiptDate (format: YYYY-MM-DD)');
      debugPrint('   paidByEmail: $paidByEmail (optional, defaults to createdBy user email)');
      debugPrint('   createdBy: $createdBy (must be UUID/userId)');
      debugPrint('   showInPersonalReceipts: $showInPersonalReceipts');
      debugPrint('   participants: ${participants.length}');
      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        debugPrint('     [$i] email: ${p['email']}, share: ${p['share']}, name: ${p['name'] ?? 'N/A'}');
      }

      // Build request body according to API spec:
      // POST /api/expense-groups/:groupId/receipts
      // {
      //   "merchant": string (required),
      //   "amount": number (required),
      //   "receiptDate": string YYYY-MM-DD (required),
      //   "category": string (optional),
      //   "paidByEmail": email string (optional, defaults to createdBy user's email),
      //   "createdBy": UUID string (required),
      //   "participants": [{ email, share, name? }] (required),
      //   "tags": string (optional),
      //   "comments": string (optional),
      //   "showInPersonalReceipts": boolean (optional, defaults based on paidByEmail)
      // }
      final body = <String, dynamic>{
        'merchant': merchant,
        'amount': amount,
        'receiptDate': receiptDate,
        'createdBy': createdBy, // Must be UUID (userId)
        'participants': participants.map((p) {
          final participant = <String, dynamic>{
            'email': p['email']?.toString().toLowerCase() ?? '',
            'share': p['share'] is num 
                ? p['share'] 
                : double.tryParse(p['share']?.toString() ?? '0') ?? 0.0,
          };
          // Add name only if provided (optional field)
          if (p['name'] != null && p['name'].toString().trim().isNotEmpty) {
            participant['name'] = p['name'].toString().trim();
          }
          return participant;
        }).toList(),
      };

      // Add optional paidByEmail if provided
      if (paidByEmail != null && paidByEmail.trim().isNotEmpty) {
        body['paidByEmail'] = paidByEmail.trim().toLowerCase();
      }

      // Add optional showInPersonalReceipts if provided
      if (showInPersonalReceipts != null) {
        body['showInPersonalReceipts'] = showInPersonalReceipts;
      }

      // Add optional fields only if they have values
      if (category != null && category.trim().isNotEmpty) {
        body['category'] = category.trim();
      }

      if (tags != null && tags.trim().isNotEmpty) {
        body['tags'] = tags.trim();
      }

      if (comments != null && comments.trim().isNotEmpty) {
        body['comments'] = comments.trim();
      }

      debugPrint('📋 Request Body: ${json.encode(body)}');

      final response = await ApiService.post(
        '/expense-groups/$groupId/receipts',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Create Receipt in Group Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': {
            'receipt': data['receipt'] ?? {},
            'splitBill': data['splitBill'] ?? {},
          },
        };
      } else {
        String errorMessage = 'Failed to create receipt in group';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.createReceiptInGroup error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user's contacts that can be added to a group
  /// GET /api/split-bill/contacts/{userId}
  /// Query parameters:
  /// - search: Filter contacts by name, email, or phone (case-insensitive partial match)
  /// - page: Page number for pagination (default: 1)
  /// - limit: Number of contacts per page (default: 50)
  /// - groupId: If provided, excludes contacts that are already members of this group
  static Future<Map<String, dynamic>> getContacts({
    required String userId,
    String? groupId,
    String? search,
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      debugPrint('📤 Get Contacts Request:');
      debugPrint('   Endpoint: GET /api/split-bill/contacts/$userId');
      debugPrint('   userId: $userId');
      debugPrint('   groupId: $groupId');
      debugPrint('   search: $search');
      debugPrint('   page: $page');
      debugPrint('   limit: $limit');

      final queryParams = <String, String>{};
      if (groupId != null && groupId.isNotEmpty) {
        queryParams['groupId'] = groupId;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (page != null) {
        queryParams['page'] = page.toString();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final response = await ApiService.get(
        '/split-bill/contacts/$userId',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Get Contacts Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle the new response structure: { success: true, data: { contacts: [...], pagination: {...} } }
        List<Map<String, dynamic>> contacts = [];
        if (responseData is Map) {
          if (responseData['success'] == true && responseData['data'] != null) {
            final data = responseData['data'];
            if (data is Map && data['contacts'] != null) {
              contacts = List<Map<String, dynamic>>.from(data['contacts']);
            }
          } else if (responseData['contacts'] != null) {
            // Fallback: handle old format if needed
            contacts = List<Map<String, dynamic>>.from(responseData['contacts']);
          }
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'data': contacts,
        };
      } else {
        String errorMessage = 'Failed to fetch contacts';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.getContacts error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a split bill for an existing receipt (Method 1)
  /// POST /api/split-bill
  /// Use this when you already have a receipt and want to split it among group members
  /// 
  /// ⚠️ BREAKING CHANGE: paidBy → paidByEmail
  /// - Use paidByEmail (email string) instead of paidBy (userId)
  /// - Optional: defaults to createdBy user's email if not provided
  static Future<Map<String, dynamic>> createSplitBillForReceipt({
    required int receiptId,
    required String createdBy,
    required List<Map<String, dynamic>> participants,
    String? groupId,
    String? paidByEmail,
    String? token,
  }) async {
    try {
      debugPrint('📤 Create Split Bill for Receipt Request:');
      debugPrint('   Endpoint: POST /api/split-bill');
      debugPrint('   receiptId: $receiptId');
      debugPrint('   createdBy: $createdBy');
      debugPrint('   groupId: $groupId');
      debugPrint('   paidByEmail: $paidByEmail (optional, defaults to createdBy user email)');
      debugPrint('   participants: ${participants.length}');
      for (var i = 0; i < participants.length; i++) {
        final p = participants[i];
        debugPrint('     [$i] email: ${p['email']}, share: ${p['share']}, name: ${p['name'] ?? 'N/A'}');
      }

      // Build request body according to API spec:
      // POST /api/split-bill
      // {
      //   "receiptId": number (required),
      //   "createdBy": UUID string (required),
      //   "groupId": UUID string (optional),
      //   "paidByEmail": email string (optional, defaults to createdBy user's email),
      //   "participants": [{ email, share, name? }] (required)
      // }
      final body = <String, dynamic>{
        'receiptId': receiptId,
        'createdBy': createdBy,
        'participants': participants.map((p) {
          final participant = <String, dynamic>{
            'email': p['email']?.toString().toLowerCase() ?? '',
            'share': p['share'] is num 
                ? p['share'] 
                : double.tryParse(p['share']?.toString() ?? '0') ?? 0.0,
          };
          // Add name only if provided (optional field)
          if (p['name'] != null && p['name'].toString().trim().isNotEmpty) {
            participant['name'] = p['name'].toString().trim();
          }
          return participant;
        }).toList(),
      };

      // Add optional fields only if they have values
      if (groupId != null && groupId.trim().isNotEmpty) {
        body['groupId'] = groupId.trim();
      }

      if (paidByEmail != null && paidByEmail.trim().isNotEmpty) {
        body['paidByEmail'] = paidByEmail.trim().toLowerCase();
      }

      debugPrint('📋 Request Body: ${json.encode(body)}');

      final response = await ApiService.post(
        '/split-bill',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Create Split Bill Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': {
            'splitBillId': data['splitBillId'] ?? data['id'] ?? '',
            'totalAmount': data['totalAmount'] ?? '',
            'participants': data['participants'] ?? [],
          },
        };
      } else {
        String errorMessage = 'Failed to create split bill';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.createSplitBillForReceipt error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // SETTLEMENT APIs
  // ============================================================================

  /// Get specific debts (who owes whom) for settlement selection
  /// GET /api/expense-groups/:groupId/debts?userId={userId}
  static Future<Map<String, dynamic>> getDebts({
    required String groupId,
    String? userId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Get Debts Request:');
      debugPrint('   Endpoint: GET /api/expense-groups/$groupId/debts');
      debugPrint('   groupId: $groupId');
      debugPrint('   userId: $userId');

      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }

      final response = await ApiService.get(
        '/expense-groups/$groupId/debts',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Get Debts Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['debts'] ?? [],
        };
      } else {
        String errorMessage = 'Failed to fetch debts';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.getDebts error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all settlements for a group
  /// GET /api/expense-groups/:groupId/settlements?userId={userId}
  static Future<Map<String, dynamic>> getSettlements({
    required String groupId,
    String? userId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Get Settlements Request:');
      debugPrint('   Endpoint: GET /api/expense-groups/$groupId/settlements');
      debugPrint('   groupId: $groupId');
      debugPrint('   userId: $userId');

      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }

      final response = await ApiService.get(
        '/expense-groups/$groupId/settlements',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Get Settlements Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['settlements'] ?? [],
        };
      } else {
        String errorMessage = 'Failed to fetch settlements';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.getSettlements error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a settlement (record a payment between members)
  /// POST /api/expense-groups/:groupId/settlements
  /// 
  /// IMPORTANT: Amount is automatically calculated by the system - DO NOT send amount field
  /// 
  /// IMPORTANT PERMISSIONS:
  /// - Any group member can record settlements between any two members
  /// 
  /// Parameters:
  /// - fromEmail: Person who PAID/SENT money
  /// - toEmail: Person who RECEIVED money
  /// - settledBy: User ID or email of the person recording the settlement
  /// - notes: Optional notes about the payment
  /// 
  /// The system will:
  /// - Auto-correct direction if reversed
  /// - Calculate amount automatically based on debts
  /// - Validate that debt exists between the two members
  static Future<Map<String, dynamic>> createSettlement({
    required String groupId,
    required String fromEmail,
    required String toEmail,
    required String settledBy,
    String? notes,
    String? token,
  }) async {
    try {
      // Validation
      if (groupId.trim().isEmpty) {
        return {
          'success': false,
          'error': 'Group ID is required',
        };
      }

      final normalizedFromEmail = fromEmail.trim().toLowerCase();
      final normalizedToEmail = toEmail.trim().toLowerCase();

      if (normalizedFromEmail.isEmpty || normalizedToEmail.isEmpty) {
        return {
          'success': false,
          'error': 'Both fromEmail and toEmail are required',
        };
      }

      if (normalizedFromEmail == normalizedToEmail) {
        return {
          'success': false,
          'error': 'fromEmail and toEmail cannot be the same',
        };
      }

      // Validate email format
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(normalizedFromEmail)) {
        return {
          'success': false,
          'error': 'Invalid fromEmail format',
        };
      }
      if (!emailRegex.hasMatch(normalizedToEmail)) {
        return {
          'success': false,
          'error': 'Invalid toEmail format',
        };
      }

      debugPrint('📤 Create Settlement Request:');
      debugPrint('   Endpoint: POST /api/expense-groups/$groupId/settlements');
      debugPrint('   groupId: $groupId');
      debugPrint('   fromEmail: $normalizedFromEmail (who paid)');
      debugPrint('   toEmail: $normalizedToEmail (who received)');
      debugPrint('   settledBy: $settledBy');
      debugPrint('   notes: $notes');
      debugPrint('   ⚠️ Amount NOT sent - system will calculate automatically');

      // Determine if settledBy is an email or userId
      // If it contains @, treat as email, otherwise as userId
      final normalizedSettledBy = settledBy.trim();
      final isSettledByEmail = normalizedSettledBy.contains('@');
      
      final body = <String, dynamic>{
        'fromEmail': normalizedFromEmail,
        'toEmail': normalizedToEmail,
        // NOTE: amount is NOT included - system calculates it automatically
      };

      // Add settledBy as email if it's an email, otherwise as userId
      if (isSettledByEmail) {
        body['settledBy'] = normalizedSettledBy.toLowerCase();
      } else {
        body['settledBy'] = normalizedSettledBy;
      }

      if (notes != null && notes.trim().isNotEmpty) {
        body['notes'] = notes.trim();
      }

      debugPrint('📋 Request Body: ${json.encode(body)}');

      final response = await ApiService.post(
        '/expense-groups/$groupId/settlements',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Create Settlement Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 201 || statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data['settlement'] ?? data,
          'message': data['message'] ?? 'Settlement created successfully',
        };
      } else {
        String errorMessage = 'Failed to create settlement';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.createSettlement error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Delete a settlement
  /// DELETE /api/expense-groups/:groupId/settlements/:settlementId
  /// 
  /// PERMISSIONS:
  /// - Group creator: Can delete any settlement
  /// - Normal members: Can only delete settlements they recorded
  static Future<Map<String, dynamic>> deleteSettlement({
    required String groupId,
    required String settlementId,
    required String userId,
    String? token,
  }) async {
    try {
      debugPrint('📤 Delete Settlement Request:');
      debugPrint('   Endpoint: DELETE /api/expense-groups/$groupId/settlements/$settlementId');
      debugPrint('   groupId: $groupId');
      debugPrint('   settlementId: $settlementId');
      debugPrint('   userId: $userId');

      final body = <String, dynamic>{
        'userId': userId,
      };

      final response = await ApiService.delete(
        '/expense-groups/$groupId/settlements/$settlementId',
        body: body,
        token: token,
      );

      final statusCode = response.statusCode;

      debugPrint('📥 Delete Settlement Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');

      if (statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'message': data['message'] ?? 'Settlement deleted successfully',
        };
      } else {
        String errorMessage = 'Failed to delete settlement';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('❌ ExpenseGroupService.deleteSettlement error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

