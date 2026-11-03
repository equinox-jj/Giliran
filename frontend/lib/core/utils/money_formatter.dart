import 'package:intl/intl.dart';

/// Rupiah display for whole-rupiah API amounts.
abstract final class MoneyFormatter() {
  static final _number = NumberFormat.decimalPattern('id_ID');

  /// "Rp1.234.567": no space, dot thousands, no decimals.
  static String rupiah(int amount) => 'Rp${_number.format(amount)}';
}
