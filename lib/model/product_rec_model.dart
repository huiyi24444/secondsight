class ProductRecommendation {
  final String productId;
  final String productName;
  final double productPrice;
  final String productURL;
  final double similarityScore;

  ProductRecommendation({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productURL,
    required this.similarityScore,
  });

  factory ProductRecommendation.fromMap(Map<String, dynamic> map) {
    return ProductRecommendation(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productPrice: (map['productPrice'] ?? 0).toDouble(),
      productURL: map['productURL'] ?? '',
      similarityScore: (map['similarityScore'] ?? 0).toDouble(),
    );
  }
}