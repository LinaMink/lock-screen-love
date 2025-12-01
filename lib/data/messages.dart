class DailyMessages {
  static final List<String> messages = [
    // Sausis (1-31)
    'Tu esi mano stiprybė!',
    'Myliu tave labiau nei vakar!',
    'Ačiū, kad esi šalia!',
    'Tu esi geriausias dalykas mano gyvenime!',
    'Su tavimi viskas lengviau!',
    'Tu mane įkvėpi kiekvieną dieną!',
    'Džiaugiuosi kiekviena akimirka su tavimi!',
    'Tu esi mano ramybė!',
    'Dėkoju už tave kiekvieną dieną!',
    'Tu esi nuostabus!',

    // Vasaris (32-59)
    'Mano širdis priklauso tau!',
    'Tu esi mano laimė!',
    'Su tavimi jaučiuosi saugi!',
    'Tu man reiški viską!',
    'Myliu tave be galo!',
    'Tu esi mano svajonė!',
    'Kasdien dėkoju likimui už tave!',
    'Tu esi tobulas man!',
    'Su tavimi gyvenimas gražesnis!',
    'Tu esi mano pasaulis!',

    // Kovas (60-90)
    'Myliu tave daugiau nei žodžiais pasakyti!',
    'Tu esi mano viskas!',
    'Su tavimi jaučiuosi pilna!',
    'Tu esi mano šviesa!',
    'Dėkoju už kiekvieną dieną!',
    'Tu esi specialus!',
    'Myliu viską tavyje!',
    'Tu esi mano džiaugsmas!',
    'Su tavimi gyvenimas prasmingas!',
    'Tu esi mano ateitis!',

    // Pridėsime daugiau vėliau...
    // Kol kas kartosime šiuos tekstus
  ];

  // Gauna tekstą pagal metų dieną (1-365)
  static String getMessageForDay(int dayOfYear) {
    // Jei tekstų dar nepakankamai, kartojame
    int index = (dayOfYear - 1) % messages.length;
    return messages[index];
  }

  // Gauna šiandienos tekstą
  static String getTodayMessage() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return getMessageForDay(dayOfYear);
  }
}
