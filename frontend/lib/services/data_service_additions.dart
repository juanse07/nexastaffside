  /// Validate an invite code and return team information
  Future<Map<String, dynamic>> validateInviteCode(String code) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (userKey != null) headers['x-user-key'] = userKey;

    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/validate/$code',
    );

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } else if (response.statusCode == 404) {
      throw Exception('Invalid or expired invite code');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final error = data['error'] ?? 'Invalid invite code';
      throw Exception(error);
    } else {
      throw Exception('Failed to validate invite code (${response.statusCode})');
    }
  }

  /// Redeem an invite code to join a team
  Future<void> redeemInviteCode(String code) async {
    final token = await _safeStorageRead('auth_jwt');
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final userKey = _decodeUserKeyFromToken(token);
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (userKey != null) headers['x-user-key'] = userKey;

    final uri = Uri.parse(
      '$_apiBaseUrl$_apiPathPrefix/invites/redeem',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode({'code': code}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Refresh teams and events after successful redemption
      await _fetchMyTeams(silent: true);
      await _fetchEvents(silent: true, forceFullSync: true);
      notifyListeners();
    } else if (response.statusCode == 404) {
      throw Exception('Invalid or expired invite code');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final error = data['error'] ?? 'Failed to join team';
      throw Exception(error);
    } else {
      throw Exception('Failed to join team (${response.statusCode})');
    }
  }
