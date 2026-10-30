import 'package:flutter/material.dart';

class CreditCardModel {
  final String id;
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;
  final String cvv;
  final String brand; // 'mastercard', 'visa', 'elo', etc.
  final LinearGradient gradient;
  final bool isDefault;

  const CreditCardModel({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.cvv,
    required this.brand,
    required this.gradient,
    this.isDefault = false,
  });

  String get maskedNumber {
    final clean = cardNumber.replaceAll(' ', '');
    if (clean.length < 4) return '•••• •••• •••• ••••';
    final last4 = clean.substring(clean.length - 4);
    return '•••• •••• •••• $last4';
  }

  static List<CreditCardModel> get mockCards => [
        const CreditCardModel(
          id: 'card_1',
          cardNumber: '5412 7512 3412 8892',
          cardHolderName: 'MARCIO SILVA',
          expiryDate: '08/29',
          cvv: '891',
          brand: 'mastercard',
          isDefault: true,
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        const CreditCardModel(
          id: 'card_2',
          cardNumber: '4111 8820 9942 1204',
          cardHolderName: 'MARCIO S SOUZA',
          expiryDate: '11/30',
          cvv: '320',
          brand: 'visa',
          isDefault: false,
          gradient: LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF5500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        const CreditCardModel(
          id: 'card_3',
          cardNumber: '6062 8219 4481 9012',
          cardHolderName: 'MARCIO SILVA',
          expiryDate: '03/28',
          cvv: '105',
          brand: 'elo',
          isDefault: false,
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ];
}
