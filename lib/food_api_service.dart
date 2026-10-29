import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class FoodApiService {
  static const String defaultApiUrl =
      'https://gist.githubusercontent.com/CarloCobrado/2ff519657f874163071a1bf1555ab3f2/raw/a39164f6cd42aaa9b0b77a49764abacafe2485fd/food_products.json';

  final String apiUrl;
  final http.Client _client;

  FoodApiService({
    String? apiUrl,
    http.Client? client,
  })  : apiUrl = apiUrl ?? defaultApiUrl,
        _client = client ?? http.Client();

  Future<String> fetchProductsJson() async {
    final uri = Uri.parse(apiUrl);

    try {
      debugPrint('[FoodApiService] Executing HTTP GET -> $uri');

      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'SecondServe-MobileApp',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out after 10 seconds.');
            },
          );

      debugPrint('[FoodApiService] HTTP Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw HttpException(
          'HTTP GET failed with status ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }
    } on SocketException catch (e) {
      debugPrint('[FoodApiService] SocketException (No internet / connection error): $e');
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('[FoodApiService] TimeoutException: $e');
      rethrow;
    } catch (e) {
      debugPrint('[FoodApiService] Request execution error: $e');
      rethrow;
    }
  }

  Future<String> fetchProductsJsonWithFallback() async {
    try {
      return await fetchProductsJson();
    } catch (e) {
      debugPrint(
        '[FoodApiService] Remote GET failed ($e). Loading local assets/food_products.json as fallback.',
      );
      return await rootBundle.loadString('assets/food_products.json');
    }
  }

  void dispose() {
    _client.close();
  }
}
