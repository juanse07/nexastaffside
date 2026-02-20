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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

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
  /// **'Welcome to FlowShift Staff!'**
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

  /// No description provided for @letsGetYouSetUp.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get you set up'**
  String get letsGetYouSetUp;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get yourProfile;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish Setup'**
  String get finishSetup;

  /// No description provided for @youreAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get youreAllSet;

  /// No description provided for @yourProfileIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your profile is ready. You can now start accepting events.'**
  String get yourProfileIsReady;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go'**
  String get letsGo;

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

  /// No description provided for @loadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get loadingMap;

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

  /// No description provided for @flowShiftStaff.
  ///
  /// In en, this message translates to:
  /// **'FlowShift Staff'**
  String get flowShiftStaff;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get continueWithPhone;

  /// No description provided for @orSignInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or sign in with email'**
  String get orSignInWithEmail;

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

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @pleaseEnterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter email and password'**
  String get pleaseEnterEmailAndPassword;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get googleSignInFailed;

  /// No description provided for @appleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed'**
  String get appleSignInFailed;

  /// No description provided for @emailSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in failed'**
  String get emailSignInFailed;

  /// No description provided for @bySigningInYouAgree.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to our'**
  String get bySigningInYouAgree;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @andWord.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andWord;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Phone Sign In'**
  String get phoneSignIn;

  /// No description provided for @wellSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification code'**
  String get wellSendVerificationCode;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @enterValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhoneNumber;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get sendVerificationCode;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCode;

  /// No description provided for @enter6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enter6DigitCode;

  /// No description provided for @pleaseEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get pleaseEnterVerificationCode;

  /// No description provided for @didntReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get didntReceiveCode;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to {phone}'**
  String verificationCodeSentTo(String phone);

  /// No description provided for @phoneVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone verification failed: {error}'**
  String phoneVerificationFailed(String error);

  /// No description provided for @teamCenter.
  ///
  /// In en, this message translates to:
  /// **'Team Center'**
  String get teamCenter;

  /// No description provided for @invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get invitations;

  /// No description provided for @noPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'No pending invites'**
  String get noPendingInvites;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code'**
  String get enterInviteCode;

  /// No description provided for @failedToAcceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept invite: {error}'**
  String failedToAcceptInvite(String error);

  /// No description provided for @failedToDeclineInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline invite: {error}'**
  String failedToDeclineInvite(String error);

  /// No description provided for @myTeams.
  ///
  /// In en, this message translates to:
  /// **'My Teams'**
  String get myTeams;

  /// No description provided for @youHaveNotJoinedAnyTeams.
  ///
  /// In en, this message translates to:
  /// **'You have not joined any teams yet.'**
  String get youHaveNotJoinedAnyTeams;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @joinATeam.
  ///
  /// In en, this message translates to:
  /// **'Join a Team'**
  String get joinATeam;

  /// No description provided for @enterInviteCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code your manager gave you'**
  String get enterInviteCodePrompt;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @validateCode.
  ///
  /// In en, this message translates to:
  /// **'Validate Code'**
  String get validateCode;

  /// No description provided for @validInvite.
  ///
  /// In en, this message translates to:
  /// **'Valid Invite!'**
  String get validInvite;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @successfullyJoinedTeam.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined team!'**
  String get successfullyJoinedTeam;

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining...'**
  String get joining;

  /// No description provided for @joinTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Team'**
  String get joinTeam;

  /// No description provided for @failedToValidateCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to validate code: {error}'**
  String failedToValidateCode(String error);

  /// No description provided for @failedToJoinTeam.
  ///
  /// In en, this message translates to:
  /// **'Failed to join team: {error}'**
  String failedToJoinTeam(String error);

  /// No description provided for @pleaseEnterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter an invite code'**
  String get pleaseEnterInviteCode;

  /// No description provided for @teamChatEnabledBefore.
  ///
  /// In en, this message translates to:
  /// **'Team chat will be enabled 1 hour before the event'**
  String get teamChatEnabledBefore;

  /// No description provided for @chatOpensSoon.
  ///
  /// In en, this message translates to:
  /// **'Chat Opens Soon'**
  String get chatOpensSoon;

  /// No description provided for @teamChatWillOpen.
  ///
  /// In en, this message translates to:
  /// **'Team chat will automatically open 1 hour before the event starts'**
  String get teamChatWillOpen;

  /// No description provided for @comeBackCloserToShift.
  ///
  /// In en, this message translates to:
  /// **'Come back closer to your shift time to chat with your team'**
  String get comeBackCloserToShift;

  /// No description provided for @startTheConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation!'**
  String get startTheConversation;

  /// No description provided for @managerBadge.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get managerBadge;

  /// No description provided for @composeProfessionalMessages.
  ///
  /// In en, this message translates to:
  /// **'Compose professional messages with AI assistance'**
  String get composeProfessionalMessages;

  /// No description provided for @composingYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Composing your message...'**
  String get composingYourMessage;

  /// No description provided for @messageInserted.
  ///
  /// In en, this message translates to:
  /// **'Message inserted!'**
  String get messageInserted;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @failedToComposeMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to compose message: {error}'**
  String failedToComposeMessage(String error);

  /// No description provided for @whatWouldYouLikeToSay.
  ///
  /// In en, this message translates to:
  /// **'What would you like to say?'**
  String get whatWouldYouLikeToSay;

  /// No description provided for @describeYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Describe what you\'d like to say...'**
  String get describeYourMessage;

  /// No description provided for @tone.
  ///
  /// In en, this message translates to:
  /// **'Tone'**
  String get tone;

  /// No description provided for @professionalFriendly.
  ///
  /// In en, this message translates to:
  /// **'Professional & Friendly'**
  String get professionalFriendly;

  /// No description provided for @casualFriendly.
  ///
  /// In en, this message translates to:
  /// **'Casual & Friendly'**
  String get casualFriendly;

  /// No description provided for @useMessage.
  ///
  /// In en, this message translates to:
  /// **'Use Message'**
  String get useMessage;

  /// No description provided for @useBoth.
  ///
  /// In en, this message translates to:
  /// **'Use Both'**
  String get useBoth;

  /// No description provided for @tryDifferentScenario.
  ///
  /// In en, this message translates to:
  /// **'Try Different Scenario'**
  String get tryDifferentScenario;

  /// No description provided for @insertIntoChat.
  ///
  /// In en, this message translates to:
  /// **'Insert Into Chat'**
  String get insertIntoChat;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @generatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Generated Message'**
  String get generatedMessage;

  /// No description provided for @originalMessage.
  ///
  /// In en, this message translates to:
  /// **'Original Message'**
  String get originalMessage;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @clearConversation.
  ///
  /// In en, this message translates to:
  /// **'Clear Conversation?'**
  String get clearConversation;

  /// No description provided for @clearConversationConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete all messages in this conversation.'**
  String get clearConversationConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @failedToGetAIResponse.
  ///
  /// In en, this message translates to:
  /// **'Failed to get AI response: {error}'**
  String failedToGetAIResponse(String error);

  /// No description provided for @askAboutSchedule.
  ///
  /// In en, this message translates to:
  /// **'Ask about your schedule, earnings, or shifts...'**
  String get askAboutSchedule;

  /// No description provided for @aiIsThinking.
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get aiIsThinking;

  /// No description provided for @recordingTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Recording... Tap mic to stop'**
  String get recordingTapToStop;

  /// No description provided for @transcribingVoice.
  ///
  /// In en, this message translates to:
  /// **'Transcribing voice...'**
  String get transcribingVoice;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required. Please enable it in Settings.'**
  String get microphonePermissionRequired;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @flowShiftPro.
  ///
  /// In en, this message translates to:
  /// **'FlowShift Pro'**
  String get flowShiftPro;

  /// No description provided for @unlimitedAiChat.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI Chat Messages'**
  String get unlimitedAiChat;

  /// No description provided for @prioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Support'**
  String get prioritySupport;

  /// No description provided for @advancedAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced Analytics'**
  String get advancedAnalytics;

  /// No description provided for @customNotifications.
  ///
  /// In en, this message translates to:
  /// **'Custom Notifications'**
  String get customNotifications;

  /// No description provided for @earlyAccessFeatures.
  ///
  /// In en, this message translates to:
  /// **'Early Access to New Features'**
  String get earlyAccessFeatures;

  /// No description provided for @monthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}/month'**
  String monthlyPrice(String price);

  /// No description provided for @yearlyPrice.
  ///
  /// In en, this message translates to:
  /// **'{price}/year'**
  String yearlyPrice(String price);

  /// No description provided for @subscribeNow.
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get subscribeNow;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get bestValue;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @freeTrialDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-day free trial'**
  String freeTrialDays(int days);

  /// No description provided for @cancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get cancelAnytime;

  /// No description provided for @subscriptionDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.'**
  String get subscriptionDisclaimer;

  /// No description provided for @purchaseSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful! Enjoy Pro features.'**
  String get purchaseSuccessful;

  /// No description provided for @failedToPurchase.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete purchase'**
  String get failedToPurchase;

  /// No description provided for @failedToRestore.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore purchase'**
  String get failedToRestore;

  /// No description provided for @noPreviousPurchase.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found'**
  String get noPreviousPurchase;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @glowUp.
  ///
  /// In en, this message translates to:
  /// **'Glow Up'**
  String get glowUp;

  /// No description provided for @originalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Original Photo'**
  String get originalPhoto;

  /// No description provided for @myCreations.
  ///
  /// In en, this message translates to:
  /// **'My Creations'**
  String get myCreations;

  /// No description provided for @activeBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeBadge;

  /// No description provided for @deleteCreation.
  ///
  /// In en, this message translates to:
  /// **'Delete creation?'**
  String get deleteCreation;

  /// No description provided for @deleteCreationConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove this creation.'**
  String get deleteCreationConfirm;

  /// No description provided for @newLookSaved.
  ///
  /// In en, this message translates to:
  /// **'New look saved!'**
  String get newLookSaved;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @failedToSaveCreation.
  ///
  /// In en, this message translates to:
  /// **'Failed to save creation'**
  String get failedToSaveCreation;

  /// No description provided for @failedToDeleteCreation.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete creation'**
  String get failedToDeleteCreation;

  /// No description provided for @failedToUpdateProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture'**
  String get failedToUpdateProfilePicture;

  /// No description provided for @noCreationsYet.
  ///
  /// In en, this message translates to:
  /// **'No creations yet'**
  String get noCreationsYet;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String shareFailed(String error);

  /// No description provided for @exportError.
  ///
  /// In en, this message translates to:
  /// **'Export error: {error}'**
  String exportError(String error);

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exportShifts.
  ///
  /// In en, this message translates to:
  /// **'Export Shifts'**
  String get exportShifts;

  /// No description provided for @downloadShiftHistory.
  ///
  /// In en, this message translates to:
  /// **'Download your shift history'**
  String get downloadShiftHistory;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @csvFormat.
  ///
  /// In en, this message translates to:
  /// **'CSV (Spreadsheet)'**
  String get csvFormat;

  /// No description provided for @pdfFormat.
  ///
  /// In en, this message translates to:
  /// **'PDF (Document)'**
  String get pdfFormat;

  /// No description provided for @timePeriod.
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get timePeriod;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @exportInfo.
  ///
  /// In en, this message translates to:
  /// **'Export includes event name, date, hours worked, and pay rate.'**
  String get exportInfo;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @updatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully'**
  String get updatedSuccessfully;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String refreshFailed(String error);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshData.
  ///
  /// In en, this message translates to:
  /// **'Refresh data'**
  String get refreshData;

  /// No description provided for @dataMayBeOutdated.
  ///
  /// In en, this message translates to:
  /// **'Data may be outdated'**
  String get dataMayBeOutdated;

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'New Record!'**
  String get newRecord;

  /// No description provided for @clockedInCelebration.
  ///
  /// In en, this message translates to:
  /// **'Clocked In!'**
  String get clockedInCelebration;

  /// No description provided for @plusPoints.
  ///
  /// In en, this message translates to:
  /// **'+{points} points'**
  String plusPoints(int points);

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'{days} day streak!'**
  String dayStreak(int days);

  /// No description provided for @tapToDismiss.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to dismiss'**
  String get tapToDismiss;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided for @ptsLabel.
  ///
  /// In en, this message translates to:
  /// **'{pts} pts'**
  String ptsLabel(int pts);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @best.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get best;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get nextLevel;

  /// No description provided for @ptsToGo.
  ///
  /// In en, this message translates to:
  /// **'{pts} pts to go'**
  String ptsToGo(int pts);

  /// No description provided for @keepItUp.
  ///
  /// In en, this message translates to:
  /// **'Keep it up!'**
  String get keepItUp;

  /// No description provided for @onFire.
  ///
  /// In en, this message translates to:
  /// **'On fire!'**
  String get onFire;

  /// No description provided for @unstoppable.
  ///
  /// In en, this message translates to:
  /// **'Unstoppable!'**
  String get unstoppable;

  /// No description provided for @justGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Just getting started'**
  String get justGettingStarted;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @profileGlowUp.
  ///
  /// In en, this message translates to:
  /// **'Profile Glow Up'**
  String get profileGlowUp;

  /// No description provided for @yourRoleYourStyle.
  ///
  /// In en, this message translates to:
  /// **'Your role. Your style. Your look.'**
  String get yourRoleYourStyle;

  /// No description provided for @whoAreYouToday.
  ///
  /// In en, this message translates to:
  /// **'Who are you today?'**
  String get whoAreYouToday;

  /// No description provided for @pickYourVibe.
  ///
  /// In en, this message translates to:
  /// **'Pick your vibe'**
  String get pickYourVibe;

  /// No description provided for @qualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get qualityLabel;

  /// No description provided for @standardQuality.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardQuality;

  /// No description provided for @hdQuality.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get hdQuality;

  /// No description provided for @textInImage.
  ///
  /// In en, this message translates to:
  /// **'Text in image'**
  String get textInImage;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @readyForNewLook.
  ///
  /// In en, this message translates to:
  /// **'Ready for a new look?'**
  String get readyForNewLook;

  /// No description provided for @getMyNewLook.
  ///
  /// In en, this message translates to:
  /// **'Get My New Look'**
  String get getMyNewLook;

  /// No description provided for @lookingGood.
  ///
  /// In en, this message translates to:
  /// **'Looking good!'**
  String get lookingGood;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get before;

  /// No description provided for @after.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get after;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated images may not be accurate representations.'**
  String get aiDisclaimer;

  /// No description provided for @useThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use This Photo'**
  String get useThisPhoto;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @generateNew.
  ///
  /// In en, this message translates to:
  /// **'Generate New'**
  String get generateNew;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See {count} more'**
  String seeMore(int count);

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get showLess;

  /// No description provided for @freeMonthBanner.
  ///
  /// In en, this message translates to:
  /// **'Free month: {days} days remaining'**
  String freeMonthBanner(int days);

  /// No description provided for @freeMonthExpired.
  ///
  /// In en, this message translates to:
  /// **'Your free month has ended — Subscribe to unlock all features'**
  String get freeMonthExpired;

  /// No description provided for @subscriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Subscription Required'**
  String get subscriptionRequired;

  /// No description provided for @featureLocked.
  ///
  /// In en, this message translates to:
  /// **'requires FlowShift Pro'**
  String get featureLocked;

  /// No description provided for @subscribeToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Unlock'**
  String get subscribeToUnlock;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @readOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Read-only mode'**
  String get readOnlyMode;

  /// No description provided for @acceptShifts.
  ///
  /// In en, this message translates to:
  /// **'Accept shifts'**
  String get acceptShifts;

  /// No description provided for @declineShifts.
  ///
  /// In en, this message translates to:
  /// **'Decline shifts'**
  String get declineShifts;

  /// No description provided for @chatWithManagers.
  ///
  /// In en, this message translates to:
  /// **'Chat with managers'**
  String get chatWithManagers;

  /// No description provided for @generateCaricature.
  ///
  /// In en, this message translates to:
  /// **'Generate caricature'**
  String get generateCaricature;

  /// No description provided for @freeMonthExplore.
  ///
  /// In en, this message translates to:
  /// **'You have a free month to explore everything!'**
  String get freeMonthExplore;

  /// No description provided for @proFeatureAcceptDecline.
  ///
  /// In en, this message translates to:
  /// **'Accept & decline shifts'**
  String get proFeatureAcceptDecline;

  /// No description provided for @proFeatureChat.
  ///
  /// In en, this message translates to:
  /// **'Chat with managers and team'**
  String get proFeatureChat;

  /// No description provided for @proFeatureAI.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant (20 messages/month)'**
  String get proFeatureAI;

  /// No description provided for @proFeatureClockInOut.
  ///
  /// In en, this message translates to:
  /// **'Clock in/out'**
  String get proFeatureClockInOut;

  /// No description provided for @proFeatureAvailability.
  ///
  /// In en, this message translates to:
  /// **'Set availability'**
  String get proFeatureAvailability;

  /// No description provided for @proFeatureCaricatures.
  ///
  /// In en, this message translates to:
  /// **'Generate profile caricatures'**
  String get proFeatureCaricatures;

  /// No description provided for @proPrice.
  ///
  /// In en, this message translates to:
  /// **'\$7.99/month'**
  String get proPrice;
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
