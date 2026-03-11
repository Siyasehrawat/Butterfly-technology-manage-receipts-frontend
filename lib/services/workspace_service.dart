import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service_bypass.dart';

class WorkspaceService {
  // Cache for memberId per workspace to avoid repeated API calls
  static final Map<String, String> _memberIdCache = {};
  
  /// Helper function to derive memberId from userId
  /// This is used for backward compatibility when screens only have userId
  /// Tries multiple approaches to get memberId
  static Future<String?> _deriveMemberId({
    required String workspaceId,
    required String userId,
    String? token,
  }) async {
    try {
      // Check cache first
      final cacheKey = '$workspaceId:$userId';
      if (_memberIdCache.containsKey(cacheKey)) {
        return _memberIdCache[cacheKey];
      }
      
      // Approach 1: Try to get memberId from getUserWorkspaces response
      final workspacesResult = await getUserWorkspaces(
        userId: userId,
        token: token,
      );
      
      if (workspacesResult['success'] == true) {
        final workspacesData = workspacesResult['data'] as Map<String, dynamic>?;
        final workspacesList = (workspacesData?['workspaces'] ?? []) as List<dynamic>;
        
        // Find the workspace and extract memberId if available
        for (var workspace in workspacesList) {
          final workspaceMap = workspace as Map<String, dynamic>;
          final wsId = workspaceMap['id']?.toString();
          if (wsId == workspaceId) {
            // Check if memberId is directly available in workspace data
            if (workspaceMap['memberId'] != null) {
              final memberId = workspaceMap['memberId']?.toString();
              _memberIdCache[cacheKey] = memberId!;
              return memberId;
            }
            // Check if there's a member object with id
            if (workspaceMap['member'] != null) {
              final member = workspaceMap['member'] as Map<String, dynamic>?;
              if (member != null && member['id'] != null) {
                final memberId = member['id']?.toString();
                _memberIdCache[cacheKey] = memberId!;
                return memberId;
              }
            }
          }
        }
      }
      
      // If we can't derive it, return null silently
      // The calling method will try the API call anyway, and if it fails,
      // the backend will return an appropriate error
      return null;
    } catch (e) {
      debugPrint('WorkspaceService._deriveMemberId error: $e');
      return null;
    }
  }
  
  /// Cache memberId for a workspace-user combination
  /// This can be called when memberId is obtained from API responses
  static void cacheMemberId({
    required String workspaceId,
    required String userId,
    required String memberId,
  }) {
    final cacheKey = '$workspaceId:$userId';
    _memberIdCache[cacheKey] = memberId;
  }
  // ============================================================================
  // ONBOARDING APIs
  // ============================================================================

