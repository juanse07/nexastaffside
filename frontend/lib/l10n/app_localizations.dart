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

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'(555) 123-4567'**
  String get phoneHint;

  /// No description provided for @phoneHelper.
  ///
  /// In en, this message translates to:
  /// **'US format only'**
  String get phoneHelper;

  /// No description provided for @appId.
  ///
  /// In en, this message translates to:
  /// **'App ID (9 digits, optional)'**
  String get appId;

  /// No description provided for @pictureUrl.
  ///
  /// In en, this message translates to:
  /// **'Picture URL (optional)'**
  String get pictureUrl;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedToLoadProfile;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @profilePictureUploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile picture uploaded'**
  String get profilePictureUploaded;

  /// No description provided for @failedToUploadPicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload picture'**
  String get failedToUploadPicture;

  /// No description provided for @workTerminology.
  ///
  /// In en, this message translates to:
  /// **'Work Terminology'**
  String get workTerminology;

  /// No description provided for @howDoYouPreferToCallWork.
  ///
  /// In en, this message translates to:
  /// **'How do you prefer to call your work?'**
  String get howDoYouPreferToCallWork;

  /// No description provided for @shiftsExample.
  ///
  /// In en, this message translates to:
  /// **'Shifts (e.g., \"My Shifts\")'**
  String get shiftsExample;

  /// No description provided for @jobsExample.
  ///
  /// In en, this message translates to:
  /// **'Jobs (e.g., \"My Jobs\")'**
  String get jobsExample;

  /// No description provided for @eventsExample.
  ///
  /// In en, this message translates to:
  /// **'Events (e.g., \"My Events\")'**
  String get eventsExample;

  /// No description provided for @terminologyUpdateInfo.
  ///
  /// In en, this message translates to:
  /// **'This will update how work assignments appear throughout the app'**
  String get terminologyUpdateInfo;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @youWillReceiveNotificationsFor.
  ///
  /// In en, this message translates to:
  /// **'You\'ll receive notifications for:'**
  String get youWillReceiveNotificationsFor;

  /// No description provided for @newMessagesFromManagers.
  ///
  /// In en, this message translates to:
  /// **'New messages from managers'**
  String get newMessagesFromManagers;

  /// No description provided for @taskAssignments.
  ///
  /// In en, this message translates to:
  /// **'Task assignments'**
  String get taskAssignments;

  /// No description provided for @eventInvitations.
  ///
  /// In en, this message translates to:
  /// **'Event invitations'**
  String get eventInvitations;

  /// No description provided for @hoursApprovalUpdates.
  ///
  /// In en, this message translates to:
  /// **'Hours approval updates'**
  String get hoursApprovalUpdates;

  /// No description provided for @importantSystemAlerts.
  ///
  /// In en, this message translates to:
  /// **'Important system alerts'**
  String get importantSystemAlerts;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get sendTestNotification;

  /// No description provided for @sendingTest.
  ///
  /// In en, this message translates to:
  /// **'Sending Test...'**
  String get sendingTest;

  /// No description provided for @tapToVerifyNotifications.
  ///
  /// In en, this message translates to:
  /// **'Tap to verify push notifications are working'**
  String get tapToVerifyNotifications;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent! Check your notifications.'**
  String get testNotificationSent;

  /// No description provided for @failedToSendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Failed to send test notification'**
  String get failedToSendTestNotification;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get navEarnings;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get navShifts;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @myEarnings.
  ///
  /// In en, this message translates to:
  /// **'My Earnings'**
  String get myEarnings;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @monthlyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get monthlyBreakdown;

  /// No description provided for @allYears.
  ///
  /// In en, this message translates to:
  /// **'All Years'**
  String get allYears;

  /// No description provided for @pleaseLoginToViewEarnings.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view earnings'**
  String get pleaseLoginToViewEarnings;

  /// No description provided for @noEarningsYet.
  ///
  /// In en, this message translates to:
  /// **'No earnings data yet'**
  String get noEarningsYet;

  /// No description provided for @acceptEventToSeeEarnings.
  ///
  /// In en, this message translates to:
  /// **'Accept an event to see your earnings here'**
  String get acceptEventToSeeEarnings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @pleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get pleaseLogin;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @welcomeToNexaStaff.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tie Staff!'**
  String get welcomeToNexaStaff;

  /// No description provided for @pleaseCompleteProfileToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile to get started'**
  String get pleaseCompleteProfileToGetStarted;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First Name *'**
  String get firstNameLabel;

  /// No description provided for @enterYourFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get enterYourFirstName;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Name *'**
  String get lastNameLabel;

  /// No description provided for @enterYourLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter your last name'**
  String get enterYourLastName;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'555-123-4567'**
  String get phoneNumberHint;

  /// No description provided for @phoneNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: XXX-XXX-XXXX or 10 digits'**
  String get phoneNumberFormat;

  /// No description provided for @defaultHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Default Home Screen'**
  String get defaultHomeScreen;

  /// No description provided for @chooseWhichScreenToShow.
  ///
  /// In en, this message translates to:
  /// **'Choose which screen to show when you open the app'**
  String get chooseWhichScreenToShow;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get clockIn;

  /// No description provided for @appIdOptional.
  ///
  /// In en, this message translates to:
  /// **'App ID (Optional)'**
  String get appIdOptional;

  /// No description provided for @enterYourAppId.
  ///
  /// In en, this message translates to:
  /// **'Enter your app ID if provided'**
  String get enterYourAppId;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @requiredFields.
  ///
  /// In en, this message translates to:
  /// **'* Required fields'**
  String get requiredFields;

  /// No description provided for @profileSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile saved successfully!'**
  String get profileSavedSuccessfully;

  /// No description provided for @fieldIsRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String fieldIsRequired(String field);

  /// No description provided for @phoneNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberIsRequired;

  /// No description provided for @enterValidUSPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid US phone number'**
  String get enterValidUSPhoneNumber;

  /// No description provided for @calculatingEarnings.
  ///
  /// In en, this message translates to:
  /// **'Calculating earnings...'**
  String get calculatingEarnings;

  /// No description provided for @noEarningsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Earnings Yet'**
  String get noEarningsYetTitle;

  /// No description provided for @completeEventsToSeeEarnings.
  ///
  /// In en, this message translates to:
  /// **'Complete events to see your earnings here'**
  String get completeEventsToSeeEarnings;

  /// No description provided for @allYearsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Years'**
  String get allYearsFilter;

  /// No description provided for @totalEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarningsTitle;

  /// No description provided for @yearEarnings.
  ///
  /// In en, this message translates to:
  /// **'{year} Earnings'**
  String yearEarnings(int year);

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @avgRate.
  ///
  /// In en, this message translates to:
  /// **'Avg Rate'**
  String get avgRate;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @loadMoreMonths.
  ///
  /// In en, this message translates to:
  /// **'Load {count} More Months'**
  String loadMoreMonths(int count);

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @noEventsFoundForMonth.
  ///
  /// In en, this message translates to:
  /// **'No events found for this month'**
  String get noEventsFoundForMonth;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get venue;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @failedToLoadConversations.
  ///
  /// In en, this message translates to:
  /// **'Failed to load conversations'**
  String get failedToLoadConversations;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @yourManagerWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your manager will appear here when they message you'**
  String get yourManagerWillAppearHere;

  /// No description provided for @errorManagerIdMissing.
  ///
  /// In en, this message translates to:
  /// **'Error: Manager ID is missing'**
  String get errorManagerIdMissing;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @valerioAssistant.
  ///
  /// In en, this message translates to:
  /// **'Valerio Assistant'**
  String get valerioAssistant;

  /// No description provided for @valerioAssistantDescription.
  ///
  /// In en, this message translates to:
  /// **'Get help with shifts 👷‍♂️👨‍🍳🍽️🍹💼🏥🚗🏪🎵📦, check your schedule 📅, and more ✨'**
  String get valerioAssistantDescription;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @failedToLoadManagers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load managers'**
  String get failedToLoadManagers;

  /// No description provided for @noManagersAssigned.
  ///
  /// In en, this message translates to:
  /// **'No managers assigned'**
  String get noManagersAssigned;

  /// No description provided for @joinTeamToChat.
  ///
  /// In en, this message translates to:
  /// **'Join a team to start chatting with managers'**
  String get joinTeamToChat;

  /// No description provided for @contactMyManagers.
  ///
  /// In en, this message translates to:
  /// **'Contact My Managers'**
  String get contactMyManagers;

  /// No description provided for @untitledEvent.
  ///
  /// In en, this message translates to:
  /// **'Untitled Event'**
  String get untitledEvent;

  /// No description provided for @myEvents.
  ///
  /// In en, this message translates to:
  /// **'My Events'**
  String get myEvents;

  /// No description provided for @noAcceptedEvents.
  ///
  /// In en, this message translates to:
  /// **'No accepted events'**
  String get noAcceptedEvents;

  /// No description provided for @eventAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count} event accepted'**
  String eventAccepted(int count);

  /// No description provided for @eventsAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count} events accepted'**
  String eventsAccepted(int count);

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'event'**
  String get event;

  /// No description provided for @noPastEvents.
  ///
  /// In en, this message translates to:
  /// **'No past events'**
  String get noPastEvents;

  /// No description provided for @completedEventsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your completed events will appear here'**
  String get completedEventsWillAppearHere;

  /// No description provided for @loadMoreEvents.
  ///
  /// In en, this message translates to:
  /// **'Load {count} More Events'**
  String loadMoreEvents(int count);

  /// No description provided for @followRouteInMaps.
  ///
  /// In en, this message translates to:
  /// **'Follow route in Maps'**
  String get followRouteInMaps;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get guests;

  /// No description provided for @shiftPay.
  ///
  /// In en, this message translates to:
  /// **'Shift Pay'**
  String get shiftPay;

  /// No description provided for @tapToViewRateDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap to view rate details'**
  String get tapToViewRateDetails;

  /// No description provided for @uniformRequirements.
  ///
  /// In en, this message translates to:
  /// **'Uniform Requirements'**
  String get uniformRequirements;

  /// No description provided for @parkingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Parking Instructions'**
  String get parkingInstructions;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'DECLINE'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'ACCEPT'**
  String get accept;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'FULL'**
  String get full;

  /// No description provided for @conflict.
  ///
  /// In en, this message translates to:
  /// **'CONFLICT'**
  String get conflict;

  /// No description provided for @requestCancellation.
  ///
  /// In en, this message translates to:
  /// **'Request cancellation'**
  String get requestCancellation;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get close;

  /// No description provided for @requestCancellationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Request cancellation?'**
  String get requestCancellationQuestion;

  /// No description provided for @keepEvent.
  ///
  /// In en, this message translates to:
  /// **'KEEP EVENT'**
  String get keepEvent;

  /// No description provided for @requestCancellationCaps.
  ///
  /// In en, this message translates to:
  /// **'REQUEST CANCELLATION'**
  String get requestCancellationCaps;

  /// No description provided for @unavailabilityConflict.
  ///
  /// In en, this message translates to:
  /// **'Unavailability Conflict'**
  String get unavailabilityConflict;

  /// No description provided for @acceptAnyway.
  ///
  /// In en, this message translates to:
  /// **'ACCEPT ANYWAY'**
  String get acceptAnyway;

  /// No description provided for @teamChat.
  ///
  /// In en, this message translates to:
  /// **'Team Chat'**
  String get teamChat;

  /// No description provided for @shiftPayRole.
  ///
  /// In en, this message translates to:
  /// **'Shift Pay - {role}'**
  String shiftPayRole(String role);

  /// No description provided for @guestsCount.
  ///
  /// In en, this message translates to:
  /// **'Guests: {count}'**
  String guestsCount(String count);

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @jan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get jan;

  /// No description provided for @feb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get feb;

  /// No description provided for @mar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get mar;

  /// No description provided for @apr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get apr;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @jun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get jun;

  /// No description provided for @jul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get jul;

  /// No description provided for @aug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get aug;

  /// No description provided for @sep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get sep;

  /// No description provided for @oct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get oct;

  /// No description provided for @nov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get nov;

  /// No description provided for @dec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get dec;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @mayFull.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get mayFull;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @weekAgo.
  ///
  /// In en, this message translates to:
  /// **'1 week ago'**
  String get weekAgo;

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks ago'**
  String weeksAgo(int count);

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @estimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated Total'**
  String get estimatedTotal;

  /// No description provided for @basedOnScheduledDuration.
  ///
  /// In en, this message translates to:
  /// **'Based on scheduled shift duration'**
  String get basedOnScheduledDuration;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message: {error}'**
  String failedToSendMessage(String error);

  /// No description provided for @pleaseLoginToUseAI.
  ///
  /// In en, this message translates to:
  /// **'Please log in to use AI message composer'**
  String get pleaseLoginToUseAI;

  /// No description provided for @failedToOpenAIComposer.
  ///
  /// In en, this message translates to:
  /// **'Failed to open AI composer: {error}'**
  String failedToOpenAIComposer(String error);

  /// No description provided for @callManager.
  ///
  /// In en, this message translates to:
  /// **'Call Manager'**
  String get callManager;

  /// No description provided for @callPerson.
  ///
  /// In en, this message translates to:
  /// **'Call {name}?'**
  String callPerson(String name);

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @callingFeatureAvailableSoon.
  ///
  /// In en, this message translates to:
  /// **'Calling feature will be available soon'**
  String get callingFeatureAvailableSoon;

  /// No description provided for @failedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get failedToLoadMessages;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventNotFound;

  /// No description provided for @declineInvitationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Decline Invitation?'**
  String get declineInvitationQuestion;

  /// No description provided for @declineInvitationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to decline this event invitation? The manager will be notified.'**
  String get declineInvitationConfirm;

  /// No description provided for @declineInvitation.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineInvitation;

  /// No description provided for @failedToRespond.
  ///
  /// In en, this message translates to:
  /// **'Failed to respond: {error}'**
  String failedToRespond(String error);

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// No description provided for @noMessagesYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYetTitle;

  /// No description provided for @sendMessageToStart.
  ///
  /// In en, this message translates to:
  /// **'Send a message to start the conversation'**
  String get sendMessageToStart;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @invitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation accepted!'**
  String get invitationAccepted;

  /// No description provided for @invitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get invitationDeclined;

  /// No description provided for @aiMessageAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Message Assistant'**
  String get aiMessageAssistant;

  /// No description provided for @clockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get clockOut;

  /// No description provided for @clockingIn.
  ///
  /// In en, this message translates to:
  /// **'Clocking in...'**
  String get clockingIn;

  /// No description provided for @clockingOut.
  ///
  /// In en, this message translates to:
  /// **'Clocking out...'**
  String get clockingOut;

  /// No description provided for @clockedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'✓ Clocked in successfully!'**
  String get clockedInSuccessfully;

  /// No description provided for @clockedInOffline.
  ///
  /// In en, this message translates to:
  /// **'✓ Clocked in (offline) - Will sync when online'**
  String get clockedInOffline;

  /// No description provided for @clockedOutSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'✓ Clocked out successfully! Time worked: {time}'**
  String clockedOutSuccessfully(String time);

  /// No description provided for @timerRestored.
  ///
  /// In en, this message translates to:
  /// **'✓ Timer restored - You are already clocked in'**
  String get timerRestored;

  /// No description provided for @clockInAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in available in {time}'**
  String clockInAvailableIn(String time);

  /// No description provided for @autoClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Auto clocked in to event: {eventId}'**
  String autoClockedIn(String eventId);

  /// No description provided for @failedToQueueClockIn.
  ///
  /// In en, this message translates to:
  /// **'Failed to queue clock-in: {error}'**
  String failedToQueueClockIn(String error);

  /// No description provided for @failedToQueueClockOut.
  ///
  /// In en, this message translates to:
  /// **'Failed to queue clock-out: {error}'**
  String failedToQueueClockOut(String error);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @availabilityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Availability updated'**
  String get availabilityUpdated;

  /// No description provided for @availabilityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Availability deleted'**
  String get availabilityDeleted;

  /// No description provided for @failedToUpdateAvailability.
  ///
  /// In en, this message translates to:
  /// **'Failed to update availability'**
  String get failedToUpdateAvailability;

  /// No description provided for @failedToDeleteAvailability.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete availability'**
  String get failedToDeleteAvailability;

  /// No description provided for @deleteAvailability.
  ///
  /// In en, this message translates to:
  /// **'Delete availability'**
  String get deleteAvailability;

  /// No description provided for @teams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teams;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @defaultStartScreen.
  ///
  /// In en, this message translates to:
  /// **'Default Start Screen'**
  String get defaultStartScreen;

  /// No description provided for @defaultStartScreenUpdated.
  ///
  /// In en, this message translates to:
  /// **'Default start screen updated'**
  String get defaultStartScreenUpdated;

  /// No description provided for @chooseDefaultScreen.
  ///
  /// In en, this message translates to:
  /// **'Choose which screen to open when you launch the app:'**
  String get chooseDefaultScreen;

  /// No description provided for @shifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shifts;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// No description provided for @noUpcomingShifts.
  ///
  /// In en, this message translates to:
  /// **'No upcoming shifts'**
  String get noUpcomingShifts;

  /// No description provided for @noAvailableRoles.
  ///
  /// In en, this message translates to:
  /// **'No Available Roles'**
  String get noAvailableRoles;

  /// No description provided for @noRolesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No roles available'**
  String get noRolesAvailable;

  /// No description provided for @noAvailableTerminology.
  ///
  /// In en, this message translates to:
  /// **'No Available {terminology}'**
  String noAvailableTerminology(String terminology);

  /// No description provided for @noAcceptedTerminology.
  ///
  /// In en, this message translates to:
  /// **'No accepted {terminology}'**
  String noAcceptedTerminology(String terminology);

  /// No description provided for @noTerminologyMatchProfile.
  ///
  /// In en, this message translates to:
  /// **'No {terminology} match your profile just yet. Check back soon or refresh for updates.'**
  String noTerminologyMatchProfile(String terminology);

  /// No description provided for @acceptTerminologyFromRoles.
  ///
  /// In en, this message translates to:
  /// **'Accept {terminology} from the Roles tab to see them here'**
  String acceptTerminologyFromRoles(String terminology);

  /// No description provided for @noRolesMatchProfile.
  ///
  /// In en, this message translates to:
  /// **'No roles match your profile just yet. Check back soon or refresh for updates.'**
  String get noRolesMatchProfile;

  /// No description provided for @acceptEventsFromRoles.
  ///
  /// In en, this message translates to:
  /// **'Accept events from the Roles tab to see them here'**
  String get acceptEventsFromRoles;

  /// No description provided for @acceptEventFromShifts.
  ///
  /// In en, this message translates to:
  /// **'Accept an event from the Shifts tab to see it here'**
  String get acceptEventFromShifts;

  /// No description provided for @noEventsOrAvailability.
  ///
  /// In en, this message translates to:
  /// **'No events or availability'**
  String get noEventsOrAvailability;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh and check for new events'**
  String get pullToRefresh;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimated;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get lastWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get nextWeek;

  /// No description provided for @in2Weeks.
  ///
  /// In en, this message translates to:
  /// **'In 2 Weeks'**
  String get in2Weeks;

  /// No description provided for @in3Weeks.
  ///
  /// In en, this message translates to:
  /// **'In 3 Weeks'**
  String get in3Weeks;

  /// No description provided for @eventDateTimeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Event date/time not available'**
  String get eventDateTimeNotAvailable;

  /// No description provided for @eventTimePassed.
  ///
  /// In en, this message translates to:
  /// **'Event time has passed'**
  String get eventTimePassed;

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No Date'**
  String get noDate;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @invitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get invitation;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client: '**
  String get clientLabel;

  /// No description provided for @estimateNoTaxes.
  ///
  /// In en, this message translates to:
  /// **'Estimate does not include applicable taxes'**
  String get estimateNoTaxes;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission required'**
  String get locationPermissionRequired;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Enable in settings.'**
  String get locationPermissionDenied;

  /// No description provided for @couldNotLaunchMap.
  ///
  /// In en, this message translates to:
  /// **'Could not launch map'**
  String get couldNotLaunchMap;

  /// No description provided for @ask.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get ask;

  /// No description provided for @noTeamBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re not on a team yet'**
  String get noTeamBannerTitle;

  /// No description provided for @noTeamBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask your manager for an invite link, or go to Teams to enter an invite code.'**
  String get noTeamBannerMessage;

  /// No description provided for @goToTeams.
  ///
  /// In en, this message translates to:
  /// **'Go to Teams'**
  String get goToTeams;
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
