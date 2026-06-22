import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
part 'network_response.dart';

typedef AccessTokenGetter = FutureOr<String?> Function();
typedef RefreshTokenGetter = FutureOr<String?> Function();

typedef TokenRefreshSaver = FutureOr<void> Function({
  required String accessToken,
  String? refreshToken,
});

typedef TokenClearer = FutureOr<void> Function();

typedef RefreshTokenBodyBuilder = Map<String, dynamic> Function(
  String refreshToken,
);

typedef TokenExtractor = String? Function(Map<String, dynamic> responseData);

class NetworkClient {
  static const String _requiresAuthKey = 'requires_auth';
  static const String _isRetryKey = 'is_retry';
  static const String _manualTokenKey = 'manual_token';

  final String _defaultErrorMessage;

  final VoidCallback onUnauthorized;

  final AccessTokenGetter? getAccessToken;
  final RefreshTokenGetter? getRefreshToken;
  final TokenRefreshSaver? onTokenRefreshed;
  final TokenClearer? onTokenClear;

  final String? refreshTokenEndpoint;
  final RefreshTokenBodyBuilder? refreshTokenBodyBuilder;
  final TokenExtractor? accessTokenExtractor;
  final TokenExtractor? refreshTokenExtractor;

  late final Dio _dio;
  late final Dio _refreshDio;

  final Logger _logger;

  Completer<String?>? _refreshCompleter;

  Dio get dio => _dio;

