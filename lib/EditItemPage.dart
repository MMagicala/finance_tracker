import 'package:finance_tracker/Date.dart';
import 'package:finance_tracker/GlobalVars.dart';
import 'package:finance_tracker/TitleItem.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Frequency.dart';
import 'Item.dart';

//import 'dart:math' as math;
import 'package:flutter/services.dart';

class EditItemPage extends StatefulWidget {
  // Information passed from the home page to this page (read only!)
  Function addItemCallbackFunction;
  Function editItemCallbackFunction;
  Item item;
  bool itemsHaveLoan;

  /* Constructors that are called from the homepage. Two constructors are for
   * launching this page in either adding or editing mode. Callback functions
   * allow the EditItemPageState class to send item data back to the homepage. */
  EditItemPage(this.addItemCallbackFunction, this.itemsHaveLoan)
      : editItemCallbackFunction = null,
        item = null;
  EditItemPage.edit(
      this.editItemCallbackFunction, this.item, this.itemsHaveLoan)
      : addItemCallbackFunction = null;

  @override
  State<StatefulWidget> createState() => EditItemPageState();
}

class EditItemPageState extends State<EditItemPage> {
  // Edited data (can be changed!)
  // TextFormFields controllers
  var nameController = TextEditingController();
  var amountController = TextEditingController();
  var loanAmountController = TextEditingController();
  var daysFrequencyController = TextEditingController();

  /* These booleans determine whether certain fields should be visible or not.
   * They are visible depending on the values of other fields */
  bool showLastDateSelector;
  bool showLoanAmountText;
  bool showFrequencyDaysText;
  bool showRepayLoanCheckBox;
  bool showLastDateCheckBox;

  // Saves the values of certain non-text fields
  Frequency _frequency;
  DateTime _startDate, _lastDate;
  bool _repayLoan;
  // Passes on the enabled flag so our new item has the same value as the replaced edited one
  bool _enabled;
  /* Checks if the add callback function was passed into the widget class or not.
   * This is true if the function is null. */
  bool isInEditMode;

  // Global key allows access to the form widget and it's data
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    //only insert text if the EditItemPage is in edit mode
    isInEditMode = widget.addItemCallbackFunction == null;

    if (isInEditMode) {
      /* Set the values of the fields equal to the data passed from the parent widget.
       * The default values will be passed if they didn't exist when decoded from
       * the list extracted from SharedPrefs */
      nameController.text = widget.item.name;
      amountController.text = widget.item.amount.toString();
      loanAmountController.text = widget.item.loanAmount.toString();
      daysFrequencyController.text = widget.item.daysFrequency.toString();

      // The non-text fields will be set to these variable values
      _startDate = widget.item.startDate;
      _lastDate = widget.item.lastDate;
      _frequency = widget.item.frequency;
      _repayLoan = widget.item.repayLoan;

      // Based on the given data, show and hide certain fields accordingly
      // There is no loan amount to show if money is NOT being given to them
      showLoanAmountText = widget.item.amount > 0;

      // Frequency days is only shown if the frequency is set to custom
      showFrequencyDaysText = _frequency == Frequency.CUSTOM;

      // Allow the user to select a last date unless the item only applies once
      showLastDateCheckBox = widget.item.frequency != Frequency.ONCE;
      showLastDateSelector = _lastDate != null;

      /* An item can be used to repay a loan if the user is paying (losing) money AND
       * there is a loan that needs to be repaid */
      // TODO: Change the itemsHaveLoan logic so it is only true when a loan balance exists
      showRepayLoanCheckBox = widget.item.amount < 0 && widget.itemsHaveLoan;
    } else {
      // Set default values for the fields when adding an item
      _frequency = Frequency.MONTHLY;
      _startDate = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _lastDate = null;
      _repayLoan = false;
      _enabled = true;

      // Certain fields should not be visible yet
      showLastDateSelector = false;
      showLoanAmountText = false;
      showRepayLoanCheckBox = false;
      showFrequencyDaysText = false;
      showLastDateCheckBox = true;

      // Set the optional fields to zero
      loanAmountController.text = "0";
      daysFrequencyController.text = "0";
    }

