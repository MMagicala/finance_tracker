enum Frequency { DAILY, WEEKLY, MONTHLY, ANNUALLY, ONCE, CUSTOM}

class FreqConvert{
  static String freqToString(Frequency freq) {
    return freq.toString().replaceAll("Frequency.", "").toLowerCase();
  }

  static Frequency stringToFrequency(String freq_string){
    for(Frequency freq in Frequency.values){
      if(freqToString(freq) == freq_string){
        return freq;
      }
    }
    return null;
  }
}