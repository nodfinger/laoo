class ApiResponse<T> {
  const ApiResponse({required this.success, required this.data, this.message});

  final bool success;
  final T? data;
  final String? message;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      data: json.containsKey('data') ? parseData(json['data']) : null,
    );
  }
}
