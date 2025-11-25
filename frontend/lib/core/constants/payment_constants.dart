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
  static const String contactEmail = 'support@disciplefy.in';
  static const String contactPhone = '+919876543210';

  // Payment themes
  static const Map<String, dynamic> razorpayTheme = {
    'color': '#7C3AED', // Vibrant purple
  };

  // Token pricing
  static const int tokensPerRupee = 10; // 10 tokens = ₹1
  static const int minimumTokenPurchase = 1;
  static const int maximumTokenPurchase = 10000;

  // Payment timeout
  static const int paymentTimeoutSeconds = 300; // 5 minutes

  // Default payment packages
  static const List<Map<String, dynamic>> defaultPackages = [
    {
      'tokens': 50,
      'rupees': 5,
      'discount': 0,
      'isPopular': false,
    },
    {
      'tokens': 100,
      'rupees': 9,
      'discount': 10,
      'isPopular': false,
    },
    {
      'tokens': 250,
      'rupees': 20,
      'discount': 20,
      'isPopular': true,
    },
    {
      'tokens': 500,
      'rupees': 35,
      'discount': 30,
      'isPopular': false,
    },
  ];
}
