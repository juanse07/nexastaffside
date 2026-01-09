// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get myProfile => 'My Profile';

  @override
  String get save => 'Save';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneHint => '(555) 123-4567';

  @override
  String get phoneHelper => 'US format only';

  @override
  String get appId => 'App ID (9 digits, optional)';

  @override
  String get pictureUrl => 'Picture URL (optional)';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get failedToLoadProfile => 'Failed to load profile';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get profilePictureUploaded => 'Profile picture uploaded';

  @override
  String get failedToUploadPicture => 'Failed to upload picture';

  @override
  String get workTerminology => 'Work Terminology';

  @override
  String get howDoYouPreferToCallWork => 'How do you prefer to call your work?';

  @override
  String get shiftsExample => 'Shifts (e.g., \"My Shifts\")';

  @override
  String get jobsExample => 'Jobs (e.g., \"My Jobs\")';

  @override
  String get eventsExample => 'Events (e.g., \"My Events\")';

  @override
  String get terminologyUpdateInfo =>
      'This will update how work assignments appear throughout the app';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get youWillReceiveNotificationsFor =>
      'You\'ll receive notifications for:';

  @override
  String get newMessagesFromManagers => 'New messages from managers';

  @override
  String get taskAssignments => 'Task assignments';

  @override
  String get eventInvitations => 'Event invitations';

  @override
  String get hoursApprovalUpdates => 'Hours approval updates';

  @override
  String get importantSystemAlerts => 'Important system alerts';

  @override
  String get sendTestNotification => 'Send Test Notification';

  @override
  String get sendingTest => 'Sending Test...';

  @override
  String get tapToVerifyNotifications =>
      'Tap to verify push notifications are working';

  @override
  String get testNotificationSent =>
      'Test notification sent! Check your notifications.';

  @override
  String get failedToSendTestNotification => 'Failed to send test notification';

  @override
  String get navProfile => 'Profile';

  @override
  String get navEarnings => 'Earnings';

  @override
  String get navChats => 'Chats';

  @override
  String get navShifts => 'Shifts';

  @override
  String get navJobs => 'Jobs';

  @override
  String get navEvents => 'Events';

  @override
  String get myEarnings => 'My Earnings';

  @override
  String get totalEarnings => 'Total Earnings';

  @override
  String get monthlyBreakdown => 'Monthly Breakdown';

  @override
  String get allYears => 'All Years';

  @override
  String get pleaseLoginToViewEarnings => 'Please log in to view earnings';

  @override
  String get noEarningsYet => 'No earnings data yet';

  @override
  String get acceptEventToSeeEarnings =>
      'Accept an event to see your earnings here';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get pleaseLogin => 'Please log in';

  @override
  String get retry => 'Retry';

  @override
  String get completeYourProfile => 'Complete Your Profile';

  @override
  String get signOut => 'Sign out';

  @override
  String get welcomeToNexaStaff => 'Welcome to Tie Staff!';

  @override
  String get pleaseCompleteProfileToGetStarted =>
      'Please complete your profile to get started';

  @override
  String get firstNameLabel => 'First Name *';

  @override
  String get enterYourFirstName => 'Enter your first name';

  @override
  String get lastNameLabel => 'Last Name *';

  @override
  String get enterYourLastName => 'Enter your last name';

  @override
  String get phoneNumberLabel => 'Phone Number *';

  @override
  String get phoneNumberHint => '555-123-4567';

  @override
  String get phoneNumberFormat => 'Format: XXX-XXX-XXXX or 10 digits';

  @override
  String get defaultHomeScreen => 'Default Home Screen';

  @override
  String get chooseWhichScreenToShow =>
      'Choose which screen to show when you open the app';

  @override
  String get roles => 'Roles';

  @override
  String get chat => 'Chat';

  @override
  String get clockIn => 'Clock In';

  @override
  String get appIdOptional => 'App ID (Optional)';

  @override
  String get enterYourAppId => 'Enter your app ID if provided';

  @override
  String get continueButton => 'Continue';

  @override
  String get requiredFields => '* Required fields';

  @override
  String get profileSavedSuccessfully => 'Profile saved successfully!';

  @override
  String fieldIsRequired(String field) {
    return '$field is required';
  }

  @override
  String get phoneNumberIsRequired => 'Phone number is required';

  @override
  String get enterValidUSPhoneNumber => 'Enter a valid US phone number';

  @override
  String get calculatingEarnings => 'Calculating earnings...';

  @override
  String get noEarningsYetTitle => 'No Earnings Yet';

  @override
  String get completeEventsToSeeEarnings =>
      'Complete events to see your earnings here';

  @override
  String get allYearsFilter => 'All Years';

  @override
  String get totalEarningsTitle => 'Total Earnings';

  @override
  String yearEarnings(int year) {
    return '$year Earnings';
  }

  @override
  String get hours => 'Hours';

  @override
  String get avgRate => 'Avg Rate';

  @override
  String get monthly => 'Monthly';

  @override
  String loadMoreMonths(int count) {
    return 'Load $count More Months';
  }

  @override
  String get events => 'Events';

  @override
  String get noEventsFoundForMonth => 'No events found for this month';

  @override
  String get client => 'Client';

  @override
  String get venue => 'Venue';

  @override
  String get role => 'Role';

  @override
  String get rate => 'Rate';

  @override
  String get chats => 'Chats';

  @override
  String get failedToLoadConversations => 'Failed to load conversations';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get yourManagerWillAppearHere =>
      'Your manager will appear here when they message you';

  @override
  String get errorManagerIdMissing => 'Error: Manager ID is missing';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get valerioAssistant => 'Valerio Assistant';

  @override
  String get valerioAssistantDescription =>
      'Get help with shifts 👷‍♂️👨‍🍳🍽️🍹💼🏥🚗🏪🎵📦, check your schedule 📅, and more ✨';

  @override
  String get newChat => 'New Chat';

  @override
  String get failedToLoadManagers => 'Failed to load managers';

  @override
  String get noManagersAssigned => 'No managers assigned';

  @override
  String get joinTeamToChat => 'Join a team to start chatting with managers';

  @override
  String get contactMyManagers => 'Contact My Managers';

  @override
  String get untitledEvent => 'Untitled Event';

  @override
  String get myEvents => 'My Events';

  @override
  String get noAcceptedEvents => 'No accepted events';

  @override
  String eventAccepted(int count) {
    return '$count event accepted';
  }

  @override
  String eventsAccepted(int count) {
    return '$count events accepted';
  }

  @override
  String get event => 'event';

  @override
  String get noPastEvents => 'No past events';

  @override
  String get completedEventsWillAppearHere =>
      'Your completed events will appear here';

  @override
  String loadMoreEvents(int count) {
    return 'Load $count More Events';
  }

  @override
  String get followRouteInMaps => 'Follow route in Maps';

  @override
  String get guests => 'Guests';

  @override
  String get shiftPay => 'Shift Pay';

  @override
  String get tapToViewRateDetails => 'Tap to view rate details';

  @override
  String get uniformRequirements => 'Uniform Requirements';

  @override
  String get parkingInstructions => 'Parking Instructions';

  @override
  String get decline => 'DECLINE';

  @override
  String get accept => 'ACCEPT';

  @override
  String get full => 'FULL';

  @override
  String get conflict => 'CONFLICT';

  @override
  String get requestCancellation => 'Request cancellation';

  @override
  String get close => 'CLOSE';

  @override
  String get requestCancellationQuestion => 'Request cancellation?';

  @override
  String get keepEvent => 'KEEP EVENT';

  @override
  String get requestCancellationCaps => 'REQUEST CANCELLATION';

  @override
  String get unavailabilityConflict => 'Unavailability Conflict';

  @override
  String get acceptAnyway => 'ACCEPT ANYWAY';

  @override
  String get teamChat => 'Team Chat';

  @override
  String shiftPayRole(String role) {
    return 'Shift Pay - $role';
  }

  @override
  String guestsCount(String count) {
    return 'Guests: $count';
  }

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get jan => 'Jan';

  @override
  String get feb => 'Feb';

  @override
  String get mar => 'Mar';

  @override
  String get apr => 'Apr';

  @override
  String get may => 'May';

  @override
  String get jun => 'Jun';

  @override
  String get jul => 'Jul';

  @override
  String get aug => 'Aug';

  @override
  String get sep => 'Sep';

  @override
  String get oct => 'Oct';

  @override
  String get nov => 'Nov';

  @override
  String get dec => 'Dec';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get mayFull => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get weekAgo => '1 week ago';

  @override
  String weeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String get thisMonth => 'This Month';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get estimatedTotal => 'Estimated Total';

  @override
  String get basedOnScheduledDuration => 'Based on scheduled shift duration';

  @override
  String failedToSendMessage(String error) {
    return 'Failed to send message: $error';
  }

  @override
  String get pleaseLoginToUseAI => 'Please log in to use AI message composer';

  @override
  String failedToOpenAIComposer(String error) {
    return 'Failed to open AI composer: $error';
  }

  @override
  String get callManager => 'Call Manager';

  @override
  String callPerson(String name) {
    return 'Call $name?';
  }

  @override
  String get call => 'Call';

  @override
  String get callingFeatureAvailableSoon =>
      'Calling feature will be available soon';

  @override
  String get failedToLoadMessages => 'Failed to load messages';

  @override
  String get eventNotFound => 'Event not found';

  @override
  String get declineInvitationQuestion => 'Decline Invitation?';

  @override
  String get declineInvitationConfirm =>
      'Are you sure you want to decline this event invitation? The manager will be notified.';

  @override
  String get declineInvitation => 'Decline';

  @override
  String failedToRespond(String error) {
    return 'Failed to respond: $error';
  }

  @override
  String get typeAMessage => 'Type a message...';

  @override
  String get noMessagesYetTitle => 'No messages yet';

  @override
  String get sendMessageToStart => 'Send a message to start the conversation';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get invitationAccepted => 'Invitation accepted!';

  @override
  String get invitationDeclined => 'Invitation declined';

  @override
  String get aiMessageAssistant => 'AI Message Assistant';

  @override
  String get clockOut => 'Clock Out';

  @override
  String get clockingIn => 'Clocking in...';

  @override
  String get clockingOut => 'Clocking out...';

  @override
  String get clockedInSuccessfully => '✓ Clocked in successfully!';

  @override
  String get clockedInOffline =>
      '✓ Clocked in (offline) - Will sync when online';

  @override
  String clockedOutSuccessfully(String time) {
    return '✓ Clocked out successfully! Time worked: $time';
  }

  @override
  String get timerRestored => '✓ Timer restored - You are already clocked in';

  @override
  String clockInAvailableIn(String time) {
    return 'Clock in available in $time';
  }

  @override
  String autoClockedIn(String eventId) {
    return 'Auto clocked in to event: $eventId';
  }

  @override
  String failedToQueueClockIn(String error) {
    return 'Failed to queue clock-in: $error';
  }

  @override
  String failedToQueueClockOut(String error) {
    return 'Failed to queue clock-out: $error';
  }

  @override
  String get available => 'Available';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get availabilityUpdated => 'Availability updated';

  @override
  String get availabilityDeleted => 'Availability deleted';

  @override
  String get failedToUpdateAvailability => 'Failed to update availability';

  @override
  String get failedToDeleteAvailability => 'Failed to delete availability';

  @override
  String get deleteAvailability => 'Delete availability';

  @override
  String get teams => 'Teams';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get account => 'Account';

  @override
  String get defaultStartScreen => 'Default Start Screen';

  @override
  String get defaultStartScreenUpdated => 'Default start screen updated';

  @override
  String get chooseDefaultScreen =>
      'Choose which screen to open when you launch the app:';

  @override
  String get shifts => 'Shifts';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get noUpcomingShifts => 'No upcoming shifts';

  @override
  String get noAvailableRoles => 'No Available Roles';

  @override
  String get noRolesAvailable => 'No roles available';

  @override
  String noAvailableTerminology(String terminology) {
    return 'No Available $terminology';
  }

  @override
  String noAcceptedTerminology(String terminology) {
    return 'No accepted $terminology';
  }

  @override
  String noTerminologyMatchProfile(String terminology) {
    return 'No $terminology match your profile just yet. Check back soon or refresh for updates.';
  }

  @override
  String acceptTerminologyFromRoles(String terminology) {
    return 'Accept $terminology from the Roles tab to see them here';
  }

  @override
  String get noRolesMatchProfile =>
      'No roles match your profile just yet. Check back soon or refresh for updates.';

  @override
  String get acceptEventsFromRoles =>
      'Accept events from the Roles tab to see them here';

  @override
  String get acceptEventFromShifts =>
      'Accept an event from the Shifts tab to see it here';

  @override
  String get noEventsOrAvailability => 'No events or availability';

  @override
  String get pullToRefresh => 'Pull to refresh and check for new events';

  @override
  String get calendar => 'Calendar';

  @override
  String get duration => 'Duration';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get estimated => 'Estimated';

  @override
  String get thisWeek => 'This Week';

  @override
  String get lastWeek => 'Last Week';

  @override
  String get nextWeek => 'Next Week';

  @override
  String get in2Weeks => 'In 2 Weeks';

  @override
  String get in3Weeks => 'In 3 Weeks';

  @override
  String get eventDateTimeNotAvailable => 'Event date/time not available';

  @override
  String get eventTimePassed => 'Event time has passed';

  @override
  String get noDate => 'No Date';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get invitation => 'Invitation';

  @override
  String get private => 'Private';

  @override
  String get clientLabel => 'Client: ';

  @override
  String get estimateNoTaxes => 'Estimate does not include applicable taxes';

  @override
  String get locationPermissionRequired => 'Location permission required';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Enable in settings.';

  @override
  String get couldNotLaunchMap => 'Could not launch map';

  @override
  String get ask => 'Ask';
}
