/// Payment Configuration Constants
///
/// Contains all payment-related constants for Razorpay integration
class PaymentConstants {
  // Razorpay Configuration
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_RFzzBvMdQzOOyA', // Valid test key from your backend
  );

  static const String companyName = 'Disciplefy';
  static const String companyDescription = 'Bible Study Token Purchase';
  static const String currency = 'INR';

  // Payment themes
  static const Map<String, dynamic> razorpayTheme = {
    'color': '#7C3AED', // Vibrant purple
  };

  // Token pricing
  static const int tokensPerRupee = 2; // 2 tokens = ₹1

  // Default payment packages (FALLBACK ONLY - actual packages fetched from backend)
  // Progressive discount: 0% → 10% → 20% → 25% → 30% → 40%
  static const List<Map<String, dynamic>> defaultPackages = [
    {
      'tokens': 20,
      'rupees': 10,
      'discount': 0,
      'isPopular': false,
    },
    {
      'tokens': 50,
      'rupees': 22,
      'discount': 10,
      'isPopular': false,
    },
    {
      'tokens': 100,
      'rupees': 40,
      'discount': 20,
      'isPopular': true,
    },
    {
      'tokens': 200,
      'rupees': 75,
      'discount': 25,
      'isPopular': false,
    },
    {
      'tokens': 400,
      'rupees': 140,
      'discount': 30,
      'isPopular': false,
    },
    {
      'tokens': 1000,
      'rupees': 300,
      'discount': 40,
      'isPopular': false,
    },
  ];
}
