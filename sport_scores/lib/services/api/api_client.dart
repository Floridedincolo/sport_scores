import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../models/sport.dart';
import '../../utils/api_rate_limiter.dart';
import '../cache_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class RateLimitException extends ApiException {
  RateLimitException()
      : super('Daily API request limit reached (${ApiConstants.dailyRequestLimit})');
}

class NetworkException extends ApiException {
  NetworkException([String? detail])
      : super(detail == null
            ? 'Fără conexiune la internet. Verifică rețeaua și încearcă din nou.'
            : 'Probleme de rețea: $detail');
}

class ApiClient {
  final ApiRateLimiter rateLimiter;
  final CacheService cache;
  final http.Client _httpClient;

  ApiClient({
    required this.rateLimiter,
    required this.cache,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<List<dynamic>> get(
    SportType sport,
    String endpoint, {
    Map<String, String>? params,
    Duration cacheTtl = const Duration(minutes: 2),
  }) async {
    final baseUrl = ApiConstants.baseUrls[sport];
    if (baseUrl == null) throw ApiException('No API URL for $sport');

    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: params,
    );
    final cacheKey = uri.toString();

    final cached = cache.get(cacheKey, cacheTtl);
    if (cached != null) return cached as List<dynamic>;

    if (!rateLimiter.canMakeRequest) throw RateLimitException();

    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: {ApiConstants.authHeader: ApiConstants.apiKey},
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      throw NetworkException(e.osError?.message);
    } on HttpException {
      throw NetworkException();
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on FormatException {
      throw NetworkException();
    } catch (e) {
      // include timeout-uri și alte excepții neașteptate
      throw NetworkException(e.toString());
    }

    if (response.statusCode != 200) {
      throw ApiException('API error: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final errors = body['errors'];

    if (errors is Map && errors.isNotEmpty) {
      throw ApiException(errors.values.first.toString());
    }
    if (errors is List && errors.isNotEmpty) {
      throw ApiException(errors.first.toString());
    }

    await rateLimiter.recordRequest();

    final data = body['response'] as List<dynamic>;
    cache.put(cacheKey, data);
    return data;
  }
}
