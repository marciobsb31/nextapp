import 'package:flutter/material.dart';
import '../models/credit_card_model.dart';

enum PaymentMethodType { creditCard, pix, mealVoucher }
enum PaymentStatus { idle, processing, approved, failed }

class PaymentController extends ChangeNotifier {
  PaymentMethodType _selectedMethod = PaymentMethodType.creditCard;
  final List<CreditCardModel> _savedCards = List.from(CreditCardModel.mockCards);
  int _selectedCardIndex = 0;
  PaymentStatus _status = PaymentStatus.idle;

  // Campos do novo cartão para visualização dinâmica em tempo real
  String _cardNumber = '';
  String _cardHolderName = '';
  String _expiryDate = '';
  String _cvv = '';
  String _brand = 'mastercard';

  PaymentMethodType get selectedMethod => _selectedMethod;
  List<CreditCardModel> get savedCards => List.unmodifiable(_savedCards);
  int get selectedCardIndex => _selectedCardIndex;
  CreditCardModel? get currentCard =>
      _savedCards.isNotEmpty && _selectedCardIndex < _savedCards.length
          ? _savedCards[_selectedCardIndex]
          : null;
  PaymentStatus get status => _status;

  String get cardNumber => _cardNumber.isEmpty ? '•••• •••• •••• ••••' : _cardNumber;
  String get cardHolderName => _cardHolderName.isEmpty ? 'NOME DO TITULAR' : _cardHolderName.toUpperCase();
  String get expiryDate => _expiryDate.isEmpty ? 'MM/AA' : _expiryDate;
  String get cvv => _cvv.isEmpty ? '•••' : _cvv;
  String get brand => _brand;

  void selectMethod(PaymentMethodType method) {
    _selectedMethod = method;
    notifyListeners();
  }

  void selectCard(int index) {
    _selectedCardIndex = index;
    notifyListeners();
  }

  void updateCardNumber(String value) {
    _cardNumber = value;
    // Detecção básica de bandeira
    final clean = value.replaceAll(' ', '');
    if (clean.startsWith('4')) {
      _brand = 'visa';
    } else if (clean.startsWith('5')) {
      _brand = 'mastercard';
    } else if (clean.startsWith('6')) {
      _brand = 'elo';
    }
    notifyListeners();
  }

  void updateCardHolder(String value) {
    _cardHolderName = value;
    notifyListeners();
  }

  void updateExpiryDate(String value) {
    _expiryDate = value;
    notifyListeners();
  }

  void updateCvv(String value) {
    _cvv = value;
    notifyListeners();
  }

  void saveNewCard() {
    final newCard = CreditCardModel(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      cardNumber: _cardNumber.isEmpty ? '5555 4444 3333 2222' : _cardNumber,
      cardHolderName: _cardHolderName.isEmpty ? 'TITULAR' : _cardHolderName.toUpperCase(),
      expiryDate: _expiryDate.isEmpty ? '12/28' : _expiryDate,
      cvv: _cvv.isEmpty ? '123' : _cvv,
      brand: _brand,
      gradient: const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF334155)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    _savedCards.insert(0, newCard);
    _selectedCardIndex = 0;
    _cardNumber = '';
    _cardHolderName = '';
    _expiryDate = '';
    _cvv = '';
    notifyListeners();
  }

  Future<void> processPayment() async {
    _status = PaymentStatus.processing;
    notifyListeners();

    // Simulação do processamento de segurança e liberação do Smart Access
    await Future.delayed(const Duration(milliseconds: 2400));
    _status = PaymentStatus.approved;
    notifyListeners();
  }

  void resetPayment() {
    _status = PaymentStatus.idle;
    notifyListeners();
  }
}