    // Check if the amount is less than zero to hide the loan amount text
    amountController.addListener(() {
      setState(() {
        if (num.tryParse(amountController.text) == null) {
          showLoanAmountText = false;
          showRepayLoanCheckBox = false;
        } else {
          showLoanAmountText = num.parse(amountController.text) > 0;
          showRepayLoanCheckBox =
              num.parse(amountController.text) < 0 && widget.itemsHaveLoan;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.addItemCallbackFunction != null
                ? "Add an item"
                : "Edit an item")),
        body: SingleChildScrollView(
            child: Form(
                key: _formKey,
                child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [
                      TitleItem("Item Info"),
                      Card(
                          elevation: GlobalVars.listTileElevation,
                          child: Container(
                              margin: EdgeInsets.all(16),
                              child: Column(children: <Widget>[
                                // Text form for the name
                                TextFormField(
                                  controller: nameController,
                                  decoration:
                                      InputDecoration(labelText: "Name"),
                                  validator: (String value) {
                                    if (value == "")
                                      return "Enter a valid name!";
                                    return null;
                                  },
                                ),

                                // Text form for the amount
                                TextFormField(
                                  controller: amountController,
                                  decoration:
                                      InputDecoration(labelText: "Amount"),
                                  keyboardType:
                                      TextInputType.numberWithOptions(),
                                  validator: (String value) {
                                    if (num.tryParse(value) == null)
                                      return "Enter a valid amount!";
                                    return null;
                                  },
                                ),

                                // Repay loan checkbox
                                Visibility(
                                    visible: showRepayLoanCheckBox,
                                    child: CheckboxListTile(
                                        title: Text("Repay loan?"),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        value: _repayLoan,
                                        onChanged: (bool value) {
                                          setState(() {
                                            _repayLoan = value;
                                          });
                                        })),

                                // Text field for loan amount
                                Visibility(
                                    child: TextFormField(
                                      controller: loanAmountController,
                                      decoration: InputDecoration(
                                          labelText: "Loan Amount"),
                                      keyboardType:
                                          TextInputType.numberWithOptions(),
                                      validator: (String value) {
                                        // Loan must be a number
                                        if (num.tryParse(value) == null) {
                                          return "Enter a valid loan amount!";
                                        }
                                        // Loan amount must be positive
                                        if (num.parse(
                                                loanAmountController.text) <
                                            0) {
                                          return "Loan amount cannot be negative!";
                                        }
                                        // Loan amount cant be more than the total amount
                                        if (num.parse(
                                                loanAmountController.text) >
                                            num.parse(amountController.text)) {
                                          return "Loan amount cant be more than the total amount";
                                        }
                                        return null;
                                      },
                                    ),
                                    visible: showLoanAmountText),

                                // Drop down button for frequency
                                DropdownButton<Frequency>(
                                    value: _frequency,
                                    items: List.generate(
                                        Frequency.values.length, (int index) {
                                      return DropdownMenuItem<Frequency>(
                                          value: Frequency.values[index],
                                          child: Text(FreqConvert.freqToString(
                                              Frequency.values[index])));
                                    }),
                                    onChanged: (Frequency frequency) {
                                      setState(() {
                                        _frequency = frequency;
                                        // Show the frequency days drop down menu if the frequency is set to "custom"
                                        showFrequencyDaysText =
                                            _frequency == Frequency.CUSTOM;
                                        // Don't allow the user to select a last date if the frequency is set to "once"
                                        showLastDateCheckBox =
                                            frequency != Frequency.ONCE;
                                      });
                                    }),
                                // Selector for frequency days
                                Visibility(
                                  visible: showFrequencyDaysText,
                                  child: TextFormField(
                                    controller: daysFrequencyController,
                                    decoration: InputDecoration(
                                        labelText: "Every __ days"),
                                    keyboardType:
                                        TextInputType.numberWithOptions(),
                                    validator: (String value) {
                                      if (num.tryParse(value) == null ||
                                          num.tryParse(value).toInt() <= 0) {
                                        return "Enter a valid number of days!";
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                // Start date selector
                                FlatButton(
                                    onPressed: () {
                                      selectDate("startDate");
                                    },
                                    child: Text("Start Date: " +
                                        DateFormat("MM / dd / yyyy")
                                            .format(_startDate))),

                                // Last date checkbox
                                Visibility(
                                    child: CheckboxListTile(
                                        title: Text("Has a last date?"),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        value: showLastDateSelector,
                                        onChanged: (bool value) {
                                          setState(() {
                                            showLastDateSelector =
                                                !showLastDateSelector;
                                            // reset last date
                                            _lastDate = showLastDateSelector
                                                ? _startDate
                                                : null;
                                          });
                                        }),
                                    visible: showLastDateCheckBox),

                                // Last date selector
                                showLastDateSelector && showLastDateCheckBox
                                    ? FlatButton(
                                        onPressed: () {
                                          selectDate("lastDate");
                                        },
                                        child: Text("Last Date: " +
                                            DateFormat("MM / dd / yyyy")
                                                .format(_lastDate)))
                                    : Container()
                              ]))),
                    ])))),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.check),
            tooltip: isInEditMode ? "Edit item" : "Add item",
            onPressed: () {
              if (_formKey.currentState.validate()) {
                /* Call the callback functions if the form has no validation errors
                 * Perform checks on whether a field was visible or not. If it
                 * wasn't visible, just pass on the default value for that field */
                double _amount = num.parse(amountController.text).toDouble();
                _lastDate = showLastDateSelector ? _lastDate : null;
                double _loanAmount = showLoanAmountText
                    ? num.parse(loanAmountController.text).toDouble()
                    : 0;
                int _daysFrequency = showFrequencyDaysText
                    ? num.parse(daysFrequencyController.text).toInt()
                    : 0;
                if (!isInEditMode) {
                  widget.addItemCallbackFunction(Item(
                      nameController.text, _amount, _frequency, _startDate,
                      lastDate: _lastDate,
                      loanAmount: _loanAmount,
                      daysFrequency: _daysFrequency,
                      repayLoan: _repayLoan));
                } else {
                  widget.editItemCallbackFunction(Item(
                      nameController.text, _amount, _frequency, _startDate,
                      lastDate: _lastDate,
                      loanAmount: _loanAmount,
                      daysFrequency: _daysFrequency,
                      repayLoan: _repayLoan));
                }
                Navigator.pop(context);
              }
            }),
      );

  void selectDate(String variable) async {
    DateTime firstDate = DateTime(1970, 1, 1);
    if (variable == "lastDate") {
      firstDate = _startDate;
    }
    DateTime inputDate = await showDatePicker(
        context: context,
        initialDate: variable == "lastDate" ? _lastDate : _startDate,
        firstDate: firstDate,
        lastDate: DateTime(2099, 1, 1));
    if (inputDate != null) {
      DateTime newDate =
          DateTime(inputDate.year, inputDate.month, inputDate.day);
      // move the last date of the item if it exists
      setState(() {
        if (variable == "startDate") {
          if (showLastDateSelector) {
            if (_startDate.isBefore(newDate)) {
              _lastDate = Date.getDateAfterDuration(
                  _lastDate, Date.getDuration(_startDate, newDate));
            } else if (_startDate.isAfter(newDate)) {
              _lastDate = Date.getDateBeforeDuration(
                  _lastDate, Date.getDuration(newDate, _startDate));
            }
          }
          _startDate = newDate;
        } else {
          _lastDate = newDate;
        }
      });
    }
  }
}
