/* The Date class is a wrapper class of all the methods for durations and dates.
 * This is helpful because it disregards daylight savings time, since our app
 * does not use time for its calculations.
 */
class Date{
  // Gets the last date of the month
  static DateTime getLastDateOfMonth(DateTime dateTime) {
    // Year doesn't matter
    DateTime lastDate = DateTime(dateTime.year, dateTime.month + 1, 0);
    return lastDate;
  }

  // Get the date after a duration of time
  static DateTime getDateAfterDuration(DateTime _startingDate, Duration _duration) {
    _startingDate = _startingDate.add(_duration);

    // Don't count daylight savings time
    if (_startingDate.hour == 23) {
      _startingDate = _startingDate.add(Duration(hours: 1));
    } else if (_startingDate.hour == 1) {
      _startingDate = _startingDate.subtract(Duration(hours: 1));
    }

    return _startingDate;
  }

  // Get the date before a duration of time
  static DateTime getDateBeforeDuration(DateTime _startingDate, Duration _duration) {
    _startingDate = _startingDate.subtract(_duration);

    if (_startingDate.hour == 23) {
      _startingDate = _startingDate.add(Duration(hours: 1));
    } else if (_startingDate.hour == 1) {
      _startingDate = _startingDate.subtract(Duration(hours: 1));
    }

    return _startingDate;
  }


  // Get the duration between two dates
  static Duration getDuration(DateTime _endDate, DateTime _startingDate) {
    Duration duration = _startingDate.difference(_endDate);
    // If an hour ahead
    if (duration.inHours % 24 == 1) {
      duration = Duration(days: duration.inDays);
    } else if (duration.inHours % 24 == 23) {
      // If an hour behind
      duration = Duration(days: duration.inDays + 1);
    }
    return duration;
  }

}