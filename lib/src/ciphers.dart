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
  Future<CipherListResponse> list(int? lastSync) async {
    final String url;
    Map<String, dynamic>? query;

    if (lastSync == null) {
      url = '/ciphers/list';
    } else {
      url = '/ciphers/list';
      query = {
        'lastSync': lastSync.toString(),
      };
    }

    final response =
        await client.send(url, method: 'GET', queryParameters: query);

    final jsonMap = json.decode(response.body);

    List<String>? updated;
    List<String>? deleted;

    if (jsonMap['updated'] != null) {
      updated = List<String>.from(jsonMap['updated']);
    }

    if (jsonMap['deleted'] != null) {
      deleted = List<String>.from(jsonMap['deleted']);
    }

    return CipherListResponse(updated, deleted);
  }
}

class CipherListResponse {
  final List<String>? updated;
  final List<String>? deleted;

  CipherListResponse(this.updated, this.deleted);
}

class Cipher {
  String id;
  String? favorite;
  String? directory;
  CipherData data;
  int created;
  int updated;

  Cipher({
    this.id = '',
    required this.data,
    this.favorite,
    this.directory,
    this.created = 0,
    this.updated = 0,
  });

  factory Cipher.fromMap(Map<String, dynamic> map) {
    return Cipher(
      id: map['id'] ?? '',
      data: CipherData.fromMap(Map<String, dynamic>.from(map['data'])),
      favorite: map['favorite'],
      directory: map['dir'],
      created: map['created'] ?? 0,
      updated: map['updated'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'data': data.toMap(),
    };

    if (id != '') map['id'] = id;
    if (created != 0) map['created'] = created;
    if (updated != 0) map['updated'] = updated;

    if (directory != null) {
      map.putIfAbsent('dir', () => directory);
    }

    if (favorite != null) {
      map.putIfAbsent('favorite', () => favorite);
    }

    return map;
  }

  String toJson() {
    final map = toMap();

    return json.encode(map);
  }

  /// Encrypt the cipher with the given key.
  Future<String> encrypt(String encryptionKey) async {
    final clearText = toJson();

    // encrypt the cipher
    final cipherText =
        await AesCbc().encrypt(clearText, secretKey: encryptionKey);

    // return the encrypted cipher
    return cipherText;
  }
}

class CipherData {
  int type;
  String name;
  String? note;
  Map<String, String> fields;
  TypedFields? typedFields;

  CipherData({
    required this.type,
    required this.name,
    this.note,
    this.fields = const {},
    this.typedFields,
  });

  factory CipherData.fromMap(Map<String, dynamic> map) {
    return CipherData(
      type: map['type'],
      name: map['name'],
      note: map['note'],
      fields: Map<String, String>.from(map['fields']),
      typedFields: TypedFields.fromMap(map['fields']),
    );
  }

  factory CipherData.fromJson(String jsonString) {
    final map = json.decode(jsonString);

    return CipherData.fromMap(map);
  }

  Map<String, dynamic> toMap() {
    // copy the fields map, as the fields map is immutable
    final fields = Map.from(this.fields);

    // add the typed fields to the fields map
    if (typedFields != null) {
      fields.addAll(typedFields!.toMap());
    }

    final Map<String, dynamic> map = {
      'type': type,
      'name': name,
      'fields': fields,
    };

    if (note != null) map['note'] = note;

    return map;
  }

  String toJson() {
    final map = toMap();
    final jsonString = json.encode(map);

    return jsonString;
  }
}

class TypedFields {
  final String? username;
  final String? password;
  final String? otpauth;
  final String? url;

  TypedFields({
    this.username,
    this.password,
    this.otpauth,
    this.url,
  });

  factory TypedFields.fromMap(Map<String, dynamic> map) {
    return TypedFields(
      username: map['username'],
      password: map['password'],
      otpauth: map['otpauth'],
      url: map['url'],
    );
  }

  Map<String, String> toMap() {
    final Map<String, String> map = {};

    if (username != null) map['username'] = username!;
    if (password != null) map['password'] = password!;
    if (otpauth != null) map['otpauth'] = otpauth!;
    if (url != null) map['url'] = url!;

    return map;
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

    final cipherMap = json.decode(clearText);
    final cipher = Cipher.fromMap(cipherMap);

    cipher.id = id;
    cipher.created = created;
    cipher.updated = updated;

    return cipher;
  }
}

class CipherType {
  static const login = 1;
  static const secureNote = 2;
}
