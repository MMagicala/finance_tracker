import 'dart:convert';

import 'package:finance_tracker/GlobalVars.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'AboutPage.dart';
import 'DataPoint.dart';
import "EditItemPage.dart";
import 'Frequency.dart';
import 'Item.dart';
import 'Date.dart';
import 'TitleItem.dart';
import 'ItemDetailsPage.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MyHomePage(title: 'Finance Tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  // Secure storage
  final storage = new FlutterSecureStorage();

  // List of items
  List<Item> items = [];
  // Stores the index of the item being edited when the EditItemsPage is open
  int currentlyEditedItemIndex;

  // Graph variables

  // Has all the data for total balances and no loan balances for each date
  List<DataPoint> totalData, noLoanData;
  // How far the graph should render
  DateTime endDate;
  // Which date to get balance and other info
  DateTime selectedDate;
  // Date view management
  DateTime viewMinDate, viewMaxDate;

  // Tab management

  // Page controller manages the two tabs for the items list and projection view.
  PageController pageController;
  // Keeps track of the page that the controller is on
  int bottomNavBarIndex;

  // view interval for the graph
  final int viewInterval = 90;

  // Allows a widget's event to display a SnackBar from the app's scaffold widget
  GlobalKey<ScaffoldState> scaffoldGlobalKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Load data from shared preferences
    loadDataFromSecureStorage();

    // Default page is the items page
    bottomNavBarIndex = 0;
    pageController = PageController(initialPage: bottomNavBarIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldGlobalKey,
        appBar: AppBar(title: Text(widget.title), actions: <Widget>[
          Visibility(
              // Only show the PopUpMenuButton on the items page
              visible: bottomNavBarIndex == 0,
              child: PopupMenuButton(
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem(
                        value: "clear",
                        child: Text("Clear All"),
                        enabled: items.length > 0),
                    PopupMenuItem(value: "about", child: Text("About")),
                  ];
                },
                onSelected: (String value) {
                  if (value == "about") {
                    // Show the about page
                    Navigator.push(context,
                        MaterialPageRoute(builder: (BuildContext context) {
                      return AboutPage();
                    }));
                  } else if (value == "clear") {
                    showClearAllDialog();
                  }
                },
              ))
        ]),
        body: PageView(
            physics: NeverScrollableScrollPhysics(),
            controller: pageController,
            onPageChanged: (int index) {
              setState(() {
                bottomNavBarIndex = index;
              });
            },
            children: [
              Scrollbar(
                  child: items.length == 0
                      ? Center(child: Text("Add items using the button below!"))
                      : getListViewPage()),
              items.length == 0
                  ? Center(child: Text("Add items to get a projection!"))
                  : getProjectionView()
            ]),
        bottomNavigationBar: BottomNavigationBar(
          elevation: 10,
          currentIndex: bottomNavBarIndex,
          items: [
            BottomNavigationBarItem(
                title: Text("Items"), icon: Icon(Icons.attach_money)),
            BottomNavigationBarItem(
                title: Text("Projection"), icon: Icon(Icons.trending_up)),
          ],
          onTap: (int index) {
            setState(() {
              bottomNavBarIndex = index;
            });
            pageController.animateToPage(index,
                curve: Curves.easeInOut, duration: Duration(milliseconds: 400));
          },
        ),
        floatingActionButton: bottomNavBarIndex == 0
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (BuildContext context) =>
                              EditItemPage(addItem, itemsContainLoanAmount())));
                },
                tooltip: 'Add Item',
                child: Icon(Icons.add),
              )
            : null);
  }

  // Returns a list view of all the items
  Widget getListViewPage() {
    return SingleChildScrollView(
        child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(GlobalVars.listTileMargin),
            itemCount: items.length + 2,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                // Show the loan section at the very top
                return TitleItem("Items");
              } else if (index == items.length + 1) {
                // Print this text at the end of the list view
                return Container(
                    height: 75,
                    child: Center(
                        child: Text(items.length > 0
                            ? "No more items!"
                            : "Add item using the button below!")));
              }
              // List each item in between the loans view and end text
              return createItemCard(index - 1);
            }));
  }

  List<charts.Series<DataPoint, DateTime>> getRenderData(DateTime minDate,
      DateTime maxDate) {
    List<DataPoint> totalDataPointsInRange = totalData.where((DataPoint
        dataPoint){
      return !dataPoint.x.isAfter(maxDate) && !dataPoint.x.isBefore(minDate);
    }).toList();

    List<charts.Series<DataPoint, DateTime>> _graphData = [
      charts.Series<DataPoint, DateTime>(
          data: totalDataPointsInRange,
          measureFn: (DataPoint datum, _) {
            return datum.y;
          },
          id: "Total",
          domainFn: (DataPoint datum, _) {
            return datum.x;
          })
    ];
    if (itemsContainLoanAmount()) {
      List<DataPoint> totalNoLoanPointsInRange = noLoanData.where((DataPoint
      dataPoint){
        return !dataPoint.x.isAfter(maxDate) && !dataPoint.x.isBefore(minDate);
      }).toList();

      _graphData.add(charts.Series<DataPoint, DateTime>(
          data: totalNoLoanPointsInRange,
          measureFn: (DataPoint datum, _) {
            return datum.y;
          },
          id: "No loan",
          domainFn: (DataPoint datum, _) {
            return datum.x;
          }));
    }
    return _graphData;
  }

  charts.NumericTickProviderSpec getYAxisTickProvider(){
    // 5 ticks
    List<charts.TickSpec<num>> tickSpecs = [];
    
    double maxBalanceBetweenRange = getMaxBalanceBetweenViewRange();
    double minBalanceBetweenRange = getMinBalanceBetweenViewRange();
    int numTicks = 5;
    for(int i = 0; i < numTicks+1; i++){
      charts.TickSpec<num> tickSpec;
      // zero x axis must be visible
      if(maxBalanceBetweenRange > 0 && minBalanceBetweenRange < 0){
        tickSpec = charts.TickSpec<num>(minBalanceBetweenRange +
            (maxBalanceBetweenRange - minBalanceBetweenRange) / numTicks * i);
        // added zero case when both balances add to zero
      }else if(maxBalanceBetweenRange >= 0 && minBalanceBetweenRange >= 0){
        tickSpec = charts.TickSpec<num>(maxBalanceBetweenRange / numTicks * i);
      }else if(maxBalanceBetweenRange < 0 && minBalanceBetweenRange < 0){
        tickSpec = charts.TickSpec<num>(minBalanceBetweenRange / numTicks * (numTicks-i));
      }
      tickSpecs.add(tickSpec);
    }
    return charts.StaticNumericTickProviderSpec(tickSpecs);
  }

  double getMaxBalanceBetweenViewRange(){
    double maxBalance;
    for(DateTime currentDate = viewMinDate; !currentDate.isAfter(viewMaxDate)
    ; currentDate = Date.getDateAfterDuration(currentDate, Duration(days: 1))){
    double balanceAtCurrentDate = totalData.where((DataPoint dataPoint){
          return dataPoint.x == currentDate;
        }).toList()[0].y;
      if(maxBalance == null || balanceAtCurrentDate > maxBalance){
	maxBalance = balanceAtCurrentDate;
      }
    }
    return maxBalance;
  }

  double getMinBalanceBetweenViewRange(){
    double minBalance;
    List<DataPoint> dataToUse = itemsContainLoanAmount() ? noLoanData : totalData;
    for(DateTime currentDate = viewMinDate; !currentDate.isAfter(viewMaxDate)
    ; currentDate = Date.getDateAfterDuration(currentDate, Duration(days: 1))){
    double balanceAtCurrentDate = dataToUse.where((DataPoint dataPoint){
          return dataPoint.x == currentDate;
        }).toList()[0].y;
      if(minBalance == null || balanceAtCurrentDate < minBalance){ 
        minBalance = balanceAtCurrentDate;
      }
    }
    return minBalance;
  }

  // Returns the projection view of the home page
  Widget getProjectionView() {
    return Scrollbar(
        child: SingleChildScrollView(
            padding: EdgeInsets.all(8),
            child: Column(children: [
              // graph card
              Container(
                  height: MediaQuery.of(context).size.height / 2,
                  child: charts.TimeSeriesChart(getRenderData(viewMinDate,
                      viewMaxDate), animate:
                  true,
                      // allows for selecting
                      selectionModels: [
                        charts.SelectionModelConfig(
                            type: charts.SelectionModelType.info,
                            changedListener:
                                (charts.SelectionModel<DateTime> model) {
                              setState(() {
                                DataPoint dataPoint =
                                    model.selectedDatum.first.datum;
                                selectedDate = dataPoint.x;
                                saveVariableToSecureStorage("selectedDate");
                              });
                            }),
                      ],
                      primaryMeasureAxis: charts.NumericAxisSpec(tickProviderSpec: getYAxisTickProvider()),
                      behaviors: [
                    charts.SeriesLegend(),
                    charts.PanAndZoomBehavior(),
                    charts.ChartTitle("Balance Projected Over Time",
                        behaviorPosition: charts.BehaviorPosition.top),
                    charts.ChartTitle("Date",
                        behaviorPosition: charts.BehaviorPosition.bottom,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea,
                        titleStyleSpec: charts.TextStyleSpec(fontSize: 14)),
                    charts.ChartTitle("Balance",
                        behaviorPosition: charts.BehaviorPosition.start,
                        titleOutsideJustification:
                            charts.OutsideJustification.middleDrawArea,
                        titleStyleSpec: charts.TextStyleSpec(fontSize: 14)),
                  ])),
              TitleItem("Graph Controls / Balance"),
              Column(children: <Widget>[Card(child:Padding(padding: EdgeInsets
                  .all
                (8), child:
              Row
                (mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[RaisedButton(child: Text
                ("Prev"), onPressed: viewMinDate == getEarliestDate() ? null
                      : () {
                    setState(() {
                      if(Date.getDuration(getEarliestDate(), viewMinDate)
                          .inDays <= viewInterval){
                        viewMinDate = getEarliestDate();
                      }else{
                        viewMinDate = Date.getDateBeforeDuration(viewMinDate,
                            Duration(days: viewInterval+1));
                      }
                      viewMaxDate = Date.getDateAfterDuration(viewMinDate,
                          Duration(days: viewInterval));
		      adjustSelectedDateBetweenRange();
		    });
                  },),
                Text(DateFormat("MM/dd/yy").format(viewMinDate) + " - " +
                    DateFormat("MM/dd/yy").format(viewMaxDate)),
                RaisedButton(onPressed: viewMaxDate == endDate ? null : (){
                  setState(() {
                    if(Date.getDuration(viewMaxDate, endDate).inDays <= viewInterval){
                      viewMaxDate = endDate;
                    }else{
                      viewMaxDate = Date.getDateAfterDuration(viewMaxDate,
                          Duration(days: viewInterval+1));
                    }
                    viewMinDate = Date.getDateAfterDuration(viewMinDate,
                        Duration(days: viewInterval+1));
                    adjustSelectedDateBetweenRange();
		  }
		  );
                },
                    child:
                Text("Next"))
              ]))),Row
                (children: [
                Expanded(
                    child: Container(
                        height: 110,
                        child: Card(
                            elevation: GlobalVars.listTileElevation,
                            child: Column(children: [
                              FlatButton(
                                  onPressed: () {
                                    selectDate(
                                        "end",
                                        Date.getDateAfterDuration(
                                            getEarliestDate(),
                                            Duration(days: 1)),
                                        endDate,
                                        DateTime(2070, 1, 1));
                                  },
                                  child: Text(
                                      "End: " +
                                          DateFormat("MM/dd/yyyy")
                                              .format(endDate),
                                      textAlign: TextAlign.center)),
                              FlatButton(
                                  onPressed: () {
                                    selectDate("selected", getEarliestDate(),
                                        selectedDate, endDate);
                                  },
                                  child: Text(
                                    "Selected: " +
                                        DateFormat("MM/dd/yyyy")
                                            .format(selectedDate),
                                    textAlign: TextAlign.center,
                                  )),
                            ])))),
                // use a flexible to fill up the remaining space
                Expanded(
                    child: Container(
                        height: 110,
                        child: Card(
                          elevation: GlobalVars.listTileElevation,
                          child: Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Text(
                                    "Balance: " +
                                        NumberFormat.simpleCurrency()
                                            .format(getTotalBalanceAtDate(
                                                selectedDate))
                                            .toString(),
                                    style: TextStyle(color: Colors.blue),
                                    textAlign: TextAlign.center),
                                itemsContainLoanAmount()
                                    ? Text(
                                        "Without Loans: " +
                                            NumberFormat.simpleCurrency()
                                                .format(getNoLoanBalanceAtDate(
                                                    selectedDate))
                                                .toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.red),
                                      )
                                    : Container()
                              ])),
                        ))),
              ])]),
              getItemsOnDate(selectedDate).length != 0
                  ? Column(children: [
                      TitleItem(getItemsOnDate(selectedDate).length.toString() +
                          " Items Applied (" +
                          NumberFormat.simpleCurrency()
                              .format(selectedDate != getEarliestDate()
                                  ? getBalanceDiffAtDate(selectedDate)
                                  : getTotalBalanceAtDate(selectedDate))
                              .toString() +
                          ")"),
                      ListView.builder(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: getItemsOnDate(selectedDate).length,
                          itemBuilder: (BuildContext context, int index) {
                            return createItemCard(getItemsOnDate(selectedDate)
                                .keys
                                .toList()[index]);
                          })
                    ])
                  : Container(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "No items applied on this date!",
                        style: TextStyle(fontSize: 12),
                      ))
            ])));
  }

  void adjustSelectedDateBetweenRange(){
    if(selectedDate.isBefore(viewMinDate) || selectedDate.isAfter(viewMaxDate)){
      selectedDate = viewMinDate;
    }
  }

  // Prompts user whether to clear all items or not, and handles removing all items
  void showClearAllDialog() {
    showDialog(
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Clear All"),
            content: Text("Clear all items?"),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    // Just exit the prompt
                    Navigator.pop(context);
                  },
                  child: Text("No")),
              FlatButton(
                  onPressed: () {
                    setState(() {
                      // Remove each item, and save the empty list once we delete the last item
                      clearItems();
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Yes")),
            ],
          );
        },
        context: context);
  }

  // TODO: add items to dispose
  @override
  void dispose() {
    super.dispose();
  }

  // Iterates through all the items, and tells if at least one of them is a loan
  bool itemsContainLoanAmount() {
    for (Item item in items) {
      if (item.loanAmount != 0) {
        return true;
      }
    }
    return false;
  }

  // Graph functions

  /* Generates lists of DataPoints for the graph. Generates a series for the total
   * balance between a date range, and another series for a similar balance without
   * accounting for loan balances. */
  void generateGraphData() {
    assert(selectedDate != null);
    // Clear existing data before adding datapoints
    totalData = [];
    noLoanData = [];
    double totalBalance = 0, totalBalanceWithoutLoans = 0;

    // keep track of interest accruing over the month
    double interestForMonth = 0;

    for (DateTime _currentDate = getEarliestDate();
        !_currentDate.isAfter(endDate);
        _currentDate =
            Date.getDateAfterDuration(_currentDate, Duration(days: 1))) {
      /* Sum up the item amounts that apply on this date, and add it to the total
       * balance for the currently iterated date */
      Map<int, Item> itemsOnDate = getItemsOnDate(_currentDate);
      double itemAmountsSum = 0;
      /* Also sum up the loan amounts for each item, and subtract it from
       * the current no-loan balance */
      double itemLoanAmountsSum = 0;
      // Amount in loan repayments
      double loanRepaymentsSum = 0;
      /* Don't generate another datapoint if the only change in balance is because
       * of a daily item. Only generate if the balance is about to change by a non-daily item. */
      for (Item item in itemsOnDate.values) {
        // If the item is disabled, don't count it and move on to the next item
        if (!item.enabled) continue;
        itemAmountsSum += item.amount;
        if (item.loanAmount > 0) {
          itemLoanAmountsSum += item.loanAmount;
        } else if (item.repayLoan) {
          /* Repay a loan. Since the amount is negative (the user is paying for it)
           * we have to make it positive */
          loanRepaymentsSum += -item.amount;
        }
      }
      totalBalance += itemAmountsSum;
      totalBalanceWithoutLoans +=
          itemAmountsSum - itemLoanAmountsSum + loanRepaymentsSum;
/*
      // Calculate savings apy interest each day
      double savingsApy = 2;
      // Dont pay 500 of the total balance owned in bank acc
      interestForMonth += (totalBalance-500)*(savingsApy/(100.0*30));
      // Add interest to the end of the month
      if(_currentDate == Date.getLastDateOfMonth(_currentDate)){ 
        totalBalance += interestForMonth;
        totalBalanceWithoutLoans += interestForMonth;
        interestForMonth = 0;
      }
*/
      DataPoint dataPoint = DataPoint(_currentDate, totalBalance);
      DataPoint dataPointForNoLoans =
          DataPoint(_currentDate, totalBalanceWithoutLoans);

      totalData.add(dataPoint);
      noLoanData.add(dataPointForNoLoans);
    }

    // Get the render date bounds
    setViewDates();
  }

  void setViewDates(){
    viewMinDate = getEarliestDate();
    while(!Date.getDateAfterDuration(viewMinDate, Duration(days: viewInterval+1)).isAfter
      (selectedDate)){
      viewMinDate = Date.getDateAfterDuration((viewMinDate), Duration(days:
      viewInterval+1));
    }
    DateTime ninetyDaysAfterViewMinDate = Date
        .getDateAfterDuration(viewMinDate, Duration(days: viewInterval));
    viewMaxDate = Date.getDuration(viewMinDate, endDate).inDays <= viewInterval ? endDate
        : ninetyDaysAfterViewMinDate;
  }

  // Iterate through each item to find the earliest start date
  DateTime getEarliestDate() {
    DateTime earliestDate;
    for (Item item in items) {
      if (earliestDate == null) {
        earliestDate = item.startDate;
      } else {
        if (earliestDate.isAfter(item.startDate)) {
          earliestDate = item.startDate;
        }
      }
    }
    return earliestDate;
  }

  // Callback functions

  // Set the selected date and show the projection view
  void showGraphAtSelectedDate(BuildContext _context, DateTime dateTime) {
    selectedDate = dateTime;
    saveVariableToSecureStorage("selectedDate");
    // Show animation if we are at the homepage
    if (_context == context) {
      pageController.animateToPage(1,
          curve: Curves.easeInOut, duration: Duration(milliseconds: 400));
    } else {
      // No animation
      pageController.jumpToPage(1);
    }
  }

  /* Add an item to the homepage. Can optionally specify an index in the list */
  void addItem(Item item, {int index, bool loadingFromSharedPrefs = false}) {
    setState(() {
      index == null ? items.add(item) : items.insert(index, item);

      /* If we are loading from file or SharedPrefs, we already know the dates so
       * don't bother configuring them again until the very end
       */
      if (!loadingFromSharedPrefs) {
        if (items.length == 1) {
          /* Set the default selected date and end date if this is the first item to
         * be added */
          selectedDate = getEarliestDate();
          endDate =
              Date.getDateAfterDuration(selectedDate, Duration(days: 365));
        } else {
          /* Push end date forward to a year after this item's start date, since
           * this item starts after the end date and we want to be able to see the
           * graph render this item too
           */
          if (item.startDate.isAfter(endDate)) {
            endDate =
                Date.getDateAfterDuration(selectedDate, Duration(days: 365));
          }
        }
        // Save the new item to SharedPreference since the user just added it
        // And save the variables in case they were edited by this new item
        saveVariableToSecureStorage("selectedDate");
        saveVariableToSecureStorage("endDate");
        addItemToSecureStorage(item, index);
        // Generate the graph data with the new item and dates
        // Don't bother generating the data when adding items from SharedPrefs.
        // Only generate after the last item was added and the dates were already loaded
        generateGraphData();
      }
    });
  }

  // For editing items from the homepage
  void editItem(Item item, [bool showUndoSnackBar = true]) {
    setState(() {
      /* Save unedited item first, in case we need to undo this edit. This only
       * applies if showUndoSnackBar is true */
      Item uneditedItem = items[currentlyEditedItemIndex];
      // Apply the edits
      items[currentlyEditedItemIndex] = item;
      // Push end limit if the edited item's start date is now after it
      if (items[currentlyEditedItemIndex].startDate.isAfter(endDate)) {
        endDate = Date.getDateAfterDuration(
            items[currentlyEditedItemIndex].startDate, Duration(days: 365));
      }
      // Push selected date forward if the earliest date is after it
      if (selectedDate.isBefore(getEarliestDate())) {
        selectedDate = getEarliestDate();
      }
      generateGraphData();

      // Save edits to storage
      editItemInSecureStorage();
      saveVariableToSecureStorage("selectedDate");
      saveVariableToSecureStorage("endDate");

      // Show snackbar allowing user to undo edits
      if (showUndoSnackBar) {
        SnackBar snackBar = SnackBar(
            content: Text(
                "Undo edit item '${items[currentlyEditedItemIndex].name}'?"),
            action: SnackBarAction(
                label: "UNDO",
                onPressed: () {
                  editItem(uneditedItem, false);
                  // Show another SnackBar when user undos the edit
                  SnackBar undoSuccessSnackBar = SnackBar(
                      content: Text(
                          "Changes reverted to item '${uneditedItem.name}'"),
                      action: SnackBarAction(
                          label: "DISMISS",
                          onPressed: () {
                            scaffoldGlobalKey.currentState
                                .hideCurrentSnackBar();
                          }));
                  scaffoldGlobalKey.currentState
                      .showSnackBar(undoSuccessSnackBar);
                }));
        // Immediately hide any snackbar before showing the UNDO snackbar. This
        // will prevent errors when undoing edits
        scaffoldGlobalKey.currentState.hideCurrentSnackBar();
        scaffoldGlobalKey.currentState.showSnackBar(snackBar);
      }
    });
  }

  // For removing items
  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
      // Update the graph if there are still items left
      if (items.length > 0) {
        // Update graph dates
        if (selectedDate.isBefore(getEarliestDate())) {
          selectedDate = getEarliestDate();
        }
        // Only regenerate graph data if we are told to
        generateGraphData();
      }
    });
    // Remove the item from json list
    removeItemFromSecureStorage(index);
    if(items.isNotEmpty) saveVariableToSecureStorage("selectedDate");
  }

  void copyItem(int index) {
    Item itemCopy = Item.copy(items[index]);
    addItem(itemCopy, index: index);
  }

  // Clear items one by one, save the items list after removing the last item if enabled
  void clearItems() {
    for (int i = items.length - 1; i >= 0; i--) {
      // Don't regenerate graph data since we are clearing all the items
      removeItem(i);
    }
  }

  // Show a date picker for the given variable, with specified date bounds and initial selected date
  void selectDate(String variable, DateTime firstDate, DateTime initialDate,
      DateTime lastDate) async {
    DateTime inputDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate);
    if (inputDate != null) {
      DateTime newDate =
          DateTime(inputDate.year, inputDate.month, inputDate.day);
      setState(() {
        if (variable == "selected") {
          selectedDate = newDate;
          saveVariableToSecureStorage("selectedDate");
        } else if (variable == "end") {
          endDate = newDate;
          saveVariableToSecureStorage("endDate");
          // move selected date back if it is after end date
          if (selectedDate.isAfter(endDate)) {
            selectedDate = endDate;
            saveVariableToSecureStorage("selectedDate");
          }
          generateGraphData();
        }
      });
    }
  }

  // Create an item card
  Widget createItemCard(int index) {
    Offset tapPosition;
    return GestureDetector(
        onTapDown: (TapDownDetails tapDownDetails) {
          tapPosition = tapDownDetails.globalPosition;
        },
        child: Card(
          color: items[index].enabled
              ? Colors.white
              : Color.fromARGB(128, 255, 255, 255),
          elevation: GlobalVars.listTileElevation,
          child: ListTile(
              // Tap a list tile to edit an item
              onTap: () {
                currentlyEditedItemIndex = index;
                Navigator.push(context,
                    MaterialPageRoute(builder: (BuildContext context) {
                  return EditItemPage.edit(
                      editItem,
                      items[currentlyEditedItemIndex],
                      itemsContainLoanAmount());
                }));
              },
              onLongPress: () {
                showMenu(
                    context: context,
                    position: RelativeRect.fromRect(tapPosition & Size(0, 0),
                        Offset(0, 0) & MediaQuery.of(context).size),
                    items: [
                      PopupMenuItem<String>(
                          value: "showDetails",
                          child: Text(items[index].frequency == Frequency.ONCE
                              ? "Go to Date"
                              : "Show Details")),
                      PopupMenuItem<String>(value: "copy", child: Text("Copy")),
                      PopupMenuItem<String>(value: "edit", child: Text("Edit")),
                      PopupMenuItem<String>(
                          value: "toggleDisable",
                          child: Text(
                              items[index].enabled ? "Disable" : "Enable")),
                      PopupMenuItem<String>(
                          value: "remove", child: Text("Remove")),
                    ]).then((String value) {
                  if (value == "copy") {
                    copyItem(index);
                  } else if (value == "toggleDisable") {
                    setState(() {
                      items[index].enabled = !items[index].enabled;
                      // Generate graph data again with the item added/removed
                      generateGraphData();
                    });
                    // Save the changed enabled flag in SharedPrefs
                    currentlyEditedItemIndex = index;
                    editItemInSecureStorage(items[index].enabled);
                  } else if (value == "edit") {
                    currentlyEditedItemIndex = index;
                    Navigator.push(context,
                        MaterialPageRoute(builder: (BuildContext context) {
                      return EditItemPage.edit(
                          editItem,
                          items[currentlyEditedItemIndex],
                          itemsContainLoanAmount());
                    }));
                  } else if (value == "remove") {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("Remove Item"),
                          content: Text("Remove item '${items[index].name}'?"),
                          actions: <Widget>[
                            FlatButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text("No")),
                            FlatButton(
                                onPressed: () {
                                  setState(() {
                                    Item removedItem = items[index];
                                    removeItem(index);
                                    SnackBar snackBar = SnackBar(
                                      content: Text(
                                          "Undo remove item '${removedItem.name}'?"),
                                      action: SnackBarAction(
                                          label: "UNDO",
                                          onPressed: () {
                                            addItem(removedItem, index: index);
                                            scaffoldGlobalKey.currentState
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        "Item '${removedItem.name}' added back"),
                                                    action: SnackBarAction(
                                                        label: "DISMISS",
                                                        onPressed: () {
                                                          scaffoldGlobalKey
                                                              .currentState
                                                              .hideCurrentSnackBar();
                                                        })));
                                          }),
                                    );
                                    // Immediately hide any snackbar before showing the UNDO snackbar. This
                                    // will prevent index errors when adding back items
                                    scaffoldGlobalKey.currentState.hideCurrentSnackBar();
                                    scaffoldGlobalKey.currentState
                                        .showSnackBar(snackBar);
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text("Yes")),
                          ],
                        );
                      },
                    );
                  } else if (value == "showDetails") {
                    /* Pick a date and show the graph at that date. Send a callback
                     * function to the ItemDetailsPage so we can get that date. */
                    if (items[index].frequency == Frequency.ONCE) {
                      // There is only one applied date if the item is applied once
                      showGraphAtSelectedDate(context, items[index].startDate);
                    } else {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (BuildContext context) {
                        return ItemDetailsPage(
                            items[index].name,
                            getAppliedDatesOfItem(items[index]),
                            showGraphAtSelectedDate);
                      }));
                    }
                  }
                });
              },

              // Template for each list tile
              contentPadding: EdgeInsets.all(12),
              leading: items[index].amount > 0
                  ? Icon(Icons.trending_up)
                  : Icon(Icons.trending_down),
              trailing: Text("Started: " +
                  DateFormat("MM/dd/yyyy").format(items[index].startDate) +
                  (items[index].lastDate != null
                      ? "\nLast Date: " +
                          DateFormat("MM/dd/yyyy").format(items[index].lastDate)
                      : "")),
              title: Text(items[index].name, style: TextStyle(fontSize: 20)),
              subtitle: Text(NumberFormat.simpleCurrency()
                      .format(items[index].amount)
                      .toString() +
                  " (" +
                  FreqConvert.freqToString(items[index].frequency) +
                  ")")),
        ));
  }

  // Returns a list of items on a date and their indices from the list. Store in
  // a map instead of a list because we want to save the index the item came from
  // This allows createItemCard() to find the right item on the list by index
  Map<int, Item> getItemsOnDate(DateTime selectedDate) {
    Map<int, Item> itemsWithOriginalIndex = Map<int, Item>();
    for (Item item in items) {
      // Don't count an item if it ended before the selected date or started after the selected date
      if ((item.lastDate != null && selectedDate.isAfter(item.lastDate)) ||
          selectedDate.isBefore(item.startDate)) {
        continue;
      }
      switch (item.frequency) {
        case Frequency.DAILY:
          itemsWithOriginalIndex[items.indexOf(item)] = item;
          break;
        case Frequency.WEEKLY:
          if (item.startDate.weekday == selectedDate.weekday) {
            itemsWithOriginalIndex[items.indexOf(item)] = item;
          }
          break;
        case Frequency.MONTHLY:
          /* Either the numerical day is the same, or we are on the last day
           * of the month and the item's start date is on a numerical day greater than it */
          if (item.startDate.day == selectedDate.day ||
              (selectedDate == Date.getLastDateOfMonth(selectedDate) &&
                  item.startDate.day >
                      Date.getLastDateOfMonth(selectedDate).day)) {
            itemsWithOriginalIndex[items.indexOf(item)] = item;
          }
          break;
        case Frequency.ANNUALLY:
          // The same as MONTHLY's condition, but the month must be the same too
          if (item.startDate.month == selectedDate.month &&
              (item.startDate.day == selectedDate.day ||
                  (selectedDate == Date.getLastDateOfMonth(selectedDate) &&
                      item.startDate.day >
                          Date.getLastDateOfMonth(selectedDate).day))) {
            itemsWithOriginalIndex[items.indexOf(item)] = item;
          }
          break;
        case Frequency.ONCE:
          if (item.startDate == selectedDate) {
            itemsWithOriginalIndex[items.indexOf(item)] = item;
          }
          break;
        case Frequency.CUSTOM:
          // The item must apply every given amount of days
          if (Date.getDuration(item.startDate, selectedDate).inDays %
                  item.daysFrequency ==
              0) {
            itemsWithOriginalIndex[items.indexOf(item)] = item;
          }
          break;
      }
    }
    return itemsWithOriginalIndex;
  }

  // Get a list of the dates that an item will be applied to
  List<DateTime> getAppliedDatesOfItem(Item item) {
    // Start from the earliest date and continue until the loop exceeds the end date
    DateTime currentDate = getEarliestDate();
    List<DateTime> dates = [];
    while (!currentDate.isAfter(endDate)) {
      List<Item> itemsAppliedOnDate =
          getItemsOnDate(currentDate).values.toList();
      if (itemsAppliedOnDate.contains(item)) {
        dates.add(currentDate);
      }
      currentDate = Date.getDateAfterDuration(currentDate, Duration(days: 1));
    }
    return dates;
  }

  // Get the balance difference of a certain date
  double getBalanceDiffAtDate(DateTime selectedDate) {
    double balance = 0;
    for (Item item in getItemsOnDate(selectedDate).values) {
      if(item.enabled) balance += item.amount;
    }
    return balance;
  }

  // Get the balance difference of a certain date
  double getTotalBalanceAtDate(DateTime selectedDate) {
    double balance = totalData
        .where((DataPoint dataPoint) {
          return selectedDate == dataPoint.x;
        })
        .toList()[0]
        .y;
    return balance;
  }

  // Get the balance of a certain date in the no loan series of the graph
  double getNoLoanBalanceAtDate(DateTime selectedDate) {
    double balance = noLoanData
        .where((DataPoint dataPoint) {
          return selectedDate == dataPoint.x;
        })
        .toList()[0]
        .y;
    return balance;
  }

  /* Shared Preference functions. Shared Preferences allows the user to load
   * data when starting up the app. */

  /* Get all the variables saved in SharedPreferences, and return the values of
   * those variables in a list */
  void loadDataFromSecureStorage() async {
    // If storage has no keys, map the items key to an empty list so we can
    // add items later
    String items = await storage.read(key:"items");
    if (items.isEmpty) {
      // Map items key to an empty list so we can add items later
      await storage.write(key:"items", value:"[]");
    }
    // Get each String from Secure Storage using the right keys
    String _selectedDate = await storage.read(key:"selectedDate");
    String _endDate = await storage.read(key:"endDate");

    // Set the variables to the Strings
    addItemsFromEncodedJson(items);
    if (_selectedDate != null) {
      selectedDate = DateTime.parse(_selectedDate);
    }
    if (_endDate != null) {
      endDate = DateTime.parse(_endDate);
    }

    // Finally, generate the graph data if there were items
    if (items.isNotEmpty){
      generateGraphData();
    }
  }

  /* Add item to the end of the list of items saved in Secure Storage, unless an
   * index is specified */
  void addItemToSecureStorage(Item item, [int index]) async {
    String list = await storage.read(key:"items");
    List<dynamic> decodedList = jsonDecode(list);

    // Create a map to represent the new item and set its attributes
    Map<String, dynamic> jsonItem = Map<String, dynamic>();
    jsonItem["name"] = item.name;
    jsonItem["amount"] = item.amount;
    jsonItem["frequency"] = FreqConvert.freqToString(item.frequency);
    jsonItem["startDate"] = DateFormat("yyyyMMdd").format(item.startDate);
    if (item.lastDate != null) {
      jsonItem["lastDate"] = DateFormat("yyyyMMdd").format(item.lastDate);
    }
    if (item.loanAmount != 0) {
      jsonItem["loanAmount"] = item.loanAmount;
    }
    if (item.daysFrequency != 0) {
      jsonItem["daysFrequency"] = item.daysFrequency;
    }
    if (item.repayLoan == true) {
      jsonItem["repayLoan"] = item.repayLoan;
    }
    if (item.enabled == false) {
      jsonItem["enabled"] = item.enabled;
    }

    // Store the item in the list, then encode and save it to SecureStorage
    if (index == null) {
      decodedList.add(jsonItem);
    } else {
      decodedList.insert(index, jsonItem);
    }
    String encodedList = jsonEncode(decodedList);
    await storage.write(key:"items", value:encodedList);
  }

  // Edit an item in SecureStorage
  void editItemInSecureStorage([bool enabled]) async {
    // Retrieve the string and decode it into a list of maps
    String list = await storage.read(key:"items");
    List<dynamic> decodedList = jsonDecode(list);

    if (enabled != null) {
      // Only edit enabled if it is passed into this function, then exit
      if (!enabled)
        decodedList[currentlyEditedItemIndex]["enabled"] = enabled;
      else
        decodedList[currentlyEditedItemIndex].remove("enabled");
    } else {
      /* Convert some of the item's entries from their types to String. */
      String _frequency =
          FreqConvert.freqToString(items[currentlyEditedItemIndex].frequency);
      String _startDate = DateFormat("yyyyMMdd")
          .format(items[currentlyEditedItemIndex].startDate);
      String _lastDate = items[currentlyEditedItemIndex].lastDate != null
          ? DateFormat("yyyyMMdd")
              .format(items[currentlyEditedItemIndex].lastDate)
          : null;

      /* Set the entries of the map representing the item to the item's entries in String form.
     * If the entry is null, don't store it in the decoded list.*/
      decodedList[currentlyEditedItemIndex]["name"] =
          items[currentlyEditedItemIndex].name;
      decodedList[currentlyEditedItemIndex]["amount"] =
          items[currentlyEditedItemIndex].amount;
      decodedList[currentlyEditedItemIndex]["frequency"] = _frequency;
      decodedList[currentlyEditedItemIndex]["startDate"] = _startDate;
      if (_lastDate != null) {
        decodedList[currentlyEditedItemIndex]["lastDate"] = _lastDate;
      } else {
        decodedList[currentlyEditedItemIndex].remove("lastDate");
      }
      if (items[currentlyEditedItemIndex].loanAmount != 0) {
        decodedList[currentlyEditedItemIndex]["loanAmount"] =
            items[currentlyEditedItemIndex].loanAmount;
      } else {
        decodedList[currentlyEditedItemIndex].remove("loanAmount");
      }
      if (items[currentlyEditedItemIndex].daysFrequency != 0) {
        decodedList[currentlyEditedItemIndex]["daysFrequency"] =
            items[currentlyEditedItemIndex].daysFrequency;
      } else {
        decodedList[currentlyEditedItemIndex].remove("daysFrequency");
      }
      if (items[currentlyEditedItemIndex].repayLoan != false) {
        decodedList[currentlyEditedItemIndex]["repayLoan"] =
            items[currentlyEditedItemIndex].repayLoan;
      } else {
        decodedList[currentlyEditedItemIndex].remove("repayLoan");
      }
      if (items[currentlyEditedItemIndex].enabled == false) {
        decodedList[currentlyEditedItemIndex]["enabled"] =
            items[currentlyEditedItemIndex].enabled;
      } else {
        decodedList[currentlyEditedItemIndex].remove("enabled");
      }
    }
    // Encode and restore the list into SecureStorage
    String encodedList = jsonEncode(decodedList);
    await storage.write(key:"items", value:encodedList);
  }

  // Remove an item from SecureStorage
  void removeItemFromSecureStorage(int index) async {
    // Get the String from SecureStorage and decode it into a list
    String list = await storage.read(key:"items");
    List<dynamic> decodedList = jsonDecode(list);
    // Remove item, then encode and restore the list into SecureStorage
    for (int i = 0; i < decodedList.length; i++) {
      if (i == index) {
        decodedList.removeAt(i);
      }
    }
    String encodedList = jsonEncode(decodedList);
    await storage.write(key:"items", value:encodedList);
  }

  // Save the specified variable to SecureStorage
  void saveVariableToSecureStorage(String variable) async {
    if (variable == "selectedDate") {
      await storage.write(key:variable, value:DateFormat("yyyyMMdd").format
        (selectedDate));
    } else if (variable == "endDate") {
      await storage.write(key:variable, value:DateFormat("yyyyMMdd").format
        (endDate));
    }
    setViewDates();
  }

  // Decodes a json encoded string and converts the data into a list of items
  void addItemsFromEncodedJson(String jsonString) {
    // Decode the json string into a list of maps, and convert each map into an item
    List<dynamic> itemMaps = json.decode(jsonString);
    for (int i = 0; i < itemMaps.length; i++) {
      // Some items have to be converted from string to the right type
      Frequency frequency =
          FreqConvert.stringToFrequency(itemMaps[i]['frequency']);
      DateTime startDate = DateTime.parse(itemMaps[i]['startDate']);

      /* Some entries are optional, so they wont exist. Perform null checks
         * and pass in default values for "null" entries when creating the item */
      DateTime lastDate = itemMaps[i]['lastDate'] != null
          ? DateTime.parse(itemMaps[i]['lastDate'])
          : null;
      double loanAmount =
          itemMaps[i]['loanAmount'] != null ? itemMaps[i]['loanAmount'] : 0;
      int daysFrequency = itemMaps[i]['daysFrequency'] != null
          ? itemMaps[i]['daysFrequency']
          : 0;
      bool repayLoan =
          itemMaps[i]['repayLoan'] != null ? itemMaps[i]['repayLoan'] : false;
      bool enabled =
          itemMaps[i]['enabled'] != null ? itemMaps[i]['enabled'] : true;
      // Pass the data into the Item constructor
      Item item = Item(
          itemMaps[i]['name'], itemMaps[i]['amount'], frequency, startDate,
          lastDate: lastDate,
          loanAmount: loanAmount,
          daysFrequency: daysFrequency,
          repayLoan: repayLoan,
          enabled: enabled);

      /* Add new item to the homepage. Don't save it to SharedPrefs again so set the flag */
      addItem(item, loadingFromSharedPrefs: true);
    }
  }
}
