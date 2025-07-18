// lib/utils/formatters.dart

String formatCardNumber(String cardNumber) {
  // Show only last 4 digits
  if (cardNumber.length >= 4) {
    final lastFour = cardNumber.substring(cardNumber.length - 4);
    return '•••• •••• •••• $lastFour';
  }
  return '•••• •••• •••• ••••';
}
