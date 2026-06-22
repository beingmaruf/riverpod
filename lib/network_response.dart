part of 'network_client.dart';

class NetworkResponse {
  final int statusCode;
  final Map<String, dynamic>? responseData;
  final String? errorMessage;
  final bool isSuccess;

  const NetworkResponse({
    required this.statusCode,
    required this.isSuccess,
    this.responseData,
    this.errorMessage,
  });

  factory NetworkResponse.success({
    required int statusCode,
    Map<String, dynamic>? responseData,
  }) {
    return NetworkResponse(
      statusCode: statusCode,
      isSuccess: true,
      responseData: responseData,
    );
  }

  factory NetworkResponse.failure({
    required int statusCode,
    String? errorMessage,
    Map<String, dynamic>? responseData,
  }) {
    return NetworkResponse(
      statusCode: statusCode,
      isSuccess: false,
      errorMessage: errorMessage,
      responseData: responseData,
    );
  }
}
