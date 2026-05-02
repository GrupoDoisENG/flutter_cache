import 'package:dio/dio.dart';
import '../models/product.dart';

class ProductApiClient {
  final Dio _dio;

  static const _baseUrl = 'https://dummyjson.com';

  ProductApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  ProductApiClient.withDio(this._dio);

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products',
        queryParameters: {'limit': 30},
      );
      final rawList = response.data!['products'] as List<dynamic>;
      return rawList
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ProductApiException(_mapDioError(e));
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tempo de conexão esgotado. Verifique sua internet.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return 'Erro do servidor: $status';
      case DioExceptionType.connectionError:
        return 'Sem conexão com a internet.';
      default:
        return 'Erro de rede inesperado.';
    }
  }
}

class ProductApiException implements Exception {
  final String message;
  const ProductApiException(this.message);

  @override
  String toString() => message;
}
