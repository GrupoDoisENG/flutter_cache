import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/product_api_client.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

final productApiClientProvider = Provider<ProductApiClient>(
  (ref) => ProductApiClient(),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(productApiClientProvider)),
);

class ProductListNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    return ref.read(productRepositoryProvider).getProducts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(productRepositoryProvider).getProducts(forceRefresh: true),
    );
  }
}

final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, List<Product>>(
  ProductListNotifier.new,
);
