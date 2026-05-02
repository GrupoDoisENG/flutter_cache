import '../data/product_api_client.dart';
import '../models/product.dart';

class ProductRepository {
  final ProductApiClient _client;

  List<Product>? _cache;
  DateTime? _cacheTime;

  static const _cacheDuration = Duration(minutes: 5);

  ProductRepository(this._client);

  bool get _isCacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;

  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) return _cache!;
    final products = await _client.fetchProducts();
    _cache = products;
    _cacheTime = DateTime.now();
    return _cache!;
  }

  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }
}
