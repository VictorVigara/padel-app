import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Padel Stats'**
  String get appTitle;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @newMatch.
  ///
  /// In en, this message translates to:
  /// **'New Match'**
  String get newMatch;

  /// No description provided for @matchHistory.
  ///
  /// In en, this message translates to:
  /// **'Match History'**
  String get matchHistory;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @losses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get losses;

  /// No description provided for @winRate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get winRate;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @opponent.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get opponent;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches yet. Record your first game!'**
  String get noMatches;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @matchType.
  ///
  /// In en, this message translates to:
  /// **'Match Type'**
  String get matchType;

  /// No description provided for @friendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get friendly;

  /// No description provided for @league.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get league;

  /// No description provided for @tournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get tournament;

  /// No description provided for @matchFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get matchFormat;

  /// No description provided for @bestOf3.
  ///
  /// In en, this message translates to:
  /// **'Best of 3'**
  String get bestOf3;

  /// No description provided for @bestOf5.
  ///
  /// In en, this message translates to:
  /// **'Best of 5'**
  String get bestOf5;

  /// No description provided for @singleSet.
  ///
  /// In en, this message translates to:
  /// **'Single Set'**
  String get singleSet;

  /// No description provided for @courtSurface.
  ///
  /// In en, this message translates to:
  /// **'Court Surface'**
  String get courtSurface;

  /// No description provided for @glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get glass;

  /// No description provided for @cement.
  ///
  /// In en, this message translates to:
  /// **'Cement'**
  String get cement;

  /// No description provided for @turf.
  ///
  /// In en, this message translates to:
  /// **'Turf'**
  String get turf;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @opponentName.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get opponentName;

  /// No description provided for @opponent1.
  ///
  /// In en, this message translates to:
  /// **'Opponent 1'**
  String get opponent1;

  /// No description provided for @opponent2.
  ///
  /// In en, this message translates to:
  /// **'Opponent 2'**
  String get opponent2;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Your Partner'**
  String get partner;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get players;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved!'**
  String get profileSaved;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @won.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get won;

  /// No description provided for @lost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get lost;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add Set'**
  String get addSet;

  /// No description provided for @removeSet.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeSet;

  /// No description provided for @team1.
  ///
  /// In en, this message translates to:
  /// **'Your Team'**
  String get team1;

  /// No description provided for @team2.
  ///
  /// In en, this message translates to:
  /// **'Opponents'**
  String get team2;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// No description provided for @matchSaved.
  ///
  /// In en, this message translates to:
  /// **'Match saved!'**
  String get matchSaved;

  /// No description provided for @matchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Match deleted'**
  String get matchDeleted;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this match?'**
  String get confirmDelete;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @doubles.
  ///
  /// In en, this message translates to:
  /// **'Doubles'**
  String get doubles;

  /// No description provided for @singles.
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get singles;

  /// No description provided for @matchDetails.
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get matchDetails;

  /// No description provided for @addStats.
  ///
  /// In en, this message translates to:
  /// **'Add Statistics'**
  String get addStats;

  /// No description provided for @serves.
  ///
  /// In en, this message translates to:
  /// **'Serves'**
  String get serves;

  /// No description provided for @firstServeIn.
  ///
  /// In en, this message translates to:
  /// **'1st Serve In'**
  String get firstServeIn;

  /// No description provided for @firstServeTotal.
  ///
  /// In en, this message translates to:
  /// **'1st Serve Total'**
  String get firstServeTotal;

  /// No description provided for @aces.
  ///
  /// In en, this message translates to:
  /// **'Aces'**
  String get aces;

  /// No description provided for @doubleFaults.
  ///
  /// In en, this message translates to:
  /// **'Double Faults'**
  String get doubleFaults;

  /// No description provided for @shots.
  ///
  /// In en, this message translates to:
  /// **'Shots'**
  String get shots;

  /// No description provided for @winners.
  ///
  /// In en, this message translates to:
  /// **'Winners'**
  String get winners;

  /// No description provided for @unforcedErrors.
  ///
  /// In en, this message translates to:
  /// **'Unforced Errors'**
  String get unforcedErrors;

  /// No description provided for @padelShots.
  ///
  /// In en, this message translates to:
  /// **'Padel Shots'**
  String get padelShots;

  /// No description provided for @bandeja.
  ///
  /// In en, this message translates to:
  /// **'Bandeja'**
  String get bandeja;

  /// No description provided for @vibora.
  ///
  /// In en, this message translates to:
  /// **'Vibora'**
  String get vibora;

  /// No description provided for @smash.
  ///
  /// In en, this message translates to:
  /// **'Smash'**
  String get smash;

  /// No description provided for @lob.
  ///
  /// In en, this message translates to:
  /// **'Lob'**
  String get lob;

  /// No description provided for @volley.
  ///
  /// In en, this message translates to:
  /// **'Volley'**
  String get volley;

  /// No description provided for @vs.
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get vs;

  /// No description provided for @filterMatches.
  ///
  /// In en, this message translates to:
  /// **'Filter Matches'**
  String get filterMatches;

  /// No description provided for @allResults.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allResults;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTypes;

  /// No description provided for @allSurfaces.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allSurfaces;

  /// No description provided for @dateFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get dateFrom;

  /// No description provided for @dateTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get dateTo;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @ratingHistory.
  ///
  /// In en, this message translates to:
  /// **'Rating History'**
  String get ratingHistory;

  /// No description provided for @playMoreMatches.
  ///
  /// In en, this message translates to:
  /// **'Play more matches to see your rating trend'**
  String get playMoreMatches;

  /// No description provided for @noMatchesFilter.
  ///
  /// In en, this message translates to:
  /// **'No matches match your filters'**
  String get noMatchesFilter;

  /// No description provided for @totalMatches.
  ///
  /// In en, this message translates to:
  /// **'Total Matches'**
  String get totalMatches;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @serveStats.
  ///
  /// In en, this message translates to:
  /// **'Serve Stats'**
  String get serveStats;

  /// No description provided for @shotDistribution.
  ///
  /// In en, this message translates to:
  /// **'Shot Distribution'**
  String get shotDistribution;

  /// No description provided for @performanceBySurface.
  ///
  /// In en, this message translates to:
  /// **'By Surface'**
  String get performanceBySurface;

  /// No description provided for @performanceByType.
  ///
  /// In en, this message translates to:
  /// **'By Match Type'**
  String get performanceByType;

  /// No description provided for @winnersVsErrors.
  ///
  /// In en, this message translates to:
  /// **'Winners vs Errors'**
  String get winnersVsErrors;

  /// No description provided for @noStatsYet.
  ///
  /// In en, this message translates to:
  /// **'Record matches with statistics to see your dashboard'**
  String get noStatsYet;

  /// No description provided for @matchesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get matchesPlayed;

  /// No description provided for @acesPerMatch.
  ///
  /// In en, this message translates to:
  /// **'Aces / Match'**
  String get acesPerMatch;

  /// No description provided for @doubleFaultsPerMatch.
  ///
  /// In en, this message translates to:
  /// **'DFs / Match'**
  String get doubleFaultsPerMatch;

  /// No description provided for @avgFirstServe.
  ///
  /// In en, this message translates to:
  /// **'Avg 1st Serve %'**
  String get avgFirstServe;

  /// No description provided for @padelShotBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Padel Shot Breakdown'**
  String get padelShotBreakdown;

  /// No description provided for @searchPlayers.
  ///
  /// In en, this message translates to:
  /// **'Search Players'**
  String get searchPlayers;

  /// No description provided for @selectOpponent.
  ///
  /// In en, this message translates to:
  /// **'Select Opponent'**
  String get selectOpponent;

  /// No description provided for @unregistered.
  ///
  /// In en, this message translates to:
  /// **'Unregistered'**
  String get unregistered;

  /// No description provided for @playerProfile.
  ///
  /// In en, this message translates to:
  /// **'Player Profile'**
  String get playerProfile;

  /// No description provided for @noPlayersFound.
  ///
  /// In en, this message translates to:
  /// **'No players found'**
  String get noPlayersFound;

  /// No description provided for @headToHead.
  ///
  /// In en, this message translates to:
  /// **'Head to Head'**
  String get headToHead;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try logging in instead.'**
  String get emailAlreadyInUse;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get invalidCredentials;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check your internet and try again.'**
  String get networkError;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailed;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @checkEmailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account!'**
  String get checkEmailConfirm;

  /// No description provided for @nameAlreadyTaken.
  ///
  /// In en, this message translates to:
  /// **'This name is already taken. Choose a different one.'**
  String get nameAlreadyTaken;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
