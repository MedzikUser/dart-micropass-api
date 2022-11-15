import 'dart:convert';

import 'package:libcrypto/libcrypto.dart';

import 'client.dart';

class CiphersApi {
  final ApiClient client;
  final String encryptionKey;

  CiphersApi._create(this.client, this.encryptionKey);

  factory CiphersApi(String accessToken, String encryptionKey) =>
      CiphersApi._create(ApiClient(accessToken), encryptionKey);

  /// Insert a new cipher to the database.
  Future<void> insert(Cipher cipher) async {
    final encryptedCipher = await cipher.encrypt(encryptionKey);

    final body = json.encode({
      'data': encryptedCipher,
    });

    await client.send('/ciphers/insert', body: body, method: 'POST');
  }

  /// Update an existing cipher in the database.
  Future<void> update(String id, Cipher cipher) async {
    final encryptedCipher = await cipher.encrypt(encryptionKey);

    final body = json.encode({
      'id': id,
      'data': encryptedCipher,
    });

    await client.send('/ciphers/update', body: body, method: 'PATCH');
  }

  /// Get a cipher from the database.
  Future<Cipher> take(String id) async {
    final response = await client.send('/ciphers/get/$id', method: 'GET');

    final encryptedCipher = EncryptedCipher.fromJson(response.body);

    return encryptedCipher.decrypt(encryptionKey);
  }

  /// Delete a cipher from the database.
  Future<void> delete(String id) async {
    await client.send('/ciphers/delete/$id', method: 'DELETE');
  }

  /// Get all user ciphers id from the database.
  Future<List<dynamic>> list(int? lastSync) async {
    final String url;
    Map<String, dynamic>? query;

    if (lastSync == null) {
      url = '/ciphers/list';
    } else {
      url = '/ciphers/list';
      query = {'lastSync': lastSync.toString()};
    }

    final response =
        await client.send(url, method: 'GET', queryParameters: query);

    final jsonMap = json.decode(response.body);

    final ciphers = jsonMap['ciphers'];

    return ciphers;
  }
}

class Cipher {
  final String? id;
  final int type;
  final String name;
  final String? username;
  final String? password;
  final String? url;
  final String? notes;
  final String? favorite;
  final String? directoryId;
  final int? created;
  final int? updated;

  Cipher({
    this.id,
    required this.type,
    required this.name,
    this.username,
    this.password,
    this.url,
    this.notes,
    this.favorite,
    this.directoryId,
    this.created,
    this.updated,
  });

  factory Cipher.fromMap(Map<String, dynamic> map) {
    return Cipher(
      id: map["id"],
      type: map["type"],
      name: map["name"],
      username: map["username"],
      password: map["password"],
      url: map["url"],
      notes: map["notes"],
      favorite: map["favorite"],
      directoryId: map["dir"],
      created: map["created"],
      updated: map["updated"],
    );
  }

  String toJson() {
    final Map<String, dynamic> map = {
      'type': type,
      'name': name,
    };

    if (username != null) {
      map.putIfAbsent('username', () => username);
    }

    if (password != null) {
      map.putIfAbsent('password', () => password);
    }

    if (url != null) {
      map.putIfAbsent('url', () => url);
    }

    if (notes != null) {
      map.putIfAbsent('notes', () => notes);
    }

    if (favorite != null) {
      map.putIfAbsent('favorite', () => favorite);
    }

    if (directoryId != null) {
      map.putIfAbsent('dir', () => directoryId);
    }

    return json.encode(map);
  }

  /// Encrypt the cipher with the given key.
  Future<String> encrypt(String encryptionKey) async {
    final cipherJson = toJson();

    // encrypt the cipher
    final cipherText =
        await AesCbc().encrypt(cipherJson, secretKey: encryptionKey);

    // return the encrypted cipher
    return cipherText;
  }
}

class EncryptedCipher {
  final String id;
  final String data;
  final int created;
  final int updated;

  EncryptedCipher._create(this.id, this.data, this.created, this.updated);

  factory EncryptedCipher.fromJson(String jsonData) {
    final map = json.decode(jsonData);

    return EncryptedCipher._create(
      map["id"],
      map["data"],
      map["created"],
      map["updated"],
    );
  }

  Future<Cipher> decrypt(String secretKey) async {
    final clearText = await AesCbc().decrypt(data, secretKey: secretKey);

    final cipher = json.decode(clearText);

    cipher["id"] = id;
    cipher["created"] = created;
    cipher["updated"] = updated;

    return Cipher.fromMap(cipher);
  }
}

class CipherType {
  static const login = 1;
  static const secureNote = 2;
}
