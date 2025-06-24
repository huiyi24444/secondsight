class CardModel {
  String cardNumber; // Consider masking on display
  String ccv;
  String expiryDate;
  String cardholderName;

  CardModel({
    required this.cardNumber,
    required this.ccv,
    required this.expiryDate,
    required this.cardholderName,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      cardNumber: json['cardNumber'] ?? '',
      ccv: json['ccv'] ?? '',
      expiryDate: json['expiryDate'] ?? '',
      cardholderName: json['cardholderName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber,
      'ccv': ccv,
      'expiryDate': expiryDate,
      'cardholderName': cardholderName,
    };
  }
}
