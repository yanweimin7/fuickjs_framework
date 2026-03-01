import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'base_fuick_service.dart';

class NetworkService extends BaseFuickService {
  @override
  String get name => 'Network';

  final Map<String, http.Client> _activeRequests = {};

  NetworkService() {
    registerAsyncMethod('fetch', (args) async {
      String? requestId;
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final String? url = options['url']?.toString();
        requestId = options['requestId']?.toString();

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

        final client = http.Client();
        if (requestId != null) {
          _activeRequests[requestId] = client;
        }

        http.Response response;
        final uri = Uri.parse(url);

        try {
          switch (method) {
            case 'GET':
              response = await client.get(uri, headers: headers);
              break;
            case 'POST':
              response = await client.post(uri, headers: headers, body: body);
              break;
            case 'PUT':
              response = await client.put(uri, headers: headers, body: body);
              break;
            case 'DELETE':
              response = await client.delete(uri, headers: headers, body: body);
              break;
            case 'PATCH':
              response = await client.patch(uri, headers: headers, body: body);
              break;
            default:
              throw Exception('Unsupported HTTP method: $method');
          }
        } finally {
          if (requestId != null) {
            _activeRequests.remove(requestId);
          }
          client.close();
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

    registerMethod('cancel', (args) {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? requestId = options['requestId']?.toString();
      if (requestId != null) {
        final client = _activeRequests.remove(requestId);
        if (client != null) {
          logger.i('[NetworkService] Cancelling request: $requestId');
          client.close();
          return true;
        }
      }
      return false;
    });
  }
}
