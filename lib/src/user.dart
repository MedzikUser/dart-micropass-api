import 'dart:convert';
import 'dart:typed_data';

import 'package:libcrypto/libcrypto.dart';

import 'client.dart';
import 'config.dart';

class UserApi {
  final ApiClient client;

  UserApi._create(this.client);

  factory UserApi(String accessToken) =>
      UserApi._create(ApiClient(accessToken));

  /// Get the user encryption key.
  Future<String> encryptionKey(String masterPassword, String email) async {
    final response = await client.send('/user/encryption_key', method: 'GET');

    final responseJson = json.decode(response.body);

    final encryptionKeyAes = responseJson['encryption_key'];

    final emailBytes = Uint8List.fromList(utf8.encode(email.toLowerCase()));

    final secretKey = await Pbkdf2(iterations: Config.masterPasswordIterations)
        .sha256(masterPassword, emailBytes);

    final encryptionKey =
        await AesCbc().decrypt(encryptionKeyAes, secretKey: secretKey);

    return encryptionKey;
  }

  /// Get the user info.
  Future<WhoamiResponse> whoami() async {
    final response = await client.send('/user/whoami', method: 'GET');

    return WhoamiResponse(response.body);
  }
}

class WhoamiResponse {
  final String id;
  final String email;
  final String username;

  WhoamiResponse._create(this.id, this.email, this.username);

  factory WhoamiResponse(String body) {
    final res = json.decode(body);
    return WhoamiResponse._create(res['id'], res['email'], res['username']);
  }
}
