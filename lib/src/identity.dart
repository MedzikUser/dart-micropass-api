import 'dart:convert';
import 'dart:typed_data';

import 'package:libcrypto/libcrypto.dart';

import 'client.dart';
import 'config.dart';

class IdentityApi {
  final ApiClient client;

  IdentityApi._create(this.client);

  factory IdentityApi() => IdentityApi._create(ApiClient(null));

  final hash = Pbkdf2(iterations: Config.masterPasswordIterations);

  /// Send login request to the AwesomeVault API.
  Future<AuthResponse> login(String email, String masterPassword) async {
    email = email.toLowerCase();
    final emailBytes = Uint8List.fromList(utf8.encode(email));

    final masterPasswordHash = await hash.sha256(masterPassword, emailBytes);
    final masterPasswordHashFinal =
        await Pbkdf2(iterations: 1).sha512(masterPasswordHash, emailBytes);

    final String body = json.encode({
      'grant_type': 'password',
      'email': email,
      'password': masterPasswordHashFinal,
    });

    final response = await client.send(
      '/identity/token',
      body: body,
      method: 'POST',
    );

    final responseJson = json.decode(response.body);

    return AuthResponse(
      accessToken: responseJson['access_token'],
      refreshToken: responseJson['refresh_token'],
    );
  }

  /// Send register request to the AwesomeVault API.
  Future<void> register(
    String email,
    String masterPassword,
    String? masterPasswordHint,
  ) async {
    email = email.toLowerCase();

    final emailBytes = Uint8List.fromList(utf8.encode(email));
    final String masterPasswordBaseHash =
        await hash.sha256(masterPassword, emailBytes);

    // generate salt for encryption key
    final salt = Salt(32).generate();

    // make one iteration of the password with a different salt
    final String encryptionKey =
        await Pbkdf2(iterations: 1).sha256(masterPasswordBaseHash, salt);

    // encrypt the encryption key using the master password to pass it to AwesomeVault server
    final String encryptionKeyAes = await AesCbc()
        .encrypt(encryptionKey, secretKey: masterPasswordBaseHash);

    // do one more iteration because the previous key was used for encryption key
    final String masterPasswordHash =
        await Pbkdf2(iterations: 1).sha512(masterPasswordBaseHash, emailBytes);

    final body = json.encode({
      'email': email,
      'password': masterPasswordHash,
      'encryption_key': encryptionKeyAes,
      'password_hint': masterPasswordHint,
    });

    await client.send(
      '/identity/register',
      body: body,
      method: 'POST',
    );
  }

  /// Refresh the access token.
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final String body = json.encode({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });

    final response = await client.send(
      '/identity/token',
      body: body,
      method: 'POST',
    );

    final responseJson = json.decode(response.body);

    return AuthResponse(
      accessToken: responseJson['access_token'],
      refreshToken: responseJson['refresh_token'],
    );
  }
}

class AuthResponse {
  String? accessToken;
  String? refreshToken;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
  });
}
