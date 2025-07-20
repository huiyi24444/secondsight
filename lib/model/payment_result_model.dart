// ======= RESULT CLASSES =======

class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;
  final String? errorCode;

  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
    this.errorCode,
  });
}

class SetupResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? paymentMethodDetails;
  final String? errorCode;

  SetupResult({
    required this.success,
    required this.message,
    this.paymentMethodDetails,
    this.errorCode,
  });
}