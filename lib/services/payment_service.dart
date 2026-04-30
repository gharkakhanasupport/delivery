import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
export 'package:razorpay_flutter/razorpay_flutter.dart';

/// Service for handling payments (e.g. COD Remittance) via Razorpay
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late Razorpay _razorpay;
  
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize({
    Function(PaymentSuccessResponse)? onSuccess,
    Function(PaymentFailureResponse)? onFailure,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  void startPayment({
    required double amount,
    required String contact,
    required String email,
    required String description,
    Map<String, String>? notes,
  }) {
    final apiKey = dotenv.env['Test_API_Key'] ?? '';
    
    if (apiKey.isEmpty) {
      debugPrint('Razorpay API Key missing in .env');
      return;
    }

    var options = {
      'key': apiKey,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'Ghar Ka Khana',
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
      },
      'notes': notes ?? {},
      'theme': {
        'color': '#10B981', // AppColors.emeraldGreen
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }
}
