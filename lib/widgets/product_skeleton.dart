import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProductSkeleton extends StatelessWidget {
  const ProductSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              color: Colors.white,
            ),
          ),
          title: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.only(right: 60),
          ),
          subtitle: Container(
            height: 12,
            color: Colors.white,
            margin: const EdgeInsets.only(right: 100, top: 4),
          ),
        ),
      ),
    );
  }
}
