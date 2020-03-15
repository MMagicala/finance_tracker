import 'Frequency.dart';

class Item {
  String name;
  double amount;
  Frequency frequency;
  DateTime startDate;
  DateTime lastDate;
  double loanAmount;
  // for custom frequency
  int daysFrequency;
  bool repayLoan;
  bool enabled;
  Item(this.name, this.amount, this.frequency, this.startDate,
      {this.lastDate, this.loanAmount, this.daysFrequency, this.repayLoan, this.enabled = true});

  static Item copy(Item origItem) {
    return Item(
        origItem.name, origItem.amount, origItem.frequency, origItem.startDate,
        lastDate: origItem.lastDate,
        loanAmount: origItem.loanAmount,
        daysFrequency: origItem.daysFrequency,
        repayLoan: origItem.repayLoan,
    enabled: origItem.enabled);
  }
}
