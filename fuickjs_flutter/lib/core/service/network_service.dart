import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'base_fuick_service.dart';

class NetworkService extends BaseFuickService {
  @override
  String get name => 'Network';

  NetworkService() {
    registerAsyncMethod('fetch', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final String? url = options['url']?.toString();

        if (url == null || url.isEmpty) {
          throw Exception('URL is required for fetch');
        }

        final String method =
            (options['method']?.toString() ?? 'GET').toUpperCase();
        final Map<String, String> headers = {};
        if (options['headers'] is Map) {
          (options['headers'] as Map).forEach((key, value) {
            headers[key.toString()] = value.toString();
          });
        }
        final dynamic body = options['body'];

        http.Response response;
        final uri = Uri.parse(url);

        switch (method) {
          case 'GET':
            response = await http.get(uri, headers: headers);
            break;
          case 'POST':
            response = await http.post(uri, headers: headers, body: body);
            break;
          case 'PUT':
            response = await http.put(uri, headers: headers, body: body);
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: headers, body: body);
            break;
          case 'PATCH':
            response = await http.patch(uri, headers: headers, body: body);
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }

        return {
          'status': response.statusCode,
          'body': response.body,
          'headers': response.headers,
        };
      } catch (e, s) {
        logger.e('[NetworkService] Error in fetch: $e\n$s');
        rethrow;
      }
    });
  }
}
