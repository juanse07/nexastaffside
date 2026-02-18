// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get myProfile => 'Mi Perfil';

  @override
  String get save => 'Guardar';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get phoneNumber => 'Número de teléfono';

  @override
  String get phoneHint => '(555) 123-4567';

  @override
  String get phoneHelper => 'Solo formato de EE.UU.';

  @override
  String get appId => 'ID de la App (9 dígitos, opcional)';

  @override
  String get pictureUrl => 'URL de la imagen (opcional)';

  @override
  String get profileUpdated => 'Perfil actualizado';

  @override
  String get failedToLoadProfile => 'Error al cargar el perfil';

  @override
  String get chooseFromGallery => 'Elegir de la galería';

  @override
  String get takePhoto => 'Tomar una foto';

  @override
  String get removePhoto => 'Eliminar foto';

  @override
  String get profilePictureUploaded => 'Foto de perfil subida';

  @override
  String get failedToUploadPicture => 'Error al subir la imagen';

  @override
  String get workTerminology => 'Terminología de Trabajo';

  @override
  String get howDoYouPreferToCallWork => '¿Cómo prefieres llamar a tu trabajo?';

  @override
  String get shiftsExample => 'Turnos (ej., \"Mis Turnos\")';

  @override
  String get jobsExample => 'Trabajos (ej., \"Mis Trabajos\")';

  @override
  String get eventsExample => 'Eventos (ej., \"Mis Eventos\")';

  @override
  String get terminologyUpdateInfo =>
      'Esto actualizará cómo aparecen las asignaciones de trabajo en toda la aplicación';

  @override
  String get pushNotifications => 'Notificaciones Push';

  @override
  String get youWillReceiveNotificationsFor => 'Recibirás notificaciones para:';

  @override
  String get newMessagesFromManagers => 'Nuevos mensajes de gerentes';

  @override
  String get taskAssignments => 'Asignaciones de tareas';

  @override
  String get eventInvitations => 'Invitaciones a eventos';

  @override
  String get hoursApprovalUpdates => 'Actualizaciones de aprobación de horas';

  @override
  String get importantSystemAlerts => 'Alertas importantes del sistema';

  @override
  String get sendTestNotification => 'Enviar Notificación de Prueba';

  @override
  String get sendingTest => 'Enviando Prueba...';

  @override
  String get tapToVerifyNotifications =>
      'Toca para verificar que las notificaciones push funcionan';

  @override
  String get testNotificationSent =>
      '¡Notificación de prueba enviada! Revisa tus notificaciones.';

  @override
  String get failedToSendTestNotification =>
      'Error al enviar notificación de prueba';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navEarnings => 'Ganancias';

  @override
  String get navChats => 'Chats';

  @override
  String get navShifts => 'Turnos';

  @override
  String get navJobs => 'Trabajos';

  @override
  String get navEvents => 'Eventos';

  @override
  String get myEarnings => 'Mis Ganancias';

  @override
  String get totalEarnings => 'Ganancias Totales';

  @override
  String get monthlyBreakdown => 'Desglose Mensual';

  @override
  String get allYears => 'Todos los Años';

  @override
  String get pleaseLoginToViewEarnings =>
      'Por favor inicia sesión para ver las ganancias';

  @override
  String get noEarningsYet => 'Aún no hay datos de ganancias';

  @override
  String get acceptEventToSeeEarnings =>
      'Acepta un evento para ver tus ganancias aquí';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Listo';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get tryAgain => 'Intentar de Nuevo';

  @override
  String get pleaseLogin => 'Por favor inicia sesión';

  @override
  String get retry => 'Reintentar';

  @override
  String get completeYourProfile => 'Completa Tu Perfil';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get welcomeToNexaStaff => '¡Bienvenido a Tie Staff!';

  @override
  String get pleaseCompleteProfileToGetStarted =>
      'Por favor completa tu perfil para comenzar';

  @override
  String get firstNameLabel => 'Nombre *';

  @override
  String get enterYourFirstName => 'Ingresa tu nombre';

  @override
  String get lastNameLabel => 'Apellido *';

  @override
  String get enterYourLastName => 'Ingresa tu apellido';

  @override
  String get phoneNumberLabel => 'Número de Teléfono *';

  @override
  String get phoneNumberHint => '555-123-4567';

  @override
  String get phoneNumberFormat => 'Formato: XXX-XXX-XXXX o 10 dígitos';

  @override
  String get defaultHomeScreen => 'Pantalla de Inicio Predeterminada';

  @override
  String get chooseWhichScreenToShow =>
      'Elige qué pantalla mostrar al abrir la aplicación';

  @override
  String get roles => 'Roles';

  @override
  String get chat => 'Chat';

  @override
  String get clockIn => 'Registrar Entrada';

  @override
  String get appIdOptional => 'ID de la App (Opcional)';

  @override
  String get enterYourAppId => 'Ingresa tu ID de la app si lo tienes';

  @override
  String get continueButton => 'Continuar';

  @override
  String get requiredFields => '* Campos requeridos';

  @override
  String get profileSavedSuccessfully => '¡Perfil guardado exitosamente!';

  @override
  String fieldIsRequired(String field) {
    return '$field es requerido';
  }

  @override
  String get phoneNumberIsRequired => 'El número de teléfono es requerido';

  @override
  String get enterValidUSPhoneNumber =>
      'Ingresa un número de teléfono válido de EE.UU.';

  @override
  String get calculatingEarnings => 'Calculando ganancias...';

  @override
  String get noEarningsYetTitle => 'Aún No Hay Ganancias';

  @override
  String get completeEventsToSeeEarnings =>
      'Completa eventos para ver tus ganancias aquí';

  @override
  String get allYearsFilter => 'Todos los Años';

  @override
  String get totalEarningsTitle => 'Ganancias Totales';

  @override
  String yearEarnings(int year) {
    return 'Ganancias $year';
  }

  @override
  String get hours => 'Horas';

  @override
  String get avgRate => 'Tarifa Prom';

  @override
  String get monthly => 'Mensual';

  @override
  String loadMoreMonths(int count) {
    return 'Cargar $count Meses Más';
  }

  @override
  String get events => 'Eventos';

  @override
  String get noEventsFoundForMonth => 'No se encontraron eventos para este mes';

  @override
  String get client => 'Cliente';

  @override
  String get venue => 'Lugar';

  @override
  String get role => 'Rol';

  @override
  String get rate => 'Tarifa';

  @override
  String get chats => 'Chats';

  @override
  String get search => 'Buscar';

  @override
  String get noResults => 'No se encontraron resultados';

  @override
  String get failedToLoadConversations => 'Error al cargar conversaciones';

  @override
  String get noConversationsYet => 'Aún no hay conversaciones';

  @override
  String get yourManagerWillAppearHere =>
      'Tu gerente aparecerá aquí cuando te envíe un mensaje';

  @override
  String get errorManagerIdMissing => 'Error: Falta el ID del gerente';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get valerioAssistant => 'Asistente Valerio';

  @override
  String get valerioAssistantDescription =>
      'Obtén ayuda con turnos 👷‍♂️👨‍🍳🍽️🍹💼🏥🚗🏪🎵📦, revisa tu horario 📅, y más ✨';

  @override
  String get newChat => 'Nuevo Chat';

  @override
  String get failedToLoadManagers => 'Error al cargar gerentes';

  @override
  String get noManagersAssigned => 'No hay gerentes asignados';

  @override
  String get joinTeamToChat => 'Únete a un equipo para chatear con gerentes';

  @override
  String get contactMyManagers => 'Contactar a Mis Gerentes';

  @override
  String get untitledEvent => 'Evento sin título';

  @override
  String get myEvents => 'Mis Eventos';

  @override
  String get noAcceptedEvents => 'No hay eventos aceptados';

  @override
  String eventAccepted(int count) {
    return '$count evento aceptado';
  }

  @override
  String eventsAccepted(int count) {
    return '$count eventos aceptados';
  }

  @override
  String get event => 'evento';

  @override
  String get noPastEvents => 'No hay eventos pasados';

  @override
  String get completedEventsWillAppearHere =>
      'Tus eventos completados aparecerán aquí';

  @override
  String loadMoreEvents(int count) {
    return 'Cargar $count Eventos Más';
  }

  @override
  String get followRouteInMaps => 'Seguir ruta en Mapas';

  @override
  String get guests => 'Invitados';

  @override
  String get shiftPay => 'Pago del Turno';

  @override
  String get tapToViewRateDetails => 'Toca para ver detalles de tarifa';

  @override
  String get uniformRequirements => 'Requisitos de Uniforme';

  @override
  String get parkingInstructions => 'Instrucciones de Estacionamiento';

  @override
  String get decline => 'RECHAZAR';

  @override
  String get accept => 'ACEPTAR';

  @override
  String get full => 'COMPLETO';

  @override
  String get conflict => 'CONFLICTO';

  @override
  String get requestCancellation => 'Solicitar cancelación';

  @override
  String get close => 'CERRAR';

  @override
  String get requestCancellationQuestion => '¿Solicitar cancelación?';

  @override
  String get keepEvent => 'MANTENER EVENTO';

  @override
  String get requestCancellationCaps => 'SOLICITAR CANCELACIÓN';

  @override
  String get unavailabilityConflict => 'Conflicto de Disponibilidad';

  @override
  String get acceptAnyway => 'ACEPTAR DE TODOS MODOS';

  @override
  String get teamChat => 'Chat del Equipo';

  @override
  String shiftPayRole(String role) {
    return 'Pago del Turno - $role';
  }

  @override
  String guestsCount(String count) {
    return 'Invitados: $count';
  }

  @override
  String get mon => 'Lun';

  @override
  String get tue => 'Mar';

  @override
  String get wed => 'Mié';

  @override
  String get thu => 'Jue';

  @override
  String get fri => 'Vie';

  @override
  String get sat => 'Sáb';

  @override
  String get sun => 'Dom';

  @override
  String get jan => 'Ene';

  @override
  String get feb => 'Feb';

  @override
  String get mar => 'Mar';

  @override
  String get apr => 'Abr';

  @override
  String get may => 'May';

  @override
  String get jun => 'Jun';

  @override
  String get jul => 'Jul';

  @override
  String get aug => 'Ago';

  @override
  String get sep => 'Sep';

  @override
  String get oct => 'Oct';

  @override
  String get nov => 'Nov';

  @override
  String get dec => 'Dic';

  @override
  String get january => 'Enero';

  @override
  String get february => 'Febrero';

  @override
  String get march => 'Marzo';

  @override
  String get april => 'Abril';

  @override
  String get mayFull => 'Mayo';

  @override
  String get june => 'Junio';

  @override
  String get july => 'Julio';

  @override
  String get august => 'Agosto';

  @override
  String get september => 'Septiembre';

  @override
  String get october => 'Octubre';

  @override
  String get november => 'Noviembre';

  @override
  String get december => 'Diciembre';

  @override
  String daysAgo(int count) {
    return 'hace $count días';
  }

  @override
  String get weekAgo => 'hace 1 semana';

  @override
  String weeksAgo(int count) {
    return 'hace $count semanas';
  }

  @override
  String get thisMonth => 'Este Mes';

  @override
  String get lastMonth => 'Mes Pasado';

  @override
  String get estimatedTotal => 'Total Estimado';

  @override
  String get basedOnScheduledDuration =>
      'Basado en la duración del turno programado';

  @override
  String failedToSendMessage(String error) {
    return 'Error al enviar mensaje: $error';
  }

  @override
  String get pleaseLoginToUseAI =>
      'Por favor inicia sesión para usar el compositor de mensajes IA';

  @override
  String failedToOpenAIComposer(String error) {
    return 'Error al abrir compositor IA: $error';
  }

  @override
  String get callManager => 'Llamar al Gerente';

  @override
  String callPerson(String name) {
    return '¿Llamar a $name?';
  }

  @override
  String get call => 'Llamar';

  @override
  String get callingFeatureAvailableSoon =>
      'La función de llamadas estará disponible pronto';

  @override
  String get failedToLoadMessages => 'Error al cargar mensajes';

  @override
  String get eventNotFound => 'Evento no encontrado';

  @override
  String get declineInvitationQuestion => '¿Rechazar Invitación?';

  @override
  String get declineInvitationConfirm =>
      '¿Estás seguro de que quieres rechazar esta invitación al evento? Se notificará al gerente.';

  @override
  String get declineInvitation => 'Rechazar';

  @override
  String failedToRespond(String error) {
    return 'Error al responder: $error';
  }

  @override
  String get typeAMessage => 'Escribe un mensaje...';

  @override
  String get noMessagesYetTitle => 'Aún no hay mensajes';

  @override
  String get sendMessageToStart =>
      'Envía un mensaje para iniciar la conversación';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get invitationAccepted => '¡Invitación aceptada!';

  @override
  String get invitationDeclined => 'Invitación rechazada';

  @override
  String get aiMessageAssistant => 'Asistente de Mensajes IA';

  @override
  String get clockOut => 'Registrar Salida';

  @override
  String get clockingIn => 'Registrando entrada...';

  @override
  String get clockingOut => 'Registrando salida...';

  @override
  String get clockedInSuccessfully => '✓ ¡Entrada registrada exitosamente!';

  @override
  String get clockedInOffline =>
      '✓ Entrada registrada (sin conexión) - Se sincronizará cuando esté en línea';

  @override
  String clockedOutSuccessfully(String time) {
    return '✓ ¡Salida registrada exitosamente! Tiempo trabajado: $time';
  }

  @override
  String get timerRestored => '✓ Temporizador restaurado - Ya estás registrado';

  @override
  String clockInAvailableIn(String time) {
    return 'Entrada disponible en $time';
  }

  @override
  String autoClockedIn(String eventId) {
    return 'Entrada automática al evento: $eventId';
  }

  @override
  String failedToQueueClockIn(String error) {
    return 'Error al encolar registro de entrada: $error';
  }

  @override
  String failedToQueueClockOut(String error) {
    return 'Error al encolar registro de salida: $error';
  }

  @override
  String get available => 'Disponible';

  @override
  String get unavailable => 'No Disponible';

  @override
  String get confirmed => 'Confirmado';

  @override
  String get availabilityUpdated => 'Disponibilidad actualizada';

  @override
  String get availabilityDeleted => 'Disponibilidad eliminada';

  @override
  String get failedToUpdateAvailability => 'Error al actualizar disponibilidad';

  @override
  String get failedToDeleteAvailability => 'Error al eliminar disponibilidad';

  @override
  String get deleteAvailability => 'Eliminar disponibilidad';

  @override
  String get teams => 'Equipos';

  @override
  String get settings => 'Configuración';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get account => 'Cuenta';

  @override
  String get defaultStartScreen => 'Pantalla de Inicio Predeterminada';

  @override
  String get defaultStartScreenUpdated =>
      'Pantalla de inicio predeterminada actualizada';

  @override
  String get chooseDefaultScreen =>
      'Elige qué pantalla mostrar al abrir la aplicación:';

  @override
  String get shifts => 'Turnos';

  @override
  String get noUpcomingEvents => 'No hay eventos próximos';

  @override
  String get noUpcomingShifts => 'No hay turnos próximos';

  @override
  String get noAvailableRoles => 'No Hay Roles Disponibles';

  @override
  String get noRolesAvailable => 'No hay roles disponibles';

  @override
  String noAvailableTerminology(String terminology) {
    return 'No Hay $terminology Disponibles';
  }

  @override
  String noAcceptedTerminology(String terminology) {
    return 'No hay $terminology aceptados';
  }

  @override
  String noTerminologyMatchProfile(String terminology) {
    return 'Aún no hay $terminology que coincidan con tu perfil. Vuelve pronto o actualiza para ver novedades.';
  }

  @override
  String acceptTerminologyFromRoles(String terminology) {
    return 'Acepta $terminology de la pestaña Roles para verlos aquí';
  }

  @override
  String get noRolesMatchProfile =>
      'Aún no hay roles que coincidan con tu perfil. Vuelve pronto o actualiza para ver novedades.';

  @override
  String get acceptEventsFromRoles =>
      'Acepta eventos de la pestaña Roles para verlos aquí';

  @override
  String get acceptEventFromShifts =>
      'Acepta un evento de la pestaña Turnos para verlo aquí';

  @override
  String get noEventsOrAvailability => 'No hay eventos o disponibilidad';

  @override
  String get pullToRefresh => 'Desliza para actualizar y buscar nuevos eventos';

  @override
  String get calendar => 'Calendario';

  @override
  String get duration => 'Duración';

  @override
  String get start => 'Inicio';

  @override
  String get end => 'Fin';

  @override
  String get estimated => 'Estimado';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String get lastWeek => 'Semana Pasada';

  @override
  String get nextWeek => 'Próxima Semana';

  @override
  String get in2Weeks => 'En 2 Semanas';

  @override
  String get in3Weeks => 'En 3 Semanas';

  @override
  String get eventDateTimeNotAvailable => 'Fecha/hora del evento no disponible';

  @override
  String get eventTimePassed => 'La hora del evento ya pasó';

  @override
  String get noDate => 'Sin Fecha';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get invitation => 'Invitación';

  @override
  String get private => 'Privado';

  @override
  String get clientLabel => 'Cliente: ';

  @override
  String get estimateNoTaxes => 'El estimado no incluye impuestos aplicables';

  @override
  String get locationPermissionRequired => 'Permiso de ubicación requerido';

  @override
  String get locationPermissionDenied =>
      'Permiso de ubicación denegado. Actívalo en configuración.';

  @override
  String get couldNotLaunchMap => 'No se pudo abrir el mapa';

  @override
  String get ask => 'Preguntar';

  @override
  String get noTeamBannerTitle => 'Aún no estás en un equipo';

  @override
  String get noTeamBannerMessage =>
      'Pide a tu gerente un enlace de invitación, o ve a Equipos para ingresar un código.';

  @override
  String get goToTeams => 'Ir a Equipos';
}