  NetworkClient({
    required String baseUrl,
    required this.onUnauthorized,

    /// Token callbacks
    this.getAccessToken,
    this.getRefreshToken,
    this.onTokenRefreshed,
    this.onTokenClear,

    /// Refresh token config
    this.refreshTokenEndpoint,
    this.refreshTokenBodyBuilder,
    this.accessTokenExtractor,
    this.refreshTokenExtractor,

    /// Optional
    String defaultErrorMessage = 'Something went wrong!!!!',
    bool enableLogger = true,
    bool useDioBuiltInLogger = false,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
    Logger? logger,
  })  : _defaultErrorMessage = defaultErrorMessage,
        _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 2,
                errorMethodCount: 8,
                lineLength: 120,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
              ),
            ) {
    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: {
        Headers.acceptHeader: Headers.jsonContentType,
      },
    );

    _dio = Dio(baseOptions);

    /// Separate Dio for refresh token API.
    /// Important: refresh API should not use the same auth interceptor,
    /// otherwise infinite loop can happen.
    _refreshDio = Dio(baseOptions);

    _addInterceptors(
      enableLogger: enableLogger,
      useDioBuiltInLogger: useDioBuiltInLogger,
    );
  }

  void _addInterceptors({
    required bool enableLogger,
    required bool useDioBuiltInLogger,
  }) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = options.extra[_requiresAuthKey] != false;

          if (requiresAuth && !_hasAuthorizationHeader(options.headers)) {
            final manualToken = options.extra[_manualTokenKey] as String?;
            final token = manualToken ?? await getAccessToken?.call();

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;

          final requiresAuth = requestOptions.extra[_requiresAuthKey] != false;
          final alreadyRetried = requestOptions.extra[_isRetryKey] == true;

          if (statusCode != 401 || !requiresAuth || alreadyRetried) {
            handler.next(error);
            return;
          }

          final hasRefreshConfig = refreshTokenEndpoint != null &&
              getRefreshToken != null &&
              onTokenRefreshed != null;

          if (!hasRefreshConfig) {
            await _logoutUser();
            handler.next(error);
            return;
          }

          try {
            final freshAccessToken = await _getValidAccessTokenForRetry(
              requestOptions,
            );

            if (freshAccessToken == null || freshAccessToken.isEmpty) {
              await _logoutUser();
              handler.next(error);
              return;
            }

            final retryResponse = await _retryRequest(
              requestOptions,
              freshAccessToken,
            );

            handler.resolve(retryResponse);
          } catch (_) {
            await _logoutUser();
            handler.next(error);
          }
        },
      ),
    );

    if (!enableLogger) return;

    if (useDioBuiltInLogger) {
      /// Dio built-in logger.
      /// It logs request/response/error, but formatting will not be exactly
      /// the same as your previous custom PrettyPrinter logs.
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (object) {
            _logger.i(object.toString());
          },
        ),
      );
    } else {
      /// Recommended: same style as your current logger + safer header masking.
      _dio.interceptors.add(
        _PrettyDioLogger(_logger),
      );
    }
  }

  Future<NetworkResponse> getRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'GET',
      url: url,
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
    );
  }

  Future<NetworkResponse> postRequest(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _request(
      method: 'POST',
      url: url,
      data: body ?? {},
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<NetworkResponse> putRequest(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _request(
      method: 'PUT',
      url: url,
      data: body ?? {},
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<NetworkResponse> patchRequest(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _request(
      method: 'PATCH',
      url: url,
      data: body ?? {},
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<NetworkResponse> deleteRequest(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'DELETE',
      url: url,
      data: body,
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
    );
  }

  Future<NetworkResponse> multipartRequest(
    String url, {
    String method = 'POST',
    Map<String, dynamic>? fields,

    /// Example:
    /// {
    ///   'image': await MultipartFile.fromFile(filePath),
    /// }
    Map<String, MultipartFile>? files,

    /// Example for multiple files:
    /// {
    ///   'images': [
    ///      await MultipartFile.fromFile(path1),
    ///      await MultipartFile.fromFile(path2),
    ///   ],
    /// }
    Map<String, List<MultipartFile>>? fileLists,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    final formMap = <String, dynamic>{};

    if (fields != null) {
      formMap.addAll(fields);
    }

    if (files != null) {
      formMap.addAll(files);
    }

    if (fileLists != null) {
      formMap.addAll(fileLists);
    }

    final formData = FormData.fromMap(formMap);

    return _request(
      method: method.toUpperCase(),
      url: url,
      data: formData,
      headers: headers,
      queryParameters: queryParameters,
      token: token,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      contentType: Headers.multipartFormDataContentType,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<NetworkResponse> _request({
    required String method,
    required String url,
    Object? data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    String? token,
    bool requiresAuth = true,
    String? contentType,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        url,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          method: method,
          headers: _buildHeaders(headers, token),
          contentType: contentType ?? Headers.jsonContentType,
          extra: {
            _requiresAuthKey: requiresAuth,
            _manualTokenKey: token,
          },
        ),
      );

      return NetworkResponse.success(
        statusCode: response.statusCode ?? 200,
        responseData: _normalizeResponseData(response.data),
      );
    } on DioException catch (e) {
      return _handleDioException(e);
    } catch (e) {
      return NetworkResponse.failure(
        statusCode: -1,
        errorMessage: e.toString(),
      );
    }
  }

  Map<String, dynamic> _buildHeaders(
    Map<String, String>? headers,
    String? token,
  ) {
    final finalHeaders = <String, dynamic>{};

    if (headers != null) {
      finalHeaders.addAll(headers);
    }

    if (token != null && token.isNotEmpty) {
      finalHeaders.putIfAbsent('Authorization', () => 'Bearer $token');
    }

    finalHeaders.putIfAbsent(
        Headers.acceptHeader, () => Headers.jsonContentType);

    return finalHeaders;
  }

  NetworkResponse _handleDioException(DioException e) {
    final response = e.response;

    if (response != null) {
      final responseData = _normalizeResponseData(response.data);

      return NetworkResponse.failure(
        statusCode: response.statusCode ?? -1,
        responseData: responseData,
        errorMessage:
            _extractErrorMessage(response.data) ?? _messageFromDioException(e),
      );
    }

    return NetworkResponse.failure(
      statusCode: -1,
      errorMessage: _messageFromDioException(e),
    );
  }

  String _messageFromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please try again.';
      case DioExceptionType.sendTimeout:
        return 'Send timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Bad SSL certificate.';
      case DioExceptionType.badResponse:
        return _defaultErrorMessage;
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.unknown:
        return e.message ?? _defaultErrorMessage;
    }
  }

  Map<String, dynamic>? _normalizeResponseData(dynamic data) {
    if (data == null) return null;

    dynamic finalData = data;

    if (data is String) {
      finalData = _tryDecodeString(data);
    }

    if (finalData == null) return null;

    if (finalData is Map<String, dynamic>) {
      return finalData;
    }

    if (finalData is Map) {
      return Map<String, dynamic>.from(finalData);
    }

    return {
      'data': finalData,
    };
  }

  dynamic _tryDecodeString(String value) {
    if (value.isEmpty) return null;

    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  String? _extractErrorMessage(dynamic data) {
    final responseData = _normalizeResponseData(data);

    if (responseData == null) return null;

    final possibleKeys = [
      'message',
      'msg',
      'error',
      'detail',
    ];

    for (final key in possibleKeys) {
      final value = responseData[key];

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }

      if (value is List && value.isNotEmpty) {
        return value.join(', ');
      }
    }

    final errors = responseData['errors'];

    if (errors is Map && errors.isNotEmpty) {
      final firstValue = errors.values.first;

      if (firstValue is String) {
        return firstValue;
      }

      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.join(', ');
      }
    }

    return null;
  }

  bool _hasAuthorizationHeader(Map<String, dynamic> headers) {
    return headers.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
  }

  Future<String?> _getValidAccessTokenForRetry(
    RequestOptions failedRequestOptions,
  ) async {
    final tokenUsedInFailedRequest = _extractBearerToken(
      failedRequestOptions.headers['Authorization'],
    );

    final currentSavedAccessToken = await getAccessToken?.call();

    /// Case:
    /// Failed request used old token.
    /// But meanwhile another request already refreshed token.
    /// Then no need to call refresh API again.
    if (currentSavedAccessToken != null &&
        currentSavedAccessToken.isNotEmpty &&
        tokenUsedInFailedRequest != null &&
        tokenUsedInFailedRequest != currentSavedAccessToken) {
      return currentSavedAccessToken;
    }

    return _refreshAccessTokenOnce();
  }

  String? _extractBearerToken(dynamic authorizationHeader) {
    if (authorizationHeader == null) return null;

    final value = authorizationHeader.toString();

    if (value.toLowerCase().startsWith('bearer ')) {
      return value.substring(7);
    }

    return value;
  }

  Future<String?> _refreshAccessTokenOnce() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final newAccessToken = await _refreshAccessToken();
      completer.complete(newAccessToken);
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    } finally {
      _refreshCompleter = null;
    }

    return completer.future;
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken?.call();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final body = refreshTokenBodyBuilder?.call(refreshToken) ??
        {
          'refreshToken': refreshToken,
        };

    final response = await _refreshDio.post<dynamic>(
      refreshTokenEndpoint!,
      data: body,
      options: Options(
        headers: {
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );

    final responseData = _normalizeResponseData(response.data);

    if (responseData == null) {
      return null;
    }

    final newAccessToken = accessTokenExtractor?.call(responseData) ??
        _defaultAccessTokenExtractor(responseData);

    final newRefreshToken = refreshTokenExtractor?.call(responseData) ??
        _defaultRefreshTokenExtractor(responseData) ??
        refreshToken;

    if (newAccessToken == null || newAccessToken.isEmpty) {
      return null;
    }

    await onTokenRefreshed?.call(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );

    return newAccessToken;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String freshAccessToken,
  ) {
    requestOptions.headers['Authorization'] = 'Bearer $freshAccessToken';
    requestOptions.extra[_isRetryKey] = true;

    return _dio.fetch<dynamic>(requestOptions);
  }

  Future<void> _logoutUser() async {
    await onTokenClear?.call();
    onUnauthorized();
  }

  static String? _defaultAccessTokenExtractor(
    Map<String, dynamic> responseData,
  ) {
    return _findStringValue(
      responseData,
      [
        'accessToken',
        'access_token',
        'token',
      ],
    );
  }

  static String? _defaultRefreshTokenExtractor(
    Map<String, dynamic> responseData,
  ) {
    return _findStringValue(
      responseData,
      [
        'refreshToken',
        'refresh_token',
      ],
    );
  }

  static String? _findStringValue(
    Map<String, dynamic> responseData,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = responseData[key];

      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final nestedData = responseData['data'];

    if (nestedData is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nestedData[key];

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }
}

class _PrettyDioLogger extends Interceptor {
  final Logger logger;

  _PrettyDioLogger(this.logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final message = '''
URL --> ${options.uri}
METHOD --> ${options.method}
HEADERS --> ${_maskedHeaders(options.headers)}
QUERY PARAMETERS --> ${options.queryParameters}
BODY --> ${options.data}
''';

    logger.i(message);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final message = '''
URL --> ${response.realUri}
STATUS CODE --> ${response.statusCode}
HEADERS --> ${_maskedHeaders(response.requestOptions.headers)}
BODY --> ${response.data}
''';

    final statusCode = response.statusCode ?? -1;

    if (statusCode >= 200 && statusCode < 300) {
      logger.i(message);
    } else {
      logger.e(message);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    final message = '''
URL --> ${err.requestOptions.uri}
STATUS CODE --> ${response?.statusCode}
HEADERS --> ${_maskedHeaders(err.requestOptions.headers)}
ERROR TYPE --> ${err.type}
ERROR MESSAGE --> ${err.message}
BODY --> ${response?.data}
''';

    logger.e(message);
    handler.next(err);
  }

  Map<String, dynamic> _maskedHeaders(Map<String, dynamic> headers) {
    final safeHeaders = Map<String, dynamic>.from(headers);

    for (final key in safeHeaders.keys.toList()) {
      if (key.toLowerCase() == 'authorization') {
        safeHeaders[key] = 'Bearer ***';
      }
    }

    return safeHeaders;
  }
}
