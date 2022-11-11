import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiClient {
  final http.Client client;
  final String? accessToken;

  ApiClient._create(this.client, this.accessToken);

  factory ApiClient(String? accessToken) =>
      ApiClient._create(http.Client(), accessToken);

  /// Send a request to the MicroPass API server.
  Future<http.Response> send(
    String path, {
    String? body,
    required String method,
  }) async {
    // set headers to the request
    Map<String, String> headers = {
      'Accept': 'application/json',
    };

    // put access token to the request headers
    if (accessToken != null) {
      headers.putIfAbsent('Authorization', () => 'Bearer $accessToken');
    }

    // construct request URI
    var uri = Uri.https(Config.apiDomain, Config.apiPrefix + path);

    // send the request
    final http.Response response;
    if (method == 'POST') {
      headers.putIfAbsent('Content-type', () => 'application/json');
      response = await client.post(uri, body: body, headers: headers);
    } else if (method == 'GET') {
      response = await client.get(uri, headers: headers);
    } else if (method == 'DELETE') {
      response = await client.delete(uri, headers: headers);
    } else {
      throw Exception('Unknown http method: $method');
    }

    // if http status code isn't 200 throw an exception
    if (response.statusCode == 200) {
      return response;
    } else {
      final responseJson = json.decode(response.body);

      throw Exception(responseJson['error_description']);
    }
  }
}
