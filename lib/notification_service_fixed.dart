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
    bool permissionsGranted = false;

    // Para iOS
    final bool? iosResult = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('iOS permission: $iosResult');

    // Para Android 13 y posterior, solicitar permiso de notificaciones
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Solicitar permiso para mostrar notificaciones (Android 13+)
      final bool? androidNotificationPermission =
          await androidPlugin.requestNotificationsPermission();
      print('Android notification permission: $androidNotificationPermission');

      // Solicitar permiso para usar alarmas exactas (Android 12+)
      final bool? androidAlarmPermission =
          await androidPlugin.requestExactAlarmsPermission();
      print('Android exact alarm permission: $androidAlarmPermission');

      permissionsGranted = (androidNotificationPermission ?? false) ||
          (androidAlarmPermission ?? false) ||
          (iosResult ?? false);
    }

    return permissionsGranted ||
        (iosResult ?? true); // Devolver true si al menos uno es concedido
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

      try {
        // Calcular la próxima fecha para la notificación
        final DateTime now = DateTime.now();
        DateTime nextDate = DateTime(now.year, now.month, now.day,
            scheduledTime.hour, scheduledTime.minute);

        // Si la hora ya pasó hoy, programar para mañana
        if (nextDate.isBefore(now)) {
          nextDate = nextDate.add(const Duration(days: 1));
        }

        print(
            'Programando notificación para $title a las ${scheduledTime.hour}:${scheduledTime.minute}');
        print('Próxima fecha de notificación: $nextDate');

        // Convertir a TZDateTime que requiere el plugin
        final tz.TZDateTime tzDate = tz.TZDateTime.from(nextDate, tz.local);

        try {
          // Intentar con androidScheduleMode.exactAllowWhileIdle primero
          await flutterLocalNotificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            tzDate,
            _notificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents:
                DateTimeComponents.time, // Notificación diaria a la misma hora
            payload: payload,
          );
          print('Notificación programada correctamente con exact alarm');
        } catch (exactError) {
          print(
              'Error con exact alarm: $exactError. Intentando con alarma inexacta...');

          // Intento con modo inexacto
          try {
            await flutterLocalNotificationsPlugin.zonedSchedule(
              id,
              title,
              body,
              tzDate,
              _notificationDetails(),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: payload,
            );
            print('Notificación programada con alarma inexacta');
          } catch (inexactError) {
            print(
                'Error con alarma inexacta: $inexactError. Mostrando notificación inmediata...');

            // Último recurso: mostrar una notificación inmediata
            await flutterLocalNotificationsPlugin.show(
              id,
              title,
              body,
              _notificationDetails(),
              payload: payload,
            );
            print('Notificación inmediata mostrada como alternativa');
          }
        }
      } catch (e) {
        print('Error al preparar la notificación programada: $e');
        // Intentamos un método alternativo más simple
        try {
          print('Intentando método alternativo con notificación inmediata...');

          // Usar show como último recurso
          await flutterLocalNotificationsPlugin.show(
            id,
            title,
            body,
            _notificationDetails(),
            payload: payload,
          );

          print('Notificación inmediata mostrada como alternativa final');
        } catch (fallbackError) {
          print('Error en método alternativo final: $fallbackError');
        }
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
      print('Error general al programar notificación: $e');
    }
  }
  // Este método se ha eliminado porque ya no se usa

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

  // Método para obtener todas las notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print(
          "Notificaciones pendientes encontradas: ${pendingNotifications.length}");
      return pendingNotifications;
    } catch (e) {
      print("Error al obtener notificaciones pendientes: $e");
      return [];
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

  // Método para mostrar una notificación inmediata, útil para pruebas
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );
  }
}
