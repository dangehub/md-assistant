import 'dart:io';
import 'dart:convert';
import 'package:obsi/src/screens/settings/settings_service.dart';

class n8nWebHook {
  static Future<HttpClientResponse> get(String uri) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(uri));
    final response = await request.close();
    // Don't close the client here - let the caller read the response first
    // The client will be closed automatically when the response is consumed
    return response;
  }

  static Future<HttpClientResponse> post(String uri, [Object? jsonBody]) async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(uri));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (jsonBody != null) {
      request.add(utf8.encode(json.encode(jsonBody)));
    }
    final response = await request.close();
    // Don't close the client here - let the caller read the response first
    // The client will be closed automatically when the response is consumed
    return response;
  }
}
