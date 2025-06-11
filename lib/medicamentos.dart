import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:medicontrol/add_medicamento.dart';
import 'notification_service_fixed.dart'; // Importamos el servicio de notificaciones mejorado
import 'utils/responsive_utils.dart';

class MedicamentosScreen extends StatefulWidget {
  const MedicamentosScreen({Key? key}) : super(key: key);

  @override
  State<MedicamentosScreen> createState() => _MedicamentosScreenState();
}

class _MedicamentosScreenState extends State<MedicamentosScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> medicamentos = [];
  bool _localeInitialized = false;
  bool _isLoading = true;
  bool _mostrarTomados =
      true; // Control para mostrar/ocultar medicamentos tomados
  final NotificationService _notificationService =
      NotificationService(); // Inicializamos el servicio

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _cargarMedicamentos();
    _initNotifications(); // Inicializamos las notificaciones
  }

  // Método para inicializar las notificaciones
  Future<void> _initNotifications() async {
    await _notificationService.init();
    final permissionsGranted = await _notificationService.requestPermissions();
    print('Permisos de notificaciones concedidos: $permissionsGranted');

    // Verificar si hay notificaciones pendientes (diagnóstico)
    final hasNotifications =
        await _notificationService.checkNotificationsEnabled();
    print('Hay notificaciones programadas: $hasNotifications');

    if (!hasNotifications) {
      // Mostrar alerta al usuario si no hay notificaciones programadas
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No hay notificaciones programadas. Por favor, añade un medicamento para recibir recordatorios.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }
  }

  // Inicializar los datos de localización
  Future<void> _initializeLocale() async {
    await initializeDateFormatting('es_ES', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
    }
  }

  // Cargar medicamentos desde Supabase
  Future<void> _cargarMedicamentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("Error: No hay usuario autenticado");
        return;
      }

      try {
        // 1. Cargar medicamentos
        final response = await supabase
            .from('medicamentos')
            .select('*, id')
            .eq('usuario_id', user.id)
            .order('hora',
                ascending:
                    true); // 2. Obtener la fecha de hoy para verificar medicamentos tomados
        final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime
            .now()); // 3. Cargar registros de historial de hoy para saber qué medicamentos ya se tomaron
        final historialHoy = await supabase
            .from('historial')
            .select('medicamento_id, tomado')
            .eq('usuario_id', user.id)
            .eq('fecha', fechaHoy)
            .eq('tomado', true);

        print(
            "Registros de historial de hoy: ${historialHoy.length}"); // 4. Cargar y asociar horarios adicionales para cada medicamento a partir de las notificaciones
        final medicamentosConHorarios =
            await _cargarHorariosAdicionales(response);
        print(
            "Medicamentos con horarios procesados: ${medicamentosConHorarios.length}");

        // Crear un mapa de medicamentos tomados para búsqueda rápida
        final medicamentosTomadosHoy = <String, bool>{};
        for (final registro in historialHoy) {
          medicamentosTomadosHoy[registro['medicamento_id'].toString()] = true;
        }

        setState(() {
          // Filtramos los medicamentos que deben mostrarse hoy (sólo basado en la duración)
          medicamentos = medicamentosConHorarios.where((med) {
            // Ya no filtramos por día de la semana, todos los medicamentos se muestran diariamente
            // si están dentro del período de tratamiento

            // Verificar duración del tratamiento
            bool estaEnPeriodoTratamiento = true;
            if (med['fecha_inicio'] != null && med['duracion'] != null) {
              DateTime fechaInicio = DateTime.parse(med['fecha_inicio']);
              int duracionDias = med['duracion'];
              DateTime fechaFin = fechaInicio.add(Duration(days: duracionDias));
              DateTime hoy = DateTime.now();
              estaEnPeriodoTratamiento = hoy.isBefore(fechaFin) &&
                  hoy.isAfter(fechaInicio.subtract(const Duration(days: 1)));
            }

            // El medicamento debe estar dentro del periodo de tratamiento
            return estaEnPeriodoTratamiento;
          }).map((med) {
            // Verificar si este medicamento está en el historial de hoy
            final medicamentoId = med['id'].toString();
            med['tomado_local'] =
                medicamentosTomadosHoy[medicamentoId] ?? false;
            return med;
          }).toList();

          _isLoading = false;
        });

        print(
            "Medicamentos filtrados cargados correctamente: ${medicamentos.length}");
      } catch (dbError) {
        print("Error al cargar medicamentos: $dbError");
        if (dbError.toString().contains("does not exist")) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Error: La tabla medicamentos no existe en la base de datos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error general: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar medicamentos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para formatear la hora para asegurar que se muestre correctamente
  String _formatearHoraMostrar(String hora) {
    if (hora.isEmpty) return '--:--';

    try {
      // Dividir la hora en horas y minutos
      final parts = hora.split(':');
      if (parts.length < 2) {
        print("Formato de hora incorrecto: $hora");
        return hora; // Devolver la hora original si no tiene el formato esperado
      }

      // Extraer horas y minutos, asegurando que sean números válidos
      int horas = int.tryParse(parts[0].trim()) ?? 0;
      int minutos = int.tryParse(parts[1].trim()) ?? 0;

      // Asegurar que las horas y minutos estén en el rango correcto
      horas = horas.clamp(0, 23);
      minutos = minutos.clamp(0, 59);

      // Formatear la hora como HH:mm con ceros a la izquierda
      return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}';
    } catch (e) {
      print("Error al formatear la hora para mostrar: $e");
      return hora;
    }
  }

  // Método para comparar horas (formato HH:mm)
  int _compararHoras(String horaA, String horaB) {
    try {
      // Formatear ambas horas para asegurar que estén normalizadas
      horaA = _formatearHoraMostrar(horaA);
      horaB = _formatearHoraMostrar(horaB);

      return horaA.compareTo(horaB);
    } catch (e) {
      print("Error al comparar horas: $e");
      return 0;
    }
  }

  // Método para obtener el próximo medicamento a tomar
  Map<String, dynamic>? _obtenerProximoMedicamento() {
    if (medicamentos.isEmpty) {
      return null;
    }

    // Obtener la hora actual
    final ahora = DateTime.now();
    final horaActual = DateFormat('HH:mm').format(ahora);

    // Filtrar medicamentos que no se han tomado
    final medicamentosNoTomados =
        medicamentos.where((med) => med['tomado_local'] != true).toList();

    if (medicamentosNoTomados.isEmpty) {
      return null; // No hay medicamentos pendientes
    }

    // Normalizamos las horas de los medicamentos para ordenarlos correctamente
    for (var med in medicamentosNoTomados) {
      med['hora'] = _formatearHoraMostrar(med['hora'] ?? '');
    }

    // Ordenar por hora para encontrar el próximo
    medicamentosNoTomados.sort((a, b) {
      // Usar la función de comparación de horas
      final horaA = a['hora'] as String;
      final horaB = b['hora'] as String;

      // Si la hora ya pasó, ponla al final
      final horaAPasada = _compararHoras(horaA, horaActual) < 0;
      final horaBPasada = _compararHoras(horaB, horaActual) < 0;

      if (horaAPasada && !horaBPasada) {
        return 1; // A ya pasó, B es próxima
      } else if (!horaAPasada && horaBPasada) {
        return -1; // B ya pasó, A es próxima
      } else {
        // Ambas pasaron o ambas son futuras, ordena por hora
        return _compararHoras(horaA, horaB);
      }
    });

    // El primer medicamento en la lista ordenada es el próximo a tomar
    return medicamentosNoTomados.first;
  }

  // Método para marcar un medicamento como tomado/no tomado
  Future<void> _toggleMedicamentoTomado(
      Map<String, dynamic> medicamento) async {
    try {
      // Verificar el estado actual del medicamento
      final bool tomadoActual = medicamento['tomado_local'] ?? false;
      final nuevoEstado = !tomadoActual;

      print(
          "Cambiando estado del medicamento ${medicamento['nombre']} a: $nuevoEstado");

      // Actualizar estado local para la UI
      setState(() {
        medicamento['tomado_local'] = nuevoEstado;
      });

      if (nuevoEstado) {
        // Si se marca como tomado, guardar en el historial
        try {
          final user = supabase.auth.currentUser;
          if (user == null) {
            throw Exception("No hay usuario autenticado");
          }

          // Obtener la fecha y hora actual
          final ahora = DateTime.now();
          final fechaHoy = DateFormat('yyyy-MM-dd').format(ahora);
          final horaActual = DateFormat('HH:mm:ss').format(ahora);

          // Guardar en la tabla historial
          await supabase.from('historial').insert({
            'usuario_id': user.id,
            'medicamento_id': medicamento['id'],
            'fecha': fechaHoy,
            'hora_toma': horaActual,
            'tomado': true,
          });

          print(
              "Medicamento guardado en historial correctamente: ${medicamento['nombre']}");
        } catch (historialError) {
          print("Error al guardar en historial: $historialError");
          // Mostrar error pero no revertir el estado local
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Medicamento marcado como tomado, pero hubo un error al guardar en el historial: ${historialError.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Mostrar mensaje de confirmación
      final mensaje = nuevoEstado
          ? '¡Medicamento marcado como tomado!'
          : 'Medicamento marcado como no tomado';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: nuevoEstado ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error al marcar medicamento: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para eliminar un medicamento
  Future<void> _eliminarMedicamento(Map<String, dynamic> medicamento) async {
    try {
      // Verificar que el medicamento tiene un ID
      if (medicamento['id'] == null) {
        print("Error: El medicamento no tiene ID.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: El medicamento no tiene identificador'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Imprimir información del medicamento para depuración
      print(
          "Intentando eliminar medicamento: ${medicamento['nombre']} con ID: ${medicamento['id']}");

      // Mostrar diálogo de confirmación
      bool confirmar = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Eliminar medicamento'),
              content: Text(
                  '¿Estás seguro de que quieres eliminar "${medicamento['nombre']}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancelar'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Eliminar'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmar) {
        print("Eliminación cancelada por el usuario.");
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // IMPORTANTE: Primero eliminamos los registros del historial relacionados con este medicamento
      // para evitar violar la restricción de clave foránea
      try {
        print(
            "Eliminando registros de historial para el medicamento ID: ${medicamento['id']}");
        await supabase
            .from('historial')
            .delete()
            .eq('medicamento_id', medicamento['id']);

        print("Historial relacionado eliminado correctamente");

        // Ahora que se han eliminado los registros del historial, podemos eliminar el medicamento
        await supabase
            .from('medicamentos')
            .delete()
            .eq('id', medicamento['id']);

        print("Medicamento eliminado correctamente");

        // Actualizar la lista completa de medicamentos
        await _cargarMedicamentos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Medicamento "${medicamento['nombre']}" eliminado correctamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (innerError) {
        print("Error al eliminar: $innerError");
        throw innerError; // Relanzar el error para que lo maneje el catch externo
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print("Error detallado al eliminar medicamento: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el medicamento: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para cargar los horarios adicionales de cada medicamento
  Future<List<dynamic>> _cargarHorariosAdicionales(
      List<dynamic> medicamentosBase) async {
    try {
      // Obtenemos todas las notificaciones programadas
      final todasLasNotificaciones =
          await _notificationService.getPendingNotifications();
      print(
          "Total notificaciones programadas: ${todasLasNotificaciones.length}");

      // Para cada medicamento, buscamos sus notificaciones asociadas
      for (var med in medicamentosBase) {
        final int medicamentoId = med['id'];
        List<String> horarios = [med['hora'] ?? ''];

        // Buscamos notificaciones asociadas a este medicamento
        // El formato de ID es: medicamentoId * 100 + índice
        for (var notif in todasLasNotificaciones) {
          final int notifId = notif.id;
          if (notifId >= medicamentoId * 100 &&
              notifId < (medicamentoId + 1) * 100) {
            // Extraer la hora del payload
            final String? payload = notif.payload;
            if (payload != null && payload.contains('hora_')) {
              // Intentamos extraer la hora del payload si existe
              final horaMatch =
                  RegExp(r'hora_(\d{2}:\d{2})').firstMatch(payload);
              if (horaMatch != null && horaMatch.groupCount >= 1) {
                final String horaStr = horaMatch.group(1)!;
                if (!horarios.contains(horaStr)) {
                  horarios.add(horaStr);
                }
              }
            }
          }
        }

        // Ordenar los horarios
        horarios.sort();

        // Añadir la lista de horarios al medicamento
        med['todos_horarios'] = horarios;
      }

      return medicamentosBase;
    } catch (e) {
      print("Error al cargar horarios adicionales: $e");
      return medicamentosBase;
    }
  }

  // Método para editar un medicamento existente
  Future<void> _editarMedicamento(Map<String, dynamic> medicamento) async {
    try {
      // Navegar a la pantalla de edición y pasar el medicamento existente
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AnadirMedicamentoScreen(
            medicamentoExistente: medicamento,
            esEdicion: true,
          ),
        ),
      );

      // Si se guardaron los cambios, recargar la lista de medicamentos
      if (result == true) {
        await _cargarMedicamentos();
      }
    } catch (e) {
      print("Error al abrir la pantalla de edición: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error al abrir la pantalla de edición: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive settings
    final isTablet = ResponsiveUtils.isTablet(context);

    final nombreUsuario =
        Supabase.instance.client.auth.currentUser?.email ?? 'Usuario';
    final firstName = nombreUsuario.split('@').first;

    // Determinar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Si la localización no está inicializada, mostrar cargando
    if (!_localeInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "MediControl",
            style: TextStyle(
              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                  mobile: 20, tablet: 22, desktop: 24),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Mis Medicamentos",
          style: TextStyle(
            fontSize: ResponsiveUtils.getAdaptiveSize(context,
                mobile: 20, tablet: 22, desktop: 24),
          ),
        ),
        elevation: 4,
        centerTitle: false,
        backgroundColor: isDarkMode
            ? Color.fromARGB(255, 30, 30, 40)
            : primaryColor.withOpacity(0.8),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarMedicamentos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: primaryColor,
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getAdaptiveSize(context,
                          mobile: 16, tablet: 20, desktop: 24)),
                  Text(
                    "Cargando medicamentos...",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: ResponsiveUtils.getAdaptiveSize(context,
                          mobile: 16, tablet: 18, desktop: 20),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          Color.fromARGB(255, 30, 30, 40),
                          Color.fromARGB(255, 20, 20, 30)
                        ]
                      : [Colors.white, Color.fromARGB(255, 240, 245, 255)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado con saludo y fecha
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? [
                                    primaryColor.withOpacity(0.6),
                                    primaryColor.withOpacity(0.3)
                                  ]
                                : [
                                    primaryColor.withOpacity(0.7),
                                    primaryColor.withOpacity(0.4)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Elementos decorativos de fondo
                            Positioned(
                              right: -15,
                              top: -15,
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            Positioned(
                              left: -25,
                              bottom: -25,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            // Contenido principal
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  radius: isTablet ? 28 : 24,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: isTablet ? 32 : 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "👋 Hola, ${firstName.capitalize()}",
                                        style: TextStyle(
                                          fontSize: isTablet ? 22 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "📅 ${DateFormat('EEEE, d MMMM', 'es_ES').format(DateTime.now()).capitalize()}",
                                        style: TextStyle(
                                          fontSize: isTablet ? 14 : 13,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Próxima toma
                      Builder(
                        builder: (context) {
                          final proximoMedicamento =
                              _obtenerProximoMedicamento();

                          if (proximoMedicamento != null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.notifications_active,
                                        color: Colors.orange.shade700,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        "Próxima toma",
                                        style: TextStyle(
                                          fontSize: isTablet ? 22 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.orange.shade800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  elevation: 4,
                                  color: isDarkMode
                                      ? Color.fromARGB(255, 40, 40, 50)
                                      : Colors.white,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.orange.shade200
                                            .withOpacity(
                                                isDarkMode ? 0.3 : 0.5),
                                        width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.orange
                                                  .withOpacity(
                                                      isDarkMode ? 0.2 : 0.1),
                                              child: Icon(Icons.medication,
                                                  color:
                                                      Colors.orange.shade700),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    proximoMedicamento[
                                                        'nombre'],
                                                    style: TextStyle(
                                                      fontSize:
                                                          isTablet ? 20 : 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Dosis: ${proximoMedicamento['dosis']}",
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white70
                                                          : Colors
                                                              .grey.shade700,
                                                      fontSize:
                                                          isTablet ? 16 : 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                // Mostrar diálogo con todos los horarios si tiene más de uno
                                                if (proximoMedicamento['todos_horarios'] !=
                                                        null &&
                                                    proximoMedicamento[
                                                            'todos_horarios']
                                                        is List &&
                                                    (proximoMedicamento[
                                                                    'todos_horarios']
                                                                as List)
                                                            .length >
                                                        1) {
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        title: Text(
                                                          'Horarios de ${proximoMedicamento['nombre']}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.orange
                                                                .shade700,
                                                          ),
                                                        ),
                                                        content:
                                                            SingleChildScrollView(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              ...(proximoMedicamento[
                                                                          'todos_horarios']
                                                                      as List)
                                                                  .map((hora) =>
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                4.0),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.access_time,
                                                                                color: Colors.orange.shade700),
                                                                            SizedBox(width: 8),
                                                                            Text(
                                                                              _formatearHoraMostrar(hora.toString()),
                                                                              style: TextStyle(fontSize: 16),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ))
                                                                  .toList(),
                                                            ],
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            child:
                                                                Text('Cerrar'),
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(isDarkMode
                                                          ? 0.2
                                                          : 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      "⏰ ${_formatearHoraMostrar(proximoMedicamento['hora'] ?? '')}",
                                                      style: TextStyle(
                                                        fontSize:
                                                            isTablet ? 16 : 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .orange.shade800,
                                                      ),
                                                    ),
                                                    if (proximoMedicamento[
                                                                'todos_horarios'] !=
                                                            null &&
                                                        proximoMedicamento[
                                                                'todos_horarios']
                                                            is List &&
                                                        (proximoMedicamento[
                                                                        'todos_horarios']
                                                                    as List)
                                                                .length >
                                                            1) ...[
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "+${(proximoMedicamento['todos_horarios'] as List).length - 1}",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: isTablet
                                                              ? 14
                                                              : 12,
                                                          color: Colors
                                                              .orange.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Botón para marcar como tomado
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _toggleMedicamentoTomado(
                                                      proximoMedicamento),
                                              icon: Icon(
                                                proximoMedicamento[
                                                            'tomado_local'] ==
                                                        true
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                              ),
                                              label: Text(
                                                proximoMedicamento[
                                                            'tomado_local'] ==
                                                        true
                                                    ? 'Tomado'
                                                    : 'Marcar como tomado',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    proximoMedicamento[
                                                                'tomado_local'] ==
                                                            true
                                                        ? Colors.green
                                                        : primaryColor,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.blue.shade900.withOpacity(0.2)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.blue.shade700.withOpacity(0.3)
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "No hay medicamentos pendientes para tomar.",
                                      style: TextStyle(
                                        fontSize: isTablet ? 16 : 14,
                                        color: isDarkMode
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // Control para mostrar/ocultar medicamentos tomados
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Mostrar medicamentos tomados",
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Switch(
                              value: _mostrarTomados,
                              onChanged: (value) {
                                setState(() {
                                  _mostrarTomados = value;
                                });
                              },
                              activeColor: primaryColor,
                              activeTrackColor: primaryColor.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                          height: 20), // Título de la lista de medicamentos
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.medication,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              "Medicamentos programados",
                              style: TextStyle(
                                  fontSize: isTablet ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lista de medicamentos
                      Expanded(
                        child: medicamentos.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.medication_outlined,
                                      size: isTablet ? 80 : 60,
                                      color: isDarkMode
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Aún no tienes medicamentos",
                                      style: TextStyle(
                                        fontSize: isTablet ? 18 : 16,
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Pulsa el botón + para añadir uno nuevo",
                                      style: TextStyle(
                                        fontSize: isTablet ? 16 : 14,
                                        color: isDarkMode
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: medicamentos.length,
                                padding: const EdgeInsets.only(bottom: 80),
                                physics: BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final med = medicamentos[index];
                                  final tomado = med['tomado_local'] == true;

                                  // No mostrar medicamentos tomados si _mostrarTomados es false
                                  if (!_mostrarTomados && tomado) {
                                    return const SizedBox.shrink();
                                  }

                                  // Determinar qué días debe tomar este medicamento (para mostrar)
                                  String diasToma = "";
                                  if (med['dias'] != null &&
                                      med['dias'] is List) {
                                    List<dynamic> dias = med['dias'];
                                    List<String> nombresDias = [];

                                    // Convertir números de día en nombres abreviados
                                    Map<int, String> mapaDias = {
                                      1: "Lun",
                                      2: "Mar",
                                      3: "Mié",
                                      4: "Jue",
                                      5: "Vie",
                                      6: "Sáb",
                                      7: "Dom"
                                    };

                                    for (int dia in dias) {
                                      nombresDias.add(mapaDias[dia] ?? "$dia");
                                    }

                                    // Ordenar los días de la semana
                                    nombresDias.sort((a, b) {
                                      Map<String, int> orden = {
                                        "Lun": 1,
                                        "Mar": 2,
                                        "Mié": 3,
                                        "Jue": 4,
                                        "Vie": 5,
                                        "Sáb": 6,
                                        "Dom": 7
                                      };
                                      return (orden[a] ?? 99)
                                          .compareTo(orden[b] ?? 99);
                                    });

                                    diasToma = nombresDias.join(", ");
                                  }

                                  // Información sobre duración del tratamiento
                                  String duracionInfo = "";
                                  int diasRestantes = 0;
                                  if (med['fecha_inicio'] != null &&
                                      med['duracion'] != null) {
                                    DateTime fechaInicio =
                                        DateTime.parse(med['fecha_inicio']);
                                    int duracionDias = med['duracion'];
                                    DateTime fechaFin = fechaInicio
                                        .add(Duration(days: duracionDias));
                                    DateTime hoy = DateTime
                                        .now(); // Calculamos días restantes
                                    // Usamos midnight para considerar días completos
                                    DateTime hoyMidnight =
                                        DateTime(hoy.year, hoy.month, hoy.day);
                                    DateTime fechaFinMidnight = DateTime(
                                        fechaFin.year,
                                        fechaFin.month,
                                        fechaFin.day);
                                    diasRestantes = fechaFinMidnight
                                        .difference(hoyMidnight)
                                        .inDays;

                                    // Si los días son negativos, establecemos a 0
                                    if (diasRestantes < 0) {
                                      diasRestantes = 0;
                                    }

                                    // Formatear fechas para mostrar
                                    String inicioStr =
                                        DateFormat('dd/MM', 'es_ES')
                                            .format(fechaInicio);
                                    String finStr = DateFormat('dd/MM', 'es_ES')
                                        .format(fechaFin);

                                    // Información básica del tratamiento
                                    duracionInfo = "$inicioStr - $finStr";
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    color: isDarkMode
                                        ? Color.fromARGB(255, 40, 40, 50)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: tomado
                                            ? Colors.green.withOpacity(
                                                isDarkMode ? 0.3 : 0.2)
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Hacer que el ListTile sea clicable para editar el medicamento
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 12),
                                          onTap: () => _editarMedicamento(med),
                                          leading: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: tomado
                                                  ? Colors.green.withOpacity(
                                                      isDarkMode ? 0.2 : 0.1)
                                                  : primaryColor.withOpacity(
                                                      isDarkMode ? 0.2 : 0.1),
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Icon(
                                                  Icons.medication,
                                                  color: tomado
                                                      ? Colors.green
                                                      : primaryColor,
                                                  size: 28,
                                                ),
                                                if (tomado)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration: BoxDecoration(
                                                        color: isDarkMode
                                                            ? Color.fromARGB(
                                                                255, 40, 40, 50)
                                                            : Colors.white,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: Colors.green
                                                                .shade100),
                                                      ),
                                                      child: Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  med['nombre'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                        isTablet ? 18 : 16,
                                                    decoration: tomado
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                    color: tomado
                                                        ? Colors.grey
                                                        : isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Siempre mostramos el botón de expandir para ver todos los horarios de notificación
                                              InkWell(
                                                onTap: () {
                                                  // Mostrar diálogo con todos los horarios
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        title: Text(
                                                          'Horarios de ${med['nombre']}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                        content:
                                                            SingleChildScrollView(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              // Mostrar todos los horarios del medicamento
                                                              ...((med['todos_horarios']
                                                                          as List<
                                                                              dynamic>?) ??
                                                                      [
                                                                        med['hora']
                                                                      ])
                                                                  .map((hora) =>
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                4.0),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.access_time,
                                                                                color: primaryColor),
                                                                            SizedBox(width: 8),
                                                                            Text(
                                                                              _formatearHoraMostrar(hora.toString()),
                                                                              style: TextStyle(fontSize: 16),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ))
                                                                  .toList(),
                                                            ],
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            child:
                                                                Text('Cerrar'),
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: tomado
                                                        ? Colors.green
                                                            .withOpacity(
                                                                isDarkMode
                                                                    ? 0.2
                                                                    : 0.1)
                                                        : primaryColor
                                                            .withOpacity(
                                                                isDarkMode
                                                                    ? 0.2
                                                                    : 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "⏰ ${_formatearHoraMostrar(med['hora'] ?? '')}",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: tomado
                                                              ? Colors.green
                                                              : primaryColor,
                                                          fontSize: isTablet
                                                              ? 16
                                                              : 13,
                                                        ),
                                                      ),
                                                      if (((med['todos_horarios']
                                                                      as List<
                                                                          dynamic>?)
                                                                  ?.length ??
                                                              0) >
                                                          1) ...[
                                                        SizedBox(width: 2),
                                                        Text(
                                                          "+${((med['todos_horarios'] as List<dynamic>?)?.length ?? 1) - 1}",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: tomado
                                                                ? Colors.green
                                                                : primaryColor,
                                                            fontSize: isTablet
                                                                ? 14
                                                                : 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              Text(
                                                "Dosis: ${med['dosis']}",
                                                style: TextStyle(
                                                  fontSize: isTablet ? 15 : 14,
                                                  decoration: tomado
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  color: tomado
                                                      ? Colors.grey
                                                      : isDarkMode
                                                          ? Colors.white70
                                                          : null,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              // Mostrar días de toma si están disponibles
                                              if (diasToma.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_today,
                                                        size: 14,
                                                        color: isDarkMode
                                                            ? primaryColor
                                                                .withOpacity(
                                                                    0.8)
                                                            : primaryColor),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        "Días: $diasToma",
                                                        style: TextStyle(
                                                          fontSize: isTablet
                                                              ? 14
                                                              : 13,
                                                          color: isDarkMode
                                                              ? primaryColor
                                                                  .withOpacity(
                                                                      0.8)
                                                              : primaryColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              // Mostrar duración si está disponible
                                              if (duracionInfo.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.date_range,
                                                        size: 14,
                                                        color: Colors
                                                            .purple.shade300),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        "Tratamiento: $duracionInfo",
                                                        style: TextStyle(
                                                          fontSize: isTablet
                                                              ? 14
                                                              : 13,
                                                          color: Colors
                                                              .purple.shade300,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.hourglass_empty,
                                                        size: 14,
                                                        color: diasRestantes > 5
                                                            ? Colors.green
                                                            : (diasRestantes > 2
                                                                ? Colors.orange
                                                                : Colors.red)),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        "Días restantes: $diasRestantes",
                                                        style: TextStyle(
                                                          fontSize: isTablet
                                                              ? 14
                                                              : 13,
                                                          color: diasRestantes >
                                                                  5
                                                              ? Colors.green
                                                              : (diasRestantes >
                                                                      2
                                                                  ? Colors
                                                                      .orange
                                                                  : Colors.red),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Botones para acciones
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                  color: isDarkMode
                                                      ? Colors.grey.shade800
                                                      : Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () =>
                                                      _toggleMedicamentoTomado(
                                                          med),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    bottomLeft:
                                                        Radius.circular(16),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12,
                                                        horizontal: 16),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          tomado
                                                              ? Icons
                                                                  .check_circle
                                                              : Icons
                                                                  .circle_outlined,
                                                          color: tomado
                                                              ? Colors.green
                                                              : isDarkMode
                                                                  ? Colors.grey
                                                                      .shade400
                                                                  : Colors.grey
                                                                      .shade600,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            tomado
                                                                ? 'Tomado'
                                                                : 'Marcar como tomado',
                                                            style: TextStyle(
                                                              color: tomado
                                                                  ? Colors.green
                                                                  : isDarkMode
                                                                      ? Colors
                                                                          .grey
                                                                          .shade400
                                                                      : Colors
                                                                          .grey
                                                                          .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                  width: 1,
                                                  height: 36,
                                                  color: isDarkMode
                                                      ? Colors.grey.shade800
                                                      : Colors.grey.shade200),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () =>
                                                      _eliminarMedicamento(med),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    bottomRight:
                                                        Radius.circular(16),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12,
                                                        horizontal: 16),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.delete_outline,
                                                          color: isDarkMode
                                                              ? Colors
                                                                  .red.shade300
                                                              : Colors
                                                                  .red.shade600,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            'Eliminar',
                                                            style: TextStyle(
                                                              color: isDarkMode
                                                                  ? Colors.red
                                                                      .shade300
                                                                  : Colors.red
                                                                      .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AnadirMedicamentoScreen(),
            ),
          );

          if (result == true) {
            _cargarMedicamentos();
          }
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        elevation: 4,
      ),
    );
  }
}

// Extensión para capitalizar la primera letra de un string
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
