import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  // Instancia del plugin de notificaciones
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicialización
  Future<void> init() async {
    // Configuración para Android (usando el icono predeterminado de la aplicación)
    // Cambiamos 'ic_launcher' a '@mipmap/ic_launcher', que es el ícono de la app
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Inicializar el plugin con la configuración
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Inicializar timezone y establecer zona horaria local
    tz_data.initializeTimeZones();
    try {
      // Utilizamos un bloque try-catch para manejar posibles errores
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      print("Zona horaria establecida correctamente: Europe/Madrid");
    } catch (e) {
      // Si hay algún error, usamos UTC como zona horaria predeterminada
      print(
          "Error al establecer zona horaria: $e. Usando UTC como alternativa.");
      tz.setLocalLocation(tz.UTC);
    }
  }

  // Método para manejar el toque en la notificación
  void _onNotificationTap(NotificationResponse? response) {
    // Aquí puedes manejar la acción cuando el usuario toca la notificación
    // Por ejemplo, navegar a la pantalla de detalles del medicamento
    if (response?.payload != null) {
      // Puedes usar el payload para enviar información adicional
      print('Notificación tocada con payload: ${response?.payload}');
      // Aquí podrías implementar la navegación a la pantalla correspondiente
    }
  }

  // Método para verificar permisos de notificaciones
  Future<bool> requestPermissions() async {
    // Para iOS
    final bool? iosResult = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Para Android, los permisos se solicitan en tiempo de ejecución desde Android 13+
    // En versiones anteriores, se usan los permisos declarados en AndroidManifest.xml
    print('iOS permission: $iosResult');
    return iosResult ?? true; // Para Android devolvemos true por defecto
  }

  // Método para programar una notificación para un medicamento
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id, // ID único para la notificación
      title, // Título de la notificación
      body, // Cuerpo de la notificación
      tz.TZDateTime.from(scheduledTime, tz.local), // Fecha y hora programada
      _notificationDetails(), // Detalles de la notificación
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Para notificaciones recurrentes diarias
      payload:
          payload, // Datos adicionales para usar cuando se toca la notificación
    );
  }

  // Método para programar notificaciones recurrentes para medicamentos (diario)
  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required List<int>
        diasSemana, // Mantenido por compatibilidad pero ya no se usa
    String? payload,
  }) async {
    try {
      // Verificar permisos antes de programar
      final bool permiso = await requestPermissions();
      print('Permisos de notificación: $permiso');

      // Primero cancelamos cualquier notificación anterior con el mismo ID
      await cancelNotification(id);

      print(
          'Programando notificación para $title a las ${scheduledTime.hour}:${scheduledTime.minute}');

      try {
        // Obtener la próxima fecha de notificación
        final tz.TZDateTime nextScheduledDate =
            _nextInstanceOfTime(scheduledTime.hour, scheduledTime.minute);
        print('Próxima fecha de notificación: $nextScheduledDate');

        // Programar la notificación con manejo de errores
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            id, // ID único para la notificación
            title,
            body,
            nextScheduledDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents:
                DateTimeComponents.time, // Notificación diaria a la misma hora
            payload: payload,
          );
        } catch (innerError) {
          print('Error en zonedSchedule: $innerError');

          // Intento alternativo con DateTime normal en lugar de TZDateTime
          print('Intentando método alternativo de programación...');
          final now = DateTime.now();
          final tomorrow = now.add(Duration(days: 1));
          final scheduledDateTime = DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            scheduledTime.hour,
            scheduledTime.minute,
          );

          // Convertir a TZDateTime para poder usar zonedSchedule (schedule no existe)
          final tz.TZDateTime tzScheduledDate =
              tz.TZDateTime.from(scheduledDateTime, tz.UTC);

          await flutterLocalNotificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            tzScheduledDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );

          print('Programación alternativa exitosa para: $scheduledDateTime');
        }
      } catch (schedulingError) {
        print('Error al preparar la notificación programada: $schedulingError');
        throw schedulingError; // Relanzar para manejo en el catch externo
      }

      // Verificación de la programación
      final pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print(
          'Total de notificaciones programadas después de añadir: ${pendingNotifications.length}');
      final thisNotification = pendingNotifications
          .where((notification) => notification.id == id)
          .toList();
      print(
          '¿Se encontró la notificación recién programada? ${thisNotification.isNotEmpty}');
    } catch (e) {
      print('Error al programar notificación recurrente: $e');
    }
  }

  // Se ha eliminado el método _nextInstanceOfDayAndTime porque ya no se utiliza

  // Calcular la próxima fecha para una hora específica (diariamente)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    try {
      // Primero obtenemos la fecha y hora actual
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      print("Hora actual en zona horaria local: $now");

      // Creamos la fecha programada
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      print("Fecha programada inicial: $scheduledDate");

      // Si la hora ya pasó hoy, programar para mañana
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        print("La hora ya pasó, reprogramando para mañana: $scheduledDate");
      }

      return scheduledDate;
    } catch (e) {
      // Si hay algún error, usamos una alternativa segura con DateTime estándar
      print(
          "Error al calcular fecha de notificación: $e. Usando método alternativo.");
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Convertir a TZDateTime usando UTC como fallback
      return tz.TZDateTime.from(scheduledDate, tz.UTC);
    }
  }

  // Cancelar una notificación específica
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Comprobar si las notificaciones están habilitadas
  Future<bool> checkNotificationsEnabled() async {
    try {
      final List<PendingNotificationRequest> pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('Notificaciones pendientes: ${pendingNotifications.length}');
      return pendingNotifications.isNotEmpty;
    } catch (e) {
      print('Error al comprobar notificaciones: $e');
      return false;
    }
  }

  // Detalles de notificación personalizados
  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'medicamentos_channel', // ID del canal
        'Recordatorios de medicamentos', // Nombre del canal
        channelDescription:
            'Notificaciones de recordatorios para tomar medicamentos', // Descripción
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        ledColor: Color(0xFF00FF00), // Color del LED
        ledOnMs: 1000,
        ledOffMs: 500,
        visibility:
            NotificationVisibility.public, // Visible en pantalla de bloqueo
        category: AndroidNotificationCategory.alarm, // Categoría de alarma
        fullScreenIntent: true, // Mostrar incluso con pantalla bloqueada
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'mark_taken',
            'Marcar como tomado',
            cancelNotification:
                true, // La notificación se cierra automáticamente al pulsar esta acción
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel:
            InterruptionLevel.timeSensitive, // Mayor nivel de interrupción
        threadIdentifier:
            'medicamentos', // Identificador para agrupar notificaciones
        categoryIdentifier: 'medication_reminder',
      ),
    );
  }
}
