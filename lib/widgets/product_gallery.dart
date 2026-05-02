import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/product.dart';

class ProductGallery extends StatelessWidget {
  final Product product;

  const ProductGallery({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: PageView.builder(
        itemCount: product.images.length,
        itemBuilder: (context, index) {
          return CachedNetworkImage(
            imageUrl: product.images[index],
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}
