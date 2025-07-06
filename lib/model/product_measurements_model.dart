class ProductMeasurements {
  final double? bust;
  final double? waist;
  final double? hip;
  final double? shoulderWidth;
  final double? sleeveLength;
  final double? shirtLength;
  final double? inseam;
  final double? outseam;
  final double? totalLength;

  ProductMeasurements({
    this.bust,
    this.waist,
    this.hip,
    this.shoulderWidth,
    this.sleeveLength,
    this.shirtLength,
    this.inseam,
    this.outseam,
    this.totalLength,
  });

  factory ProductMeasurements.fromMap(Map<String, dynamic> data) {
    return ProductMeasurements(
      bust: (data['bust'] as num?)?.toDouble(),
      waist: (data['waist'] as num?)?.toDouble(),
      hip: (data['hip'] as num?)?.toDouble(),
      shoulderWidth: (data['shoulderWidth'] as num?)?.toDouble(),
      sleeveLength: (data['sleeveLength'] as num?)?.toDouble(),
      shirtLength: (data['shirtLength'] as num?)?.toDouble(),
      inseam: (data['inseam'] as num?)?.toDouble(),
      outseam: (data['outseam'] as num?)?.toDouble(),
      totalLength: (data['totalLength'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (bust != null) 'bust': bust,
      if (waist != null) 'waist': waist,
      if (hip != null) 'hip': hip,
      if (shoulderWidth != null) 'shoulderWidth': shoulderWidth,
      if (sleeveLength != null) 'sleeveLength': sleeveLength,
      if (shirtLength != null) 'shirtLength': shirtLength,
      if (inseam != null) 'inseam': inseam,
      if (outseam != null) 'outseam': outseam,
      if (totalLength != null) 'totalLength': totalLength,
    };
  }
}
