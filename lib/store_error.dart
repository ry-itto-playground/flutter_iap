import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

enum StoreErrorType {
  notAvailable,
  hasNotFoundId,
  iapError,
}

class StoreError implements Exception {
  const StoreError({
    required this.type,
  }) : error = null;

  const StoreError.iapError({
    required this.error,
  }) : type = StoreErrorType.iapError;

  final StoreErrorType type;
  final IAPError? error;
}
