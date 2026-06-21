import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  bool get _sr => locale.languageCode == 'sr';

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ── Navigation ──────────────────────────────────────────────────────────────
  String get navHome => _sr ? 'Početna' : 'Home';
  String get navBook => _sr ? 'Rezerviši' : 'Book';
  String get navNotifications => _sr ? 'Obaveštenja' : 'Notifications';
  String get navProfile => _sr ? 'Profil' : 'Profile';

  // ── Common ───────────────────────────────────────────────────────────────────
  String get cancelButton => _sr ? 'Otkaži' : 'Cancel';
  String get saveButton => _sr ? 'Sačuvaj' : 'Save';
  String get sendLinkButton => _sr ? 'Pošalji link' : 'Send link';
  String get createButton => _sr ? 'Kreiraj' : 'Create';
  String get deleteButton => _sr ? 'Obriši' : 'Delete';
  String get assignButton => _sr ? 'Dodeli' : 'Assign';
  String get required => _sr ? 'Obavezno' : 'Required';
  String get enterValidNumber => _sr ? 'Unesite važeći broj' : 'Enter valid number';
  String get completed => _sr ? 'Završeno' : 'Completed';
  String get inactive => _sr ? 'Neaktivno' : 'Inactive';
  String get noBookingsFound => _sr ? 'Nije moguće učitati podatke' : 'User data error';

  // ── Login screen ─────────────────────────────────────────────────────────────
  String get welcomeBack => _sr ? 'Dobrodošli!' : 'Welcome back!';
  String get createYourAccount => _sr ? 'Kreiranje naloga' : 'Create your account';
  String get firstNameLabel => _sr ? 'Ime' : 'First Name';
  String get lastNameLabel => _sr ? 'Prezime' : 'Last Name';
  String get emailLabel => _sr ? 'Email' : 'Email';
  String get passwordLabel => _sr ? 'Lozinka' : 'Password';
  String get signInButton => _sr ? 'Prijavite se' : 'Sign In';
  String get createAccountButton => _sr ? 'Kreiraj nalog' : 'Create Account';
  String get registerButton => _sr ? 'Registrujte se' : 'Register';
  String get signInLink => _sr ? 'Prijavite se' : 'Sign in';
  String get forgotPassword => _sr ? 'Zaboravili ste lozinku?' : 'Forgot password?';
  String get noAccount => _sr ? 'Nemate nalog?' : "Don't have an account?";
  String get alreadyHaveAccount => _sr ? 'Već imate nalog?' : 'Already have an account?';
  String get byRegisteringAgree => _sr ? 'Registracijom prihvatate našu ' : 'By registering you agree to our ';
  String get privacyPolicy => _sr ? 'Politiku privatnosti' : 'Privacy Policy';
  String get resetPasswordTitle => _sr ? 'Resetuj lozinku' : 'Reset password';
  String get resetPasswordDesc => _sr
      ? "Unesite Vaš email i poslaćemo Vam link za resetovanje."
      : "Enter your email and we'll send you a reset link.";
  String get wrongEmailOrPassword => _sr ? 'Pogrešan email ili lozinka.' : 'Wrong email or password.';
  String get emailAlreadyRegistered => _sr ? 'Ovaj email je već registrovan.' : 'This email is already registered.';
  String get invalidEmailFormat => _sr ? 'Nevažeći format emaila.' : 'Invalid email format.';
  String get authenticationFailed => _sr ? 'Autentikacija nije uspela.' : 'Authentication failed.';
  String get failedToSendResetEmail => _sr ? 'Slanje emaila za resetovanje nije uspelo.' : 'Failed to send reset email.';

  String passwordResetEmailSent(String email) =>
      _sr ? 'Email za resetovanje lozinke poslat na $email' : 'Password reset email sent to $email';

  // ── Profile screen ───────────────────────────────────────────────────────────
  String get profileTitle => _sr ? 'Profil' : 'Profile';
  String get logoutButton => _sr ? 'Odjavi se' : 'Logout';
  String get logoutConfirm => _sr ? 'Da li ste sigurni da se želite odjaviti?' : 'Are you sure you want to logout?';
  String get unableToLoadProfile => _sr ? 'Nije moguće učitati profil' : 'Unable to load profile';
  String get accountSection => _sr ? 'Nalog' : 'Account';
  String get changePasswordTitle => _sr ? 'Promeni lozinku' : 'Change Password';
  String get changePasswordSubtitle => _sr ? 'Pošalji link za resetovanje na Vaš email' : 'Send a reset link to your email';
  String get preferencesTitle => _sr ? 'Podešavanja' : 'Preferences';
  String get notificationsOn => _sr ? 'Obaveštenja: uključena' : 'Notifications: on';
  String get notificationsOff => _sr ? 'Obaveštenja: isključena' : 'Notifications: off';
  String get deleteAccountTitle => _sr ? 'Obriši nalog' : 'Delete Account';
  String get deleteAccountSubtitle => _sr ? 'Trajno obrišite nalog i sve podatke' : 'Permanently remove your account and data';
  String get promotionsSection => _sr ? 'Promocije' : 'Promotions';
  String get promotionHistoryTitle => _sr ? 'Istorija promocija' : 'Promotion History';
  String get noPastPromotions => _sr ? 'Nema prošlih promocija' : 'No past promotions';
  String get legalSection => _sr ? 'Pravno' : 'Legal';
  String get privacyPolicySubtitle => _sr ? 'Kako upravljamo vašim podacima' : 'How we handle your data';
  String get pushNotificationsLabel => _sr ? 'Obaveštenja' : 'Push notifications';
  String get pushNotificationsSubtitle => _sr ? 'Primajte podsetnike pre vaših sesija' : 'Receive reminders before your sessions';
  String get preferencesSaved => _sr ? 'Podešavanja sačuvana' : 'Preferences saved';
  String get languageLabel => _sr ? 'Jezik' : 'Language';
  String get languageEnglish => 'English';
  String get languageSerbian => 'Srpski';

  String changePasswordEmailPrompt(String email) =>
      _sr ? 'Link za resetovanje lozinke biće poslat na:\n\n$email' : 'A password reset link will be sent to:\n\n$email';

  String pastPromotionsCount(int count) {
    if (_sr) {
      if (count == 1) return '1 prošla promocija';
      return '$count prošlih promocija';
    }
    return '$count past promotion${count == 1 ? '' : 's'}';
  }

  // Delete account dialogs
  String get deleteAccountGoogleBody => _sr
      ? 'Ovo će trajno obrisati vaš nalog i sve vaše podatke, uključujući predstojeće rezervacije.\n\nBiće vam zatražena prijava putem Google naloga za potvrdu.\n\nOva radnja ne može biti poništena.'
      : 'This will permanently delete your account and all your data, '
          'including upcoming bookings.\n\n'
          'You will be asked to sign in with Google to confirm.\n\n'
          'This action cannot be undone.';

  String get deleteAccountPasswordBody => _sr
      ? 'Ovo će trajno obrisati vaš nalog i sve vaše podatke, uključujući predstojeće rezervacije.\n\nOva radnja ne može biti poništena.'
      : 'This will permanently delete your account and all your data, '
          'including upcoming bookings.\n\n'
          'This action cannot be undone.';

  String get enterPasswordToConfirm => _sr ? 'Unesite lozinku za potvrdu:' : 'Enter your password to confirm:';
  String get passwordHint => _sr ? 'Lozinka' : 'Password';

  // Promotion history sheet
  String get expiredOn => _sr ? 'Isteklo' : 'Expired';
  String promotionStats(int attended, int booked, int remaining, int used, int total) =>
      _sr ? '$attended pohađano · $booked rezervisano · $remaining neiskorišćeno  |  $used / $total ukupno'
          : '$attended attended · $booked booked · $remaining unused  |  $used / $total total';

  // ── Home screen ───────────────────────────────────────────────────────────────
  String get homeTitle => _sr ? 'Početna' : 'Home';
  String get yourUpcomingSessions => _sr ? 'Vaši predstojeći treninzi' : 'Your upcoming sessions';
  String get quickBook => _sr ? 'Brza rezervacija' : 'Quick book';
  String get upcomingSessionsChip => _sr ? 'Predstojeći treninzi' : 'Upcoming sessions';
  String get noSessionsBookedYet => _sr ? 'Još uvek nemate rezervisane treninge.' : 'You have no sessions booked yet.';
  String get noUpcomingSessionsAvailable => _sr ? 'Trenutno nema dostupnih treninga.' : 'No upcoming sessions available right now.';
  String get lastSession => _sr ? 'Poslednji trening' : 'Last session';
  String get ratedBadge => _sr ? 'Ocenjeno' : 'Rated';
  String get rateButton => _sr ? 'Oceni' : 'Rate';
  String get sessionsSection => _sr ? 'Treninzi' : 'Sessions';
  String get contactForNewPromotion => _sr ? 'Kontaktirajte nas za novu promociju.' : 'Contact us to get a new promotion.';
  String get promotionExpired => _sr ? 'Vaša promocija je istekla.' : 'Your promotion has expired.';
  String get allSessionsUsed => _sr ? 'Iskoristili ste sve treninge u vašim promocijama.' : 'You have used all sessions in your promotions.';
  String get noActivePromotion => _sr ? 'Nemate aktivnu promociju.' : 'You have no active promotion.';
  String get noActivePromotionCard => _sr ? 'Nema aktivne promocije' : 'No active promotion';
  String get contactToPurchase => _sr ? 'Kontaktirajte nas da kupite paket treninga.' : 'Contact us to purchase a session package.';
  String get trialSessionBooked => _sr ? 'Probni trening rezervisana' : 'Trial session booked';
  String get trialSessionDesc => _sr
      ? 'Kontaktirajte studio da kupite paket — vaš probni trening biće uračunat kao prvi.'
      : 'Contact the studio to purchase a package — your trial session will be counted as the first one.';
  String get trialBookingBanner => _sr
      ? 'Nema aktivne promocije — možete rezervisati 1 besplatni probni trening.'
      : 'No active promotion — you can book 1 free trial session.';

  // Status badges
  String get statusCompleted => _sr ? 'Završeno' : 'Completed';
  String get statusExpired => _sr ? 'Isteklo' : 'Expired';
  String get statusUsedUp => _sr ? 'Iskorišćeno' : 'Used up';
  String nLeft(int n) => _sr ? '$n preostalo' : '$n left';
  String expiresOn(String date) => _sr ? 'Ističe $date' : 'Expires $date';
  String sessionsUsed(int used, int total) => _sr ? '$used / $total treninga iskorišćeno' : '$used / $total sessions used';
  String attendedUpcoming(int attended, int booked) => _sr ? '$attended pohađano · $booked predstojeće' : '$attended attended · $booked upcoming';

  // Cancel session dialog
  String get cancelSessionTitle => _sr ? 'Otkazati trening?' : 'Cancel session?';
  String cancelSessionPrompt(String dateTime, bool canCancel) {
    if (_sr) {
      return 'Da li ste sigurni da želite da otkažete trening za $dateTime?\n\n'
          '${canCancel ? 'Kredit za trening biće vraćen na vašu promociju.' : 'Napomena: otkazivanje je dozvoljeno do 12 sati pre treninga — vaš kredit NEĆE biti vraćen.'}';
    }
    return 'Are you sure you want to cancel your session on $dateTime?\n\n'
        '${canCancel ? 'Your session credit will be returned to your promotion.' : 'Note: cancellation is within 12 hours of the session — your credit will NOT be refunded.'}';
  }

  String get keepItButton => _sr ? 'Zadrži trening' : 'Keep it';
  String get yesCancelButton => _sr ? 'Da, otkaži' : 'Yes, cancel';
  String get sessionCancelled => _sr ? 'Trening otkazana' : 'Session cancelled';
  String bookedFor(String dateTime) =>
      _sr ? 'Rezervisano za $dateTime' : 'Booked for $dateTime';
  String bookingFailed(String error) =>
      _sr ? 'Rezervacija nije uspela: $error' : 'Booking failed: $error';
  String errorMsg(String msg) => _sr ? 'Greška: $msg' : 'Error: $msg';

  // Booking tile
  String get cancelledByStudio => _sr ? 'Otkazano od strane studija — kredit vraćen' : 'Cancelled by studio — credit refunded';
  String get cancelUpTo12h => _sr ? 'Otkaži do 12h pre' : 'Cancel up to 12h before';
  String get cancellationWindowPassed => _sr ? 'Prozor za otkazivanje je prošao' : 'Cancellation window passed';
  String get cancelledBadge => _sr ? 'Otkazano' : 'Cancelled';
  String get lockedLabel => _sr ? 'Zaključano' : 'Locked';

  // ── Booking screen ────────────────────────────────────────────────────────────
  String get bookSessionTitle => _sr ? 'Rezerviši trening' : 'Book a Session';
  String noSessionsOnDate(String date) =>
      _sr ? 'Nema treninga za $date' : 'No sessions on $date';
  String sessionBookedFor(String dateTime) =>
      _sr ? 'Trening rezervisana za $dateTime' : 'Session booked for $dateTime';
  String get trialSessionBookedBanner => _sr
      ? 'Probni trening rezervisana — kupite paket za nastavak.'
      : 'Trial session booked — purchase a package to continue.';
  String get noPromotionTrialAvailable => _sr
      ? 'Nema aktivne promocije. Možete rezervisati 1 besplatni probni trening.'
      : 'No active promotion. You can book 1 free trial session.';

  // ── Session card ──────────────────────────────────────────────────────────────
  String get sessionCancelledButton => _sr ? 'Otkazano' : 'Cancelled';
  String get alreadyBooked => _sr ? 'Već rezervisano' : 'Already Booked';
  String get bookingClosed => _sr ? 'Rezervacija zatvorena' : 'Booking Closed';
  String get fullLabel => _sr ? 'Popunjeno' : 'Full';
  String get bookSessionButton => _sr ? 'Rezerviši trening' : 'Book Session';

  // ── Notifications screen ──────────────────────────────────────────────────────
  String get notificationsTitle => _sr ? 'Obaveštenja' : 'Notifications';
  String get noNotifications => _sr ? 'Nema obaveštenja' : 'No notifications';

  // ── Verification screen ───────────────────────────────────────────────────────
  String get verifyEmailTitle => _sr ? 'Verifikujte vaš email' : 'Verify your email';
  String get verificationSentTo => _sr ? 'Poslali smo link za verifikaciju na' : 'We sent a verification link to';
  String get verificationInstructions => _sr
      ? 'Otvorite pristiglu poštu i uđite na link,\nzatim se vratite i pritisnite dugme ispod.'
      : 'Open your inbox and tap the link,\nthen come back and press the button below.';
  String get iVerifiedButton => _sr ? 'Verifikovao/la sam email' : "I've verified my email";
  String get didntGetIt => _sr ? 'Niste dobili?  ' : "Didn't get it?  ";
  String resendIn(int seconds) =>
      _sr ? 'Pošalji ponovo za ${seconds}s' : 'Resend in ${seconds}s';
  String get resendButton => _sr ? 'Pošalji ponovo' : 'Resend';
  String get emailNotVerifiedYet => _sr
      ? 'Email još uvek nije verifikovan. Molimo kliknite na link u pristigloj pošti.'
      : 'Email not verified yet. Please click the link in your inbox.';
  String get verificationEmailResent => _sr ? 'Email za verifikaciju je ponovo poslat.' : 'Verification email resent.';
  String get backToRegistration => _sr ? 'Nazad na registraciju' : 'Back to registration';

  // ── Completed sessions sheet ──────────────────────────────────────────────────
  String get completedSessionsTitle => _sr ? 'Završeni treninzi' : 'Completed Sessions';
  String get noCompletedSessions => _sr ? 'Još uvek nema završenih treninga.' : 'No completed sessions yet.';
  String get rateSessionTitle => _sr ? 'Ocenite vaš trening' : 'Rate your session';
  String get tapStarToRate => _sr ? 'Dodirnite zvezdu za ocenu' : 'Tap a star to rate';
  String get commentLabel => _sr ? 'Komentar (opciono)' : 'Comment (optional)';
  String get commentHint => _sr ? 'Kakav je bio trening?' : 'How was the session?';
  String get submitButton => _sr ? 'Pošalji' : 'Submit';
  String get pleaseSelectRating => _sr ? 'Molimo odaberite ocenu zvezdicom.' : 'Please select a star rating.';
  String starLabel(int stars) {
    if (_sr) {
      switch (stars) {
        case 1: return 'Loše';
        case 2: return 'Okej';
        case 3: return 'Dobro';
        case 4: return 'Odlično';
        case 5: return 'Izvrsno!';
        default: return '';
      }
    }
    switch (stars) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return '';
    }
  }

  // ── Upcoming booking tile ─────────────────────────────────────────────────────
  String get cancelUntil12h => _sr ? 'Možete otkazati do 12h pre' : 'You can cancel until 12h before';

  // ── Admin shell ───────────────────────────────────────────────────────────────
  String get ownerPanelTitle => _sr ? 'Vlasnikov panel' : 'Owner Panel';
  String get adminPanelTitle => _sr ? 'Admin panel' : 'Admin Panel';
  String get navPackages => _sr ? 'Paketi' : 'Packages';
  String get navPromotions => _sr ? 'Promocije' : 'Promotions';
  String get navSessions => _sr ? 'Treninzi' : 'Sessions';
  String get navRatings => _sr ? 'Ocene' : 'Ratings';
  String get navAssignments => _sr ? 'Dodele' : 'Assignments';

  // ── Admin packages screen ─────────────────────────────────────────────────────
  String get noPackagesYet => _sr ? 'Još nema paketa.' : 'No packages yet.';
  String nSessions(int n) => _sr ? '$n treninga' : '$n sessions';
  String get newPackageButton => _sr ? 'Novi paket' : 'New Package';
  String get newPackageTitle => _sr ? 'Novi paket' : 'New Package';
  String get editPackageTitle => _sr ? 'Uredi paket' : 'Edit Package';
  String get packageNameLabel => _sr ? 'Naziv paketa' : 'Package Name';
  String get numberOfSessionsLabel => _sr ? 'Broj treninga' : 'Number of Sessions';
  String get deletePackageTitle => _sr ? 'Obriši paket' : 'Delete Package';
  String deletePackageBody(String name) => _sr
      ? 'Obrisati "$name"? Postojeće promocije koje koriste ovaj paket neće biti ugrožene.'
      : 'Delete "$name"? Existing promotions using this package are not affected.';

  // ── Admin promotions screen ───────────────────────────────────────────────────
  String get noPackagesAvailable => _sr ? 'Nema dostupnih paketa. Najpre kreirajte jedan.' : 'No packages available. Create one first.';
  String assignPromotionTitle(String name) => _sr ? 'Dodeli promociju\n$name' : 'Assign Promotion\n$name';
  String get packageLabel => _sr ? 'Paket' : 'Package';
  String get choosePackageHint => _sr ? 'Odaberite paket' : 'Choose package';
  String packageOption(String name, int n) => _sr ? '$name ($n sesija)' : '$name ($n sessions)';
  String get selectPackageError => _sr ? 'Odaberite paket' : 'Select a package';
  String get expiryDateLabel => _sr ? 'Datum isteka' : 'Expiry Date';
  String get pickExpiryDate => _sr ? 'Odaberite datum isteka' : 'Pick expiry date';
  String get expiryDateRequired => _sr ? 'Datum isteka je obavezan' : 'Expiry date required';
  String promotionAssigned(String email) =>
      _sr ? 'Promocija dodeljena korisniku $email' : 'Promotion assigned to $email';
  String get searchByEmailHint => _sr ? 'Pretraži korisnika po emailu...' : 'Search user by email...';
  String get noUsersFound => _sr ? 'Nisu pronađeni korisnici.' : 'No users found.';

  // ── Admin sessions screen ─────────────────────────────────────────────────────
  String get createSessionTitle => _sr ? 'Kreiraj sesiju' : 'Create Session';
  String get capacityLabel => _sr ? 'Kapacitet' : 'Capacity';
  String get selectStartTime => _sr ? 'Odaberi vreme početka' : 'Select Start Time';
  String get selectEndTime => _sr ? 'Odaberi vreme završetka' : 'Select End Time';
  String get endTimeAfterStart => _sr ? 'Vreme završetka mora biti posle vremena početka.' : 'End time must be after start time.';
  String get createDefaultWeekTitle => _sr ? 'Kreiraj podrazumevane sesije za nedelju' : 'Create Default Week Sessions';
  String createDefaultWeekBody(String weekDate) => _sr
      ? 'Kreira 8 sesija/dan Pon-Pet za nedelju od $weekDate.\n\nJutro: 09:00–13:00\nVeče: 17:00–21:00\nKapacitet: 6'
      : 'Creates 8 sessions/day Mon-Fri for week of $weekDate.\n\nMorning: 09:00–13:00\nEvening: 17:00–21:00\nCapacity: 6';
  String get cancelSessionAdminTitle => _sr ? 'Otkazati sesiju?' : 'Cancel Session?';
  String sessionOnDate(String dateTime) => _sr ? 'Sesija $dateTime' : 'Session on $dateTime';
  String usersWillBeRefunded(int count) => _sr
      ? '$count korisnik${count == 1 ? '' : 'a'} će automatski dobiti povrat kredita za sesiju.'
      : '$count user${count == 1 ? '' : 's'} will have their session credit automatically refunded.';
  String get thisActionCannotBeUndone => _sr ? 'Ova radnja ne može biti poništena.' : 'This action cannot be undone.';
  String get keepSessionButton => _sr ? 'Zadrži sesiju' : 'Keep Session';
  String get cancelSessionButton => _sr ? 'Otkaži sesiju' : 'Cancel Session';
  String get defaultWeekButton => _sr ? 'Podrazumevana nedelja' : 'Default week';
  String get cancelSessionTooltip => _sr ? 'Otkaži sesiju' : 'Cancel session';
  String capacityBooked(int capacity, int booked) =>
      _sr ? 'Kapacitet: $capacity  |  Rezervisano: $booked' : 'Capacity: $capacity  |  Booked: $booked';
  String get noSessionsOnThisDate => _sr ? 'Nema sesija na ovaj datum' : 'No sessions on this date';
  String get defaultWeekCreated => _sr ? 'Podrazumevane sesije za nedelju su kreirane!' : 'Default week sessions created!';
  String defaultWeekSkipped(int skipped) => _sr
      ? 'Gotovo — $skipped slot${skipped == 1 ? '' : 'ova'} preskočeno (već postoji).'
      : 'Done — $skipped slot${skipped == 1 ? '' : 's'} skipped (already exist).';
  String sessionCount(int count) =>
      _sr ? '$count sesija' : '$count session${count == 1 ? '' : 's'}';
  String sessionCancelledWithRefund(int count) => _sr
      ? 'Sesija otkazana. $count kredit${count == 1 ? '' : 'a'} vraćen.'
      : 'Session cancelled. $count credit${count == 1 ? '' : 's'} refunded.';
  String get sessionCancelledSimple => _sr ? 'Sesija otkazana.' : 'Session cancelled.';

  // ── Admin ratings screen ──────────────────────────────────────────────────────
  String get noRatingsYet => _sr ? 'Još nema ocena.' : 'No ratings yet.';
  String ratingCount(int count) =>
      _sr ? '$count ocen${count == 1 ? 'a' : 'a'}' : '$count rating${count == 1 ? '' : 's'}';
  String get sessionDatePrefix => _sr ? 'Sesija: ' : 'Session: ';
  String get ratedDatePrefix => _sr ? 'Ocenjeno: ' : 'Rated: ';

  // ── Admin session attendees screen ────────────────────────────────────────────
  String get loadingAttendees => _sr ? 'Učitavanje učesnika…' : 'Loading attendees…';
  String attendeesBooked(int count, int capacity) {
    if (_sr) {
      return '$count od $capacity ${count == 1 ? 'rezervisano' : 'rezervisano'}';
    }
    return '$count of $capacity ${count == 1 ? 'attendee' : 'attendees'} booked';
  }
  String get noBookingsForSession => _sr ? 'Nema rezervacija za ovu sesiju' : 'No bookings for this session';

  // ── Owner assignments screen ──────────────────────────────────────────────────
  String assignmentCount(int count) =>
      _sr ? '$count ${count == 1 ? 'zadatak' : 'zadataka'}' : '$count assignment${count == 1 ? '' : 's'}';
  String get noAssignments => _sr ? 'Nema zadataka' : 'No assignments';
  String get noAssignmentsOnDate => _sr ? 'Nema zadataka na ovaj datum' : 'No assignments on this date';
  String byName(String name) => _sr ? 'Od $name' : 'By $name';
  String packageSessions(String pkg, int n) =>
      _sr ? '$pkg · $n sesija' : '$pkg · $n sessions';
}

// ─── Delegate ─────────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'sr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
