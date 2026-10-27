// Real API responses (test/contract/fixtures) for screen tests, and a signed-in
// session built from them, so screens are tested with the API's actual shapes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenroot_mobile/core/network/api_client.dart';
import 'package:greenroot_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:greenroot_mobile/features/auth/data/models/user_models.dart';
import 'package:greenroot_mobile/features/auth/data/models/workspace_model.dart';
import 'package:greenroot_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:greenroot_mobile/features/auth/presentation/providers/session_provider.dart';

/// A fresh copy of a captured response; tests may change it freely.
dynamic fixture(String name) =>
    jsonDecode(File('test/contract/fixtures/$name.json').readAsStringSync());

class _SignedIn extends SessionNotifier {
  _SignedIn(SessionState s)
      : super(AuthRepository(AuthRemoteDataSource(ApiClient.instance))) {
    state = s;
  }
}

/// Signed in as the dev cast's nursery owner ('owner'), manager ('manager')
/// or customer ('buyer').
Override signedInAs(String who) {
  final user = UserProfile.fromJson(
    fixture(switch (who) {
      'owner' => 'users_me_owner',
      'manager' => 'users_me_manager',
      _ => 'users_me',
    }) as Map<String, dynamic>,
  );
  final workspaces = (fixture('workspaces_$who') as List)
      .cast<Map<String, dynamic>>()
      .map(Workspace.fromJson)
      .toList();
  return sessionProvider.overrideWith(
    (ref) => _SignedIn(
      SessionState(
        status: SessionStatus.authenticated,
        user: user,
        workspaces: workspaces,
        nurseryId:
            workspaces.map((w) => w.nurseryId).whereType<int>().firstOrNull,
      ),
    ),
  );
}
