import 'package:finance_tracker/GlobalVars.dart';
import 'package:finance_tracker/TitleItem.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ItemDetailsPage extends StatelessWidget {
  final List<DateTime> appliedDates;
  final Function selectedDateCallbackFunction;
  final String itemName;
  ItemDetailsPage(this.itemName, this.appliedDates, this.selectedDateCallbackFunction);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Show Details")),
        body: Scrollbar(child: ListView.builder(
                itemCount: appliedDates.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  // Show the title at the first index
                  if (index == 0) {
                    return TitleItem("Applied Dates for $itemName");
                  }
                  return Card(
                    margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      elevation: GlobalVars.listTileElevation,
                      child: InkWell(
                          onTap: () {
                            selectedDateCallbackFunction(context, appliedDates[index-1]);
                            Navigator.pop(context);
                          },
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  DateFormat("MM/dd/yyyy")
                                      .format(appliedDates[index - 1]),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)))));
                })));
  }
}