  /// Send OTP to company email
  static Future<Map<String, dynamic>> sendCompanyEmailCode({
    required String userId,
    required String companyEmail,
    String? token,
  }) async {
    try {
      debugPrint('📤 Send OTP Request:');
      debugPrint('   userId: $userId');
      debugPrint('   companyEmail: $companyEmail');
      
      final response = await ApiService.post(
        '/workspace/company-email/send-code',
        body: {
          'userId': userId,
          'companyEmail': companyEmail,
        },
        token: token,
      );
      final statusCode = response.statusCode;
      
      debugPrint('📥 Send OTP Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');
      
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to send verification code';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
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
      debugPrint('❌ WorkspaceService.sendCompanyEmailCode error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP code
  static Future<Map<String, dynamic>> verifyCompanyEmailCode({
    required String userId,
    required String companyEmail,
    required String code,
    String? token,
  }) async {
    try {
      debugPrint('📤 Verify OTP Request:');
      debugPrint('   userId: $userId');
      debugPrint('   companyEmail: $companyEmail');
      debugPrint('   code: $code');
      
      final response = await ApiService.post(
        '/workspace/company-email/verify-code',
        body: {
          'userId': userId,
          'companyEmail': companyEmail,
          'code': code,
        },
        token: token,
      );
      final statusCode = response.statusCode;
      
      debugPrint('📥 Verify OTP Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');
      
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to verify code';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
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
      debugPrint('❌ WorkspaceService.verifyCompanyEmailCode error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create new workspace
  static Future<Map<String, dynamic>> createWorkspace({
    required String userId,
    required String name,
    required String companyEmail,
    String? token,
  }) async {
    try {
      debugPrint('📤 Create Workspace Request:');
      debugPrint('   userId: $userId');
      debugPrint('   name: "$name"');
      debugPrint('   companyEmail: $companyEmail');
      
      final response = await ApiService.post(
        '/workspace',
        body: {
          'userId': userId,
          'name': name,
          'companyEmail': companyEmail,
        },
        token: token,
      );
      final statusCode = response.statusCode;
      
      debugPrint('📥 Create Workspace Response:');
      debugPrint('   Status: $statusCode');
      debugPrint('   Body: ${response.body}');
      
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        
        // Extract and cache memberId from response if available
        try {
          String? extractedMemberId;
          String? extractedWorkspaceId;
          
          // Check if memberId is directly in response
          if (data['memberId'] != null) {
            extractedMemberId = data['memberId'].toString();
          }
          // Check if there's a member object with id
          else if (data['member'] != null && data['member'] is Map) {
            final member = data['member'] as Map<String, dynamic>;
            if (member['id'] != null) {
              extractedMemberId = member['id'].toString();
            }
          }
          
          // Get workspaceId from response
          if (data['workspace'] != null && data['workspace'] is Map) {
            final workspace = data['workspace'] as Map<String, dynamic>;
            if (workspace['id'] != null) {
              extractedWorkspaceId = workspace['id'].toString();
            }
          } else if (data['id'] != null) {
            extractedWorkspaceId = data['id'].toString();
          }
          
          // Cache memberId if we have both workspaceId and memberId
          if (extractedMemberId != null && extractedWorkspaceId != null && userId != null) {
            cacheMemberId(
              workspaceId: extractedWorkspaceId,
              userId: userId,
              memberId: extractedMemberId,
            );
            debugPrint('✅ Cached memberId from createWorkspace: $extractedMemberId for workspace: $extractedWorkspaceId');
          }
        } catch (e) {
          debugPrint('⚠️ Could not extract memberId from createWorkspace response: $e');
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to create workspace';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
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
      debugPrint('❌ WorkspaceService.createWorkspace error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user's workspaces
  static Future<Map<String, dynamic>> getUserWorkspaces({
    required String userId,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '/workspace/user/workspaces?userId=$userId',
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch user workspaces',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getUserWorkspaces error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // SUBSCRIPTION & PURCHASE APIs
  // ============================================================================

  /// Initiate purchase - calculate pricing
  static Future<Map<String, dynamic>> initiatePurchase({
    required String workspaceId,
    required String userId,
    required int numberOfLicenses,
    String currency = 'INR',
    String paymentPeriod = 'monthly',  // 'monthly' or 'yearly'
    String? token,
  }) async {
    try {
      final requestBody = {
        'userId': userId,
          'numberOfLicenses': numberOfLicenses,
          'currency': currency,
          'paymentPeriod': paymentPeriod,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/subscription/initiate-purchase',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to initiate purchase',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.initiatePurchase error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Activate licenses after payment
  static Future<Map<String, dynamic>> activateLicenses({
    required String workspaceId,
    required String userId,
    required int numberOfLicenses,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required num amountPaid,
    String? token,
  }) async {
    try {
      final requestBody = {
        'userId': userId,
        'numberOfLicenses': numberOfLicenses,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'amountPaid': amountPaid,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/subscription/activate',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to activate licenses',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.activateLicenses error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // DASHBOARD & TEAM MANAGEMENT APIs
  // ============================================================================

  /// Fetch owner dashboard data for a workspace
  static Future<Map<String, dynamic>> getDashboardSummary({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      // Backend requires memberId - we must have it to proceed
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Please ensure memberId is stored when workspace is created or invite is accepted. The backend needs to return memberId in getUserWorkspaces response.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/dashboard',
        token: token,
        queryParameters: queryParams,
      );

      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        String errorMessage = 'Failed to fetch workspace dashboard';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'].toString();
          }
        } catch (_) {
          // Use default error message
        }
        
        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getDashboardSummary error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// List workspace members
  /// Note: API requires memberId query parameter
  /// If memberId is not provided, this method will try to derive it from userId
  static Future<Map<String, dynamic>> listMembers({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      // Try API call - include memberId if we have it, otherwise backend might derive it from auth token
      final queryParams = <String, String>{
        if (finalMemberId != null) 'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/members',
        token: token,
        queryParameters: queryParams,
      );
      
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        
        // If successful and we didn't have memberId, try to extract and cache it from response
        if (finalMemberId == null && userId != null) {
          try {
            final membersList = (data['members'] ?? []) as List<dynamic>;
            // Find the member with matching userId and cache its id
            for (var member in membersList) {
              final memberMap = member as Map<String, dynamic>;
              final memberUserId = memberMap['userId']?.toString();
              if (memberUserId == userId) {
                final extractedMemberId = memberMap['id']?.toString() ?? memberMap['memberId']?.toString();
                if (extractedMemberId != null) {
                  cacheMemberId(
                    workspaceId: workspaceId,
                    userId: userId,
                    memberId: extractedMemberId,
                  );
                  break;
                }
              }
            }
          } catch (_) {
            // Ignore errors when trying to extract memberId
          }
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        // Only return error if API call actually failed
        String errorMessage = 'Failed to fetch workspace members';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'].toString();
          }
        } catch (_) {
          // Use default error message
        }
        
        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listMembers error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add a workspace member
  static Future<Map<String, dynamic>> addMember({
    required String workspaceId,
    required String userId,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final requestBody = {
        'userId': userId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/members',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to add workspace member',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.addMember error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update workspace member
  static Future<Map<String, dynamic>> updateMember({
    required String workspaceId,
    required String memberId,
    String? requesterMemberId,
    String? userId, // Used to derive requesterMemberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires requesterMemberId, not userId
      String? finalRequesterMemberId = requesterMemberId;
      
      if (finalRequesterMemberId == null && userId != null) {
        finalRequesterMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalRequesterMemberId == null) {
        return {
          'success': false,
          'error': 'requesterMemberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'requesterMemberId': finalRequesterMemberId,
        ...body,
      };

      final response = await ApiService.patch(
        '/workspace/$workspaceId/members/$memberId',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to update workspace member',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.updateMember error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Remove workspace member
  static Future<Map<String, dynamic>> removeMember({
    required String workspaceId,
    required String memberId,
    String? requesterMemberId,
    String? userId, // Used to derive requesterMemberId if not provided
    String? message,
    String? token,
  }) async {
    try {
      // API requires requesterMemberId, not userId
      String? finalRequesterMemberId = requesterMemberId;
      
      if (finalRequesterMemberId == null && userId != null) {
        finalRequesterMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalRequesterMemberId == null) {
        return {
          'success': false,
          'error': 'requesterMemberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'requesterMemberId': finalRequesterMemberId,
        if (message != null) 'message': message,
      };

      final response = await ApiService.delete(
        '/workspace/$workspaceId/members/$memberId',
        token: token,
        body: requestBody,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        return {
          'success': true,
          'statusCode': statusCode,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to remove workspace member',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.removeMember error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create invite
  /// API: POST /api/workspace/:workspaceId/invites
  /// Request Body: requesterMemberId (required), email, name, role
  static Future<Map<String, dynamic>> createInvite({
    required String workspaceId,
    String? requesterMemberId,
    String? userId, // Used to derive requesterMemberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires requesterMemberId, not userId
      String? finalRequesterMemberId = requesterMemberId;
      
      if (finalRequesterMemberId == null && userId != null) {
        finalRequesterMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalRequesterMemberId == null) {
        return {
          'success': false,
          'error': 'requesterMemberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'requesterMemberId': finalRequesterMemberId,
        'email': body['email'],
        if (body['name'] != null) 'name': body['name'],
        if (body['role'] != null) 'role': body['role'],
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/invites',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        final errorBody = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : null;
        final errorMessage = errorBody?['message'] ?? 
                            errorBody?['error'] ?? 
                            'Failed to create workspace invite';
        return {
          'success': false,
          'statusCode': statusCode,
          'error': errorMessage,
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createInvite error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get invite by token
  static Future<Map<String, dynamic>> getInviteByToken({
    required String tokenParam,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '/workspace/invites/$tokenParam',
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch invite',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getInviteByToken error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Accept invite
  static Future<Map<String, dynamic>> acceptInvite({
    required String tokenParam,
    required String userId,
    String? token,
  }) async {
    try {
      final requestBody = {'userId': userId};

      final response = await ApiService.post(
        '/workspace/invites/$tokenParam/accept',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        
        // Extract and cache memberId from response if available
        try {
          String? extractedMemberId;
          String? extractedWorkspaceId;
          
          // Check if memberId is directly in response
          if (data['memberId'] != null) {
            extractedMemberId = data['memberId'].toString();
          }
          // Check if there's a member object with id
          else if (data['member'] != null && data['member'] is Map) {
            final member = data['member'] as Map<String, dynamic>;
            if (member['id'] != null) {
              extractedMemberId = member['id'].toString();
            }
          }
          
          // Get workspaceId from response
          if (data['workspace'] != null && data['workspace'] is Map) {
            final workspace = data['workspace'] as Map<String, dynamic>;
            if (workspace['id'] != null) {
              extractedWorkspaceId = workspace['id'].toString();
            }
          } else if (data['workspaceId'] != null) {
            extractedWorkspaceId = data['workspaceId'].toString();
          }
          
          // Cache memberId if we have both workspaceId and memberId
          if (extractedMemberId != null && extractedWorkspaceId != null && userId != null) {
            cacheMemberId(
              workspaceId: extractedWorkspaceId,
              userId: userId,
              memberId: extractedMemberId,
            );
            debugPrint('✅ Cached memberId from acceptInvite: $extractedMemberId for workspace: $extractedWorkspaceId');
          }
        } catch (e) {
          debugPrint('⚠️ Could not extract memberId from acceptInvite response: $e');
        }
        
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to accept invite',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.acceptInvite error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// List workspace invites
  static Future<Map<String, dynamic>> listInvites({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/invites',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to list workspace invites',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listInvites error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get current workspace subscription
  static Future<Map<String, dynamic>> getSubscription({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/subscription',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch workspace subscription',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getSubscription error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get available workspace plans
  static Future<Map<String, dynamic>> getPlans({
    required String workspaceId,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '/workspace/$workspaceId/plans',
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch workspace plans',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getPlans error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Upgrade workspace subscription
  static Future<Map<String, dynamic>> upgradeSubscription({
    required String workspaceId,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final response = await ApiService.post(
        '/workspace/$workspaceId/subscription/upgrade',
        body: body,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to upgrade workspace subscription',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.upgradeSubscription error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // STRIPE PAYMENT APIs
  // ============================================================================

  /// Get public pricing (no workspace required)
  static Future<Map<String, dynamic>> getPublicPricing({
    String currency = 'all', // 'all', 'INR', or 'USD'
    String? token,
  }) async {
    try {
      final queryParams = <String, String>{
        'currency': currency,
      };

      final response = await ApiService.get(
        '/workspace/pricing/public',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch public pricing',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getPublicPricing error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get workspace pricing
  static Future<Map<String, dynamic>> getWorkspacePricing({
    required String workspaceId,
    String currency = 'USD', // 'INR' or 'USD'
    String? token,
  }) async {
    try {
      final queryParams = <String, String>{
        'currency': currency,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/payment/stripe/pricing',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch workspace pricing',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getWorkspacePricing error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Calculate upgrade pricing
  static Future<Map<String, dynamic>> calculateUpgradePricing({
    required String workspaceId,
    required int currentLicenses,
    required int additionalLicenses,
    required String currency,
    required String paymentPeriod, // 'monthly' or 'yearly'
    String? token,
  }) async {
    try {
      final requestBody = {
        'currentLicenses': currentLicenses,
        'additionalLicenses': additionalLicenses,
        'currency': currency,
        'paymentPeriod': paymentPeriod,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/payment/stripe/calculate-upgrade',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to calculate upgrade pricing',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.calculateUpgradePricing error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create Stripe payment intent
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String workspaceId,
    required String memberId,
    required int numberOfLicenses,
    required String currency,
    required String paymentPeriod, // 'monthly' or 'yearly'
    String? token,
  }) async {
    try {
      final requestBody = {
        'memberId': memberId,
        'numberOfLicenses': numberOfLicenses,
        'currency': currency,
        'paymentPeriod': paymentPeriod,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/payment/stripe/create-intent',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to create payment intent',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createPaymentIntent error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create Stripe subscription
  static Future<Map<String, dynamic>> createSubscription({
    required String workspaceId,
    required String memberId,
    required int numberOfLicenses,
    required String currency,
    required String paymentPeriod, // 'monthly' or 'yearly'
    String? token,
  }) async {
    try {
      final requestBody = {
        'memberId': memberId,
        'numberOfLicenses': numberOfLicenses,
        'currency': currency,
        'paymentPeriod': paymentPeriod,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/payment/stripe/create-subscription',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to create subscription',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createSubscription error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get Stripe subscription status
  static Future<Map<String, dynamic>> getSubscriptionStatus({
    required String workspaceId,
    required String memberId,
    String? token,
  }) async {
    try {
      final queryParams = <String, String>{
        'memberId': memberId,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/subscription/stripe-status',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch subscription status',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getSubscriptionStatus error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Custom plan request
  /// Note: API requires memberId in request body, not userId
  static Future<Map<String, dynamic>> createCustomPlanRequest({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/custom-plan-request',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to submit custom plan request',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createCustomPlanRequest error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Analytics summary
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/analytics/summary',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch analytics summary',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getAnalyticsSummary error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Spend over time
  static Future<Map<String, dynamic>> getSpendOverTime({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/analytics/spend',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        try {
          final decoded = json.decode(response.body);
          debugPrint('📥 Spend response type: ${decoded.runtimeType}');
          
          // Ensure data is always a Map, handle List or other types
          Map<String, dynamic> data;
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          } else if (decoded is Map) {
            // Handle non-typed Map (e.g., Map<dynamic, dynamic> or JSObject)
            try {
              data = Map<String, dynamic>.from(decoded);
            } catch (e) {
              debugPrint('⚠️ Could not convert Map, using empty: $e');
              data = {'data': {'byDate': []}};
            }
          } else if (decoded is List) {
            // If API returns a list, wrap it in a map
            data = {'data': {'byDate': decoded}, 'byDate': decoded};
          } else {
            debugPrint('⚠️ Unexpected response type: ${decoded.runtimeType}');
            data = {'data': {'byDate': []}};
          }
          return {
            'success': true,
            'statusCode': statusCode,
            'data': data,
          };
        } catch (e) {
          debugPrint('❌ Error decoding spend response: $e');
          debugPrint('❌ Response body: ${response.body}');
          return {
            'success': false,
            'statusCode': statusCode,
            'error': 'Failed to parse spend response: $e',
            'raw': response.body,
          };
        }
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch spend over time',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getSpendOverTime error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Expenses breakdown
  static Future<Map<String, dynamic>> getExpensesBreakdown({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/analytics/expenses',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        try {
          final decoded = json.decode(response.body);
          debugPrint('📥 Expenses response type: ${decoded.runtimeType}');
          
          // Ensure data is always a Map, handle List or other types
          Map<String, dynamic> data;
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          } else if (decoded is Map) {
            // Handle non-typed Map (e.g., Map<dynamic, dynamic> or JSObject)
            try {
              data = Map<String, dynamic>.from(decoded);
            } catch (e) {
              debugPrint('⚠️ Could not convert Map, using empty: $e');
              data = {'breakdown': []};
            }
          } else if (decoded is List) {
            // If API returns a list, wrap it in a map with breakdown key
            data = {'breakdown': decoded};
          } else {
            debugPrint('⚠️ Unexpected response type: ${decoded.runtimeType}');
            data = {'breakdown': []};
          }
          return {
            'success': true,
            'statusCode': statusCode,
            'data': data,
          };
        } catch (e) {
          debugPrint('❌ Error decoding expenses response: $e');
          debugPrint('❌ Response body: ${response.body}');
          return {
            'success': false,
            'statusCode': statusCode,
            'error': 'Failed to parse expenses response: $e',
            'raw': response.body,
          };
        }
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch expenses breakdown',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getExpensesBreakdown error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// List approvals
  static Future<Map<String, dynamic>> listApprovals({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/approvals',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch approvals',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listApprovals error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update approval status
  static Future<Map<String, dynamic>> updateApprovalStatus({
    required String workspaceId,
    required String approvalId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.patch(
        '/workspace/$workspaceId/approvals/$approvalId',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to update approval status',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.updateApprovalStatus error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // DASHBOARDS
  // ============================================================================

  /// Fetch user dashboard data
  static Future<Map<String, dynamic>> getUserDashboard({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };
      final response = await ApiService.get(
        '/workspace/$workspaceId/user-dashboard',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch user dashboard',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getUserDashboard error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fetch manager dashboard data
  static Future<Map<String, dynamic>> getManagerDashboard({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };
      final response = await ApiService.get(
        '/workspace/$workspaceId/manager-dashboard',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch manager dashboard',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getManagerDashboard error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // EXPENSE REPORTS
  // ============================================================================

  /// List expense reports
  static Future<Map<String, dynamic>> listExpenseReports({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/expense-reports',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch expense reports',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listExpenseReports error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get single expense report
  static Future<Map<String, dynamic>> getExpenseReport({
    required String workspaceId,
    required String reportId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/expense-reports/$reportId',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch expense report',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getExpenseReport error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create expense report
  static Future<Map<String, dynamic>> createExpenseReport({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/expense-reports',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to create expense report',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createExpenseReport error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update expense report
  static Future<Map<String, dynamic>> updateExpenseReport({
    required String workspaceId,
    required String reportId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.patch(
        '/workspace/$workspaceId/expense-reports/$reportId',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to update expense report',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.updateExpenseReport error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // ACTIVITY FEED
  // ============================================================================

  /// List workspace activities
  static Future<Map<String, dynamic>> listActivities({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/activities',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch activities',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listActivities error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create workspace activity entry
  static Future<Map<String, dynamic>> createActivity({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/activities',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to create activity',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createActivity error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // RECEIPTS
  // ============================================================================

  /// List workspace receipts
  static Future<Map<String, dynamic>> listWorkspaceReceipts({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/receipts',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch workspace receipts',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listWorkspaceReceipts error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// List all workspace receipts (Managers/Owners only)
  static Future<Map<String, dynamic>> listAllWorkspaceReceipts({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/receipts/all',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch all workspace receipts',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listAllWorkspaceReceipts error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Submit workspace receipt
  static Future<Map<String, dynamic>> submitWorkspaceReceipt({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/receipts',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to submit workspace receipt',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.submitWorkspaceReceipt error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // NEEDS / RESOURCE REQUESTS
  // ============================================================================

  /// List needs/resource requests
  static Future<Map<String, dynamic>> listNeedsRequests({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    Map<String, String>? query,
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (query != null) ...query,
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/needs-requests',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch needs requests',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.listNeedsRequests error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create needs/resource request
  static Future<Map<String, dynamic>> createNeedsRequest({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.post(
        '/workspace/$workspaceId/needs-requests',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to create needs request',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.createNeedsRequest error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update needs/resource request
  static Future<Map<String, dynamic>> updateNeedsRequest({
    required String workspaceId,
    required String requestId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final requestBody = <String, dynamic>{
        'memberId': finalMemberId,
        ...body,
      };

      final response = await ApiService.patch(
        '/workspace/$workspaceId/needs-requests/$requestId',
        body: requestBody,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to update needs request',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.updateNeedsRequest error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // OWNER PENDING APPROVALS
  // ============================================================================

  /// Fetch pending approvals for owner
  static Future<Map<String, dynamic>> getOwnerPendingApprovals({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/owner/pending-approvals',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch owner pending approvals',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getOwnerPendingApprovals error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fetch pending approvals for manager
  static Future<Map<String, dynamic>> getManagerPendingApprovals({
    required String workspaceId,
    String? memberId,
    String? userId, // Used to derive memberId if not provided
    int? page,
    int? pageSize,
    String? token,
  }) async {
    try {
      // API requires memberId, not userId
      String? finalMemberId = memberId;
      
      if (finalMemberId == null && userId != null) {
        finalMemberId = await _deriveMemberId(
          workspaceId: workspaceId,
          userId: userId,
          token: token,
        );
      }
      
      if (finalMemberId == null) {
        return {
          'success': false,
          'error': 'memberId is required. Unable to determine memberId from workspace.',
          'statusCode': 400,
        };
      }
      
      final queryParams = <String, String>{
        'memberId': finalMemberId,
        if (page != null) 'page': page.toString(),
        if (pageSize != null) 'pageSize': pageSize.toString(),
      };

      final response = await ApiService.get(
        '/workspace/$workspaceId/manager/pending-approvals',
        token: token,
        queryParameters: queryParams,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to fetch manager pending approvals',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.getManagerPendingApprovals error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================================
  // RAZORPAY WEBHOOK (test helper)
  // ============================================================================

  /// Trigger Razorpay webhook (for testing)
  static Future<Map<String, dynamic>> triggerRazorpayWebhook({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    try {
      final response = await ApiService.post(
        '/workspace/razorpay/webhook',
        body: payload,
        token: token,
      );
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'statusCode': statusCode,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'error': 'Failed to trigger Razorpay webhook',
          'raw': response.body,
        };
      }
    } catch (e, st) {
      debugPrint('WorkspaceService.triggerRazorpayWebhook error: $e\n$st');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}



