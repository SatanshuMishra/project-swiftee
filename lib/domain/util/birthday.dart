final DateTime _birthdayCutoff = DateTime(2026, 2, 19, 23, 59, 59, 999);

bool isBirthdayPeriod([DateTime? now]) =>
    (now ?? DateTime.now()).millisecondsSinceEpoch <=
    _birthdayCutoff.millisecondsSinceEpoch;

bool shouldAutoShowBirthdayCard(DateTime now, bool shownThisSession) =>
    isBirthdayPeriod(now) && !shownThisSession;
