// lib/api/report_service.dart
import 'package:dio/dio.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/report_models.dart';

class ReportService {
  final Dio _dio = ApiClient.instance.dio;

  Future<ReportsOverview> getOverview({
    required int restaurantId,
    required DateTime from,
    required DateTime to,
  }) async {
    final resp = await _dio.post(
      '/reports/overview',
      data: {
        'restaurantID': restaurantId,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );

    return ReportsOverview.fromJson(resp.data as Map<String, dynamic>);
  }
}
