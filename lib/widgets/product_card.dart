import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final String? imageUrl; // 新增图片参数

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.imageUrl, // 可选
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // 让图片圆角剪裁
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 真正的图片显示
          Expanded(
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey.shade100, child: const Icon(Icons.image_not_supported)),
                  )
                : Container(
                    color: Colors.grey.shade100,
                    child: const Center(child: Icon(Icons.inventory_2, color: Colors.grey)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1, // 名字太长只显示一行，加省略号
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM $price', // 里面保留一个 RM 即可
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
