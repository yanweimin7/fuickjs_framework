import 'dart:convert';

import 'package:dio/dio.dart';
import '../logger.dart';
import 'base_fuick_service.dart';

class NetworkService extends BaseFuickService {
  @override
  String get name => 'Network';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  final Map<String, CancelToken> _activeRequests = {};

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
        final Map<String, dynamic> headers = {};
        if (options['headers'] is Map) {
          (options['headers'] as Map).forEach((key, value) {
            headers[key.toString()] = value.toString();
          });
        }
        final dynamic body = options['body'];

        final cancelToken = CancelToken();
        if (requestId != null) {
          _activeRequests[requestId] = cancelToken;
        }

        Response response;
        try {
          final dioOptions = Options(
            method: method,
            headers: headers,
          );

          response = await _dio.request(
            url,
            data: body,
            options: dioOptions,
            cancelToken: cancelToken,
          );
        } finally {
          if (requestId != null) {
            _activeRequests.remove(requestId);
          }
        }

        final responseHeaders = <String, String>{};
        response.headers.forEach((key, values) {
          responseHeaders[key] = values.join(', ');
        });

        return {
          'status': response.statusCode ?? 0,
          'body': response.data is String
              ? response.data
              : jsonEncode(response.data),
          'headers': responseHeaders,
        };
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          logger.i('[NetworkService] Request cancelled');
          return {
            'status': -1,
            'body': 'Request cancelled',
            'headers': {},
          };
        }
        final statusCode = e.response?.statusCode ?? 0;
        final responseBody = e.response?.data is String
            ? e.response!.data
            : jsonEncode(e.response?.data) ?? e.message ?? 'Unknown error';
        logger.e('[NetworkService] Dio error: ${e.message}, status: $statusCode');
        return {
          'status': statusCode,
          'body': responseBody,
          'headers': {},
        };
      } catch (e, s) {
        logger.e('[NetworkService] Error in fetch: $e\n$s');
        rethrow;
      }
    });

    // uploadFile: multipart 文件上传
    registerAsyncMethod('uploadFile', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final String? url = options['url']?.toString();
        final String? filePath = options['filePath']?.toString();
        final String name = options['name']?.toString() ?? 'file';
        final Map<String, dynamic> formData = {};
        if (options['formData'] is Map) {
          (options['formData'] as Map).forEach((key, value) {
            formData[key.toString()] = value.toString();
          });
        }
        final Map<String, dynamic> headers = {};
        if (options['header'] is Map) {
          (options['header'] as Map).forEach((key, value) {
            headers[key.toString()] = value.toString();
          });
        }

        if (url == null || url.isEmpty) {
          throw Exception('URL is required for uploadFile');
        }
        if (filePath == null || filePath.isEmpty) {
          throw Exception('filePath is required for uploadFile');
        }

        final file = await MultipartFile.fromFile(filePath, filename: filePath.split('/').last);
        final data = FormData.fromMap({
          ...formData,
          name: file,
        });

        final response = await _dio.post(url, data: data, options: Options(headers: headers));

        return {
          'statusCode': response.statusCode ?? 0,
          'data': response.data is String ? response.data : jsonEncode(response.data),
        };
      } catch (e) {
        logger.e('[NetworkService] uploadFile error: $e');
        rethrow;
      }
    });

    // downloadFile: 下载文件到本地
    registerAsyncMethod('downloadFile', (args) async {
      try {
        final Map<dynamic, dynamic> options = args is Map ? args : {};
        final String? url = options['url']?.toString();
        final String? filePath = options['filePath']?.toString();
        final Map<String, dynamic> headers = {};
        if (options['header'] is Map) {
          (options['header'] as Map).forEach((key, value) {
            headers[key.toString()] = value.toString();
          });
        }

        if (url == null || url.isEmpty) {
          throw Exception('URL is required for downloadFile');
        }
        if (filePath == null || filePath.isEmpty) {
          throw Exception('filePath is required for downloadFile');
        }

        final response = await _dio.download(url, filePath, options: Options(headers: headers));

        return {
          'statusCode': response.statusCode ?? 0,
          'filePath': filePath,
          'tempFilePath': filePath,
        };
      } catch (e) {
        logger.e('[NetworkService] downloadFile error: $e');
        rethrow;
      }
    });

    registerMethod('cancel', (args) {
      final Map<dynamic, dynamic> options = args is Map ? args : {};
      final String? requestId = options['requestId']?.toString();
      if (requestId != null) {
        final cancelToken = _activeRequests.remove(requestId);
        if (cancelToken != null) {
          logger.i('[NetworkService] Cancelling request: $requestId');
          cancelToken.cancel('User cancelled');
          return true;
        }
      }
      return false;
    });
  }
}
