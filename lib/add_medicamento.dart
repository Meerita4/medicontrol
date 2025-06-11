// filepath: c:\Users\Alejandro\Documents\DAM\2DAM\MediControl\lib\add_medicamento.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'notification_service_fixed.dart';
import 'utils/responsive_utils.dart';

// Clase para representar un horario de toma de medicamento
class HorarioMedicamento {
  final TextEditingController controller = TextEditingController();
  late TimeOfDay horario;

  HorarioMedicamento({TimeOfDay? hora}) {
    horario = hora ?? TimeOfDay.now();
    actualizarTexto();
  }

  void actualizarTexto() {
    controller.text =
        '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
  }

  void dispose() {
    controller.dispose();
  }

  String get horaFormateada => controller.text;
}

class AnadirMedicamentoScreen extends StatefulWidget {
  final String? nombrePrelleno;
  final String? dosisPrelleno;
  final Map<String, dynamic>?
      medicamentoExistente; // Añadir para editar un medicamento existente
  final bool esEdicion; // Indicador para saber si estamos editando o creando

  const AnadirMedicamentoScreen({
    Key? key,
    this.nombrePrelleno,
    this.dosisPrelleno,
    this.medicamentoExistente,
    this.esEdicion = false, // Por defecto, no es edición
  }) : super(key: key);

  @override
  State<AnadirMedicamentoScreen> createState() =>
      _AnadirMedicamentoScreenState();
}

class _AnadirMedicamentoScreenState extends State<AnadirMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _dosisController = TextEditingController();
  final _duracionController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  DateTime _fechaInicio = DateTime.now();
  bool _isLoading = false;

  // Lista para gestionar múltiples horarios
  List<HorarioMedicamento> _horarios = [];

  // Lista de días seleccionados (todos los días por defecto)
  List<int> _diasSeleccionados = [
    1,
    2,
    3,
    4,
    5,
    6,
    7
  ]; // Mantener por compatibilidad
  @override
  void initState() {
    super.initState();

    if (widget.esEdicion && widget.medicamentoExistente != null) {
      // Estamos en modo edición, cargar datos del medicamento
      final med = widget.medicamentoExistente!;

      // Cargar nombre y dosis
      _nombreController.text = med['nombre'] ?? '';
      _dosisController.text = med['dosis'] ?? '';

      // Cargar fecha de inicio y duración
      if (med['fecha_inicio'] != null) {
        _fechaInicioController.text = med['fecha_inicio'];
        _fechaInicio = DateTime.parse(med['fecha_inicio']);
      } else {
        _fechaInicioController.text =
            DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      _duracionController.text = med['duracion']?.toString() ?? '7';

      // Cargar días seleccionados
      if (med['dias'] != null && med['dias'] is List) {
        _diasSeleccionados = List<int>.from(med['dias']);
      }

      // Cargar horarios
      _horarios.clear();
      if (med['todos_horarios'] != null && med['todos_horarios'] is List) {
        List<dynamic> todosHorarios = med['todos_horarios'];
        for (String hora in todosHorarios) {
          try {
            final parts = hora.split(':');
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            _horarios
                .add(HorarioMedicamento(hora: TimeOfDay(hour: h, minute: m)));
          } catch (e) {
            print('Error al parsear hora: $hora - ${e.toString()}');
          }
        }
      }

      // Si no se cargó ningún horario, añadir uno por defecto
      if (_horarios.isEmpty) {
        _horarios.add(HorarioMedicamento(hora: TimeOfDay(hour: 8, minute: 0)));
      }
    } else {
      // Modo normal de añadir medicamento
      // Inicializar con un horario por defecto (mañana)
      _horarios.add(HorarioMedicamento(hora: TimeOfDay(hour: 8, minute: 0)));

      // Inicializar la fecha de inicio y duración
      _fechaInicioController.text =
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      _duracionController.text = '7'; // 7 días por defecto

      // Si hay valores prellenos, inicializar los controladores
      if (widget.nombrePrelleno != null) {
        _nombreController.text = widget.nombrePrelleno!;
      }
      if (widget.dosisPrelleno != null) {
        _dosisController.text = widget.dosisPrelleno!;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _dosisController.dispose();
    _duracionController.dispose();
    _fechaInicioController.dispose();

    // Limpiar los controladores de los horarios
    for (var horario in _horarios) {
      horario.dispose();
    }

    super.dispose();
  }

  // Función para mostrar el selector de hora para un horario específico
  Future<void> _seleccionarHora(HorarioMedicamento horario) async {
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: horario.horario,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (hora != null) {
      setState(() {
        horario.horario = hora;
        horario.actualizarTexto();
      });
    }
  }

  // Función para añadir un nuevo horario
  void _addHorario() {
    setState(() {
      _horarios.add(HorarioMedicamento());
    });
  }

  // Función para eliminar un horario
  void _removeHorario(int index) {
    if (_horarios.length > 1) {
      // Mantener al menos un horario
      setState(() {
        _horarios[index].dispose();
        _horarios.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe haber al menos un horario de toma'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Función para seleccionar la fecha de inicio
  Future<void> _seleccionarFechaInicio(BuildContext context) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime.now().subtract(
          const Duration(days: 30)), // Permitir fechas desde hace 30 días
      lastDate: DateTime.now()
          .add(const Duration(days: 365)), // Hasta un año adelante
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaInicio = fechaSeleccionada;
        _fechaInicioController.text =
            DateFormat('yyyy-MM-dd').format(fechaSeleccionada);
      });
    }
  }

  // Función mejorada para formatear hora en formato estricto HH:mm
  String _formatearHora(String hora) {
    if (hora.isEmpty) return '00:00';

    try {
      // Dividir la hora ingresada en horas y minutos
      final parts = hora.split(':');
      if (parts.length != 2) {
        // Si no tiene el formato esperado, crear una hora con valores predeterminados
        return '00:00';
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
      print("Error al formatear la hora: $e");
      return '00:00'; // Valor predeterminado en caso de error
    }
  }

  // Función para guardar el medicamento en la base de datos
  Future<void> _guardarMedicamento() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el usuario actual
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay sesión de usuario activa'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Verificar que hay al menos un horario
      if (_horarios.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe añadir al menos un horario de toma'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Crear la lista de horarios formateados
      final List<String> horariosFormateados = _horarios
          .map((horario) => _formatearHora(horario.controller.text))
          .toList();

      // La base de datos no tiene una columna 'metadatos', así que guardaremos
      // solo el primer horario en la columna "hora" existente
      final String primerHorario =
          horariosFormateados.isNotEmpty ? horariosFormateados[0] : "08:00";

      // Guardaremos la lista completa de horarios en memoria para programar notificaciones
      // pero solo el primer horario se almacenará en la base de datos

      // Depuración - verificar los horarios antes de guardar
      print("Horarios formateados antes de guardar: $horariosFormateados");
      print(
          "Primer horario (para columna hora): $primerHorario"); // Preparar los datos para insertar o actualizar
      final medicamentoData = {
        'nombre': _nombreController.text.trim(),
        'dosis': _dosisController.text.trim(),
        'hora': primerHorario, // Usar solo el primer horario en la columna hora
        // La columna 'horarios' no existe en la base de datos todavía
        // 'horarios': horariosFormateados,
        'usuario_id': user.id,
        'fecha_inicio': _fechaInicioController.text,
        'duracion': int.parse(_duracionController.text),
      };

      // Insertar o actualizar en la base de datos
      try {
        print("Intentando guardar medicamento con datos: $medicamentoData");
        // Forzar la actualización del esquema de la base de datos antes de insertarlo
        await Supabase.instance.client.from('medicamentos').select().limit(1);

        dynamic response;

        if (widget.esEdicion && widget.medicamentoExistente != null) {
          // Actualizar medicamento existente
          final medicamentoId = widget.medicamentoExistente!['id'];
          print("Actualizando medicamento ID: $medicamentoId");

          // Cancelar todas las notificaciones existentes para este medicamento
          await _cancelarNotificacionesMedicamento(medicamentoId);

          response = await Supabase.instance.client
              .from('medicamentos')
              .update(medicamentoData)
              .eq('id', medicamentoId)
              .select();
        } else {
          // Insertar nuevo medicamento
          response = await Supabase.instance.client
              .from('medicamentos')
              .insert(medicamentoData)
              .select();
        }
        print("Medicamento guardado exitosamente: $response");

        // Programar notificaciones para el medicamento creado o actualizado
        if (response.isNotEmpty) {
          final int medicamentoId = response[0]['id'] as int;
          final String nombreMedicamento = _nombreController.text.trim();
          final String dosis = _dosisController.text.trim();

          // Programar una notificación para cada horario
          for (int i = 0; i < horariosFormateados.length; i++) {
            await _programarNotificacion(
                medicamentoId * 100 + i, // ID único para cada notificación
                nombreMedicamento,
                dosis,
                horariosFormateados[i],
                _diasSeleccionados);
          }

          print(
              "${widget.esEdicion ? 'Actualizadas' : 'Programadas'} ${horariosFormateados.length} notificaciones para medicamento ID: $medicamentoId");
        }
        if (mounted) {
          // No necesitamos crear horariosTexto ya que usamos elementos individuales en el diálogo
          // Mostrar diálogo con los horarios configurados
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  widget.esEdicion
                      ? 'Medicamento actualizado correctamente'
                      : 'Medicamento añadido correctamente',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre: ${_nombreController.text.trim()}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Dosis: ${_dosisController.text.trim()}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Se han programado notificaciones para:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      ...horariosFormateados
                          .map((hora) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_active,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      hora,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
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
                    onPressed: () {
                      // Cerrar el diálogo y volver a la pantalla anterior
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(true);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                    child: const Text('ACEPTAR'),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            },
          );
          // También mostrar el SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Medicamento "${_nombreController.text.trim()}" añadido correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (dbError) {
        print("Error al guardar en la base de datos: $dbError");

        // Manejo de errores específicos
        if (dbError.toString().contains("does not exist")) {
          // La tabla no existe
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Error: La tabla medicamentos no existe en la base de datos'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (dbError.toString().contains("column") &&
            dbError.toString().contains("does not exist")) {
          // Algún campo no existe, intentar con los campos básicos
          try {
            // Crear un objeto simplificado con solo los campos esenciales
            // Usar solo el primer horario para compatibilidad
            final String primerHorario = _horarios.isNotEmpty
                ? _formatearHora(_horarios[0].controller.text)
                : "08:00";

            final medicamentoDataBasico = {
              'nombre': _nombreController.text.trim(),
              'dosis': _dosisController.text.trim(),
              'hora': primerHorario, // Usar solo el primer horario
              'usuario_id': user.id,
            };
            await Supabase.instance.client
                .from('medicamentos')
                .insert(medicamentoDataBasico);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Medicamento añadido con campos básicos. Algunos campos no pudieron guardarse.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al reintentar guardar: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Otro tipo de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar: ${dbError.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para programar notificación para un medicamento
  Future<void> _programarNotificacion(
    int medicamentoId,
    String nombreMedicamento,
    String dosis,
    String hora,
    List<int> dias, // Mantenido por compatibilidad pero ya no se usa
  ) async {
    try {
      // Obtener hora y minutos desde el string HH:mm
      final partes = hora.split(':');
      final int horaInt = int.parse(partes[0]);
      final int minutoInt = int.parse(partes[1]);

      // Construir la fecha para la notificación
      final DateTime ahora = DateTime.now();
      final DateTime horaProgramada =
          DateTime(ahora.year, ahora.month, ahora.day, horaInt, minutoInt);

      // Título y cuerpo de la notificación
      final String titulo = '🔔 Recordatorio: $nombreMedicamento';
      final String cuerpo = 'Es hora de tomar $dosis de $nombreMedicamento';

      // Programar notificaciones diarias a la hora especificada
      await _notificationService.scheduleRepeatingNotification(
        id: medicamentoId,
        title: titulo,
        body: cuerpo,
        scheduledTime: horaProgramada,
        diasSemana: [1, 2, 3, 4, 5, 6, 7], // Todos los días
        payload: 'medicamento_$medicamentoId',
      );
      print(
          'Notificaciones programadas para el medicamento $nombreMedicamento a las $hora');

      // Verificar que se hayan programado correctamente
      final hasNotifications =
          await _notificationService.checkNotificationsEnabled();
      print('Verificación: Hay notificaciones programadas: $hasNotifications');

      if (!hasNotifications && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Advertencia: Las notificaciones podrían no funcionar correctamente. Verifica los permisos de la aplicación.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error al programar notificaciones: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al programar notificaciones: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Método para cancelar notificaciones existentes de un medicamento
  Future<void> _cancelarNotificacionesMedicamento(int medicamentoId) async {
    try {
      // Cancelar todas las notificaciones en el rango del medicamento
      final int inicio = medicamentoId * 100;
      final int fin = inicio + 99; // Rango de IDs para este medicamento

      for (int i = inicio; i <= fin; i++) {
        await _notificationService.cancelNotification(i);
      }

      print('Notificaciones canceladas para medicamento ID: $medicamentoId');
    } catch (e) {
      print('Error al cancelar notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Añadir Medicamento',
          style: TextStyle(
            fontSize: ResponsiveUtils.getAdaptiveSize(context,
                mobile: 20, tablet: 22, desktop: 24),
          ),
        ),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveUtils.getAdaptiveSize(context,
                        mobile: double.infinity, tablet: 600, desktop: 800),
                  ),
                  child: SingleChildScrollView(
                    padding: ResponsiveUtils.getAdaptivePadding(
                      context,
                      mobile: const EdgeInsets.all(16.0),
                      tablet: const EdgeInsets.all(24.0),
                      desktop: const EdgeInsets.all(32.0),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado
                          Container(
                            margin: EdgeInsets.only(
                                bottom: ResponsiveUtils.getAdaptiveSize(context,
                                    mobile: 20, tablet: 30, desktop: 40)),
                            padding: ResponsiveUtils.getAdaptivePadding(
                              context,
                              mobile: const EdgeInsets.all(16),
                              tablet: const EdgeInsets.all(20),
                              desktop: const EdgeInsets.all(24),
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.blue.shade900.withOpacity(0.3)
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.blue.shade700
                                    : Colors.blue.shade100,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isDarkMode
                                      ? Colors.blue.shade700
                                      : Colors.blue.shade100,
                                  radius: ResponsiveUtils.getAdaptiveSize(
                                      context,
                                      mobile: 24,
                                      tablet: 28,
                                      desktop: 32),
                                  child: Icon(
                                    Icons.medication_outlined,
                                    color: isDarkMode
                                        ? Colors.blue.shade200
                                        : Colors.blue.shade800,
                                    size: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 28,
                                        tablet: 32,
                                        desktop: 36),
                                  ),
                                ),
                                SizedBox(
                                    width: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 12,
                                        tablet: 16,
                                        desktop: 20)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Información del medicamento',
                                        style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 16,
                                                  tablet: 18,
                                                  desktop: 20),
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.blue.shade200
                                              : Colors.blue.shade800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      SizedBox(
                                          height:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 4,
                                                  tablet: 6,
                                                  desktop: 8)),
                                      Text(
                                        'Completa los datos para programar tu medicamento',
                                        style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 12,
                                                  tablet: 14,
                                                  desktop: 15),
                                          color: isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Campo Nombre
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 20, tablet: 24, desktop: 28)),
                          _buildInputLabel(
                              'Nombre del medicamento', Icons.medical_services),
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 8, tablet: 10, desktop: 12)),
                          TextFormField(
                            controller: _nombreController,
                            decoration: InputDecoration(
                              hintText: 'Ej: Paracetamol, Ibuprofeno...',
                              prefixIcon: Icon(Icons.medication,
                                  color: Colors.blue.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.blue.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: isDarkMode
                                  ? Colors.blue.shade900.withOpacity(0.1)
                                  : Colors.blue.shade50.withOpacity(0.2),
                              contentPadding:
                                  ResponsiveUtils.getAdaptivePadding(
                                context,
                                mobile: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                tablet: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                desktop: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 24),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 16, tablet: 18, desktop: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, introduce el nombre del medicamento';
                              }
                              return null;
                            },
                          ),

                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 20, tablet: 24, desktop: 28)),

                          // Campo Dosis
                          _buildInputLabel('Dosis', Icons.local_hospital),
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 8, tablet: 10, desktop: 12)),
                          TextFormField(
                            controller: _dosisController,
                            decoration: InputDecoration(
                              hintText: 'Ej: 1 comprimido, 5ml, etc.',
                              prefixIcon: Icon(Icons.local_hospital,
                                  color: Colors.blue.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.blue.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.blue.shade50.withOpacity(0.2),
                              contentPadding:
                                  ResponsiveUtils.getAdaptivePadding(
                                context,
                                mobile: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                tablet: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                desktop: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 24),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 16, tablet: 18, desktop: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, introduce la dosis';
                              }
                              return null;
                            },
                          ),

                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 20, tablet: 24, desktop: 28)),

                          // Campo Horarios
                          _buildInputLabel(
                              'Horarios de toma', Icons.access_time),
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 8, tablet: 10, desktop: 12)),

                          // Lista de horarios
                          Column(
                            children: [
                              // Construir un campo para cada horario
                              ..._horarios.asMap().entries.map((entry) {
                                int index = entry.key;
                                HorarioMedicamento horario = entry.value;

                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom: ResponsiveUtils.getAdaptiveSize(
                                          context,
                                          mobile: 8,
                                          tablet: 10,
                                          desktop: 12)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: TextFormField(
                                          controller: horario.controller,
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            hintText: 'Hora',
                                            prefixIcon: Icon(Icons.access_time,
                                                color: Colors.blue.shade600,
                                                size: ResponsiveUtils
                                                    .getAdaptiveSize(context,
                                                        mobile: 20,
                                                        tablet: 22,
                                                        desktop: 24)),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade200),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                  color: Colors.blue.shade400,
                                                  width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.blue.shade50
                                                .withOpacity(0.2),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: ResponsiveUtils
                                                        .getAdaptiveSize(
                                                            context,
                                                            mobile: 12,
                                                            tablet: 14,
                                                            desktop: 16),
                                                    horizontal: ResponsiveUtils
                                                        .getAdaptiveSize(
                                                            context,
                                                            mobile: 12,
                                                            tablet: 14,
                                                            desktop: 16)),
                                            isDense: true,
                                          ),
                                          style: TextStyle(
                                              fontSize: ResponsiveUtils
                                                  .getAdaptiveSize(context,
                                                      mobile: 16,
                                                      tablet: 18,
                                                      desktop: 20)),
                                          onTap: () =>
                                              _seleccionarHora(horario),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Selecciona una hora';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 8,
                                                  tablet: 12,
                                                  desktop: 16)),
                                      // Botón para eliminar horario
                                      Container(
                                        width: ResponsiveUtils.getAdaptiveSize(
                                            context,
                                            mobile: 40,
                                            tablet: 48,
                                            desktop: 56),
                                        height: ResponsiveUtils.getAdaptiveSize(
                                            context,
                                            mobile: 40,
                                            tablet: 48,
                                            desktop: 56),
                                        child: IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Colors.red.shade400,
                                              size: ResponsiveUtils
                                                  .getAdaptiveSize(context,
                                                      mobile: 20,
                                                      tablet: 24,
                                                      desktop: 28)),
                                          onPressed: _horarios.length > 1
                                              ? () => _removeHorario(index)
                                              : null,
                                          tooltip: 'Eliminar',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                              // Botón para añadir nuevo horario
                              Padding(
                                padding: EdgeInsets.only(
                                    top: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 8,
                                        tablet: 12,
                                        desktop: 16)),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: Icon(Icons.add_alarm,
                                        size: ResponsiveUtils.getAdaptiveSize(
                                            context,
                                            mobile: 18,
                                            tablet: 20,
                                            desktop: 22)),
                                    label: Text('Añadir horario',
                                        style: TextStyle(
                                            fontSize:
                                                ResponsiveUtils.getAdaptiveSize(
                                                    context,
                                                    mobile: 14,
                                                    tablet: 16,
                                                    desktop: 18))),
                                    onPressed: _addHorario,
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                          vertical:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 12,
                                                  tablet: 14,
                                                  desktop: 16),
                                          horizontal:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 16,
                                                  tablet: 20,
                                                  desktop: 24)),
                                      side: BorderSide(
                                          color: Colors.blue.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 20, tablet: 24, desktop: 28)),

                          // Campo Fecha de Inicio
                          _buildInputLabel(
                              'Fecha de inicio', Icons.calendar_today),
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 8, tablet: 10, desktop: 12)),
                          TextFormField(
                            controller: _fechaInicioController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Selecciona la fecha de inicio',
                              prefixIcon: Icon(Icons.calendar_today,
                                  color: Colors.blue.shade600),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.edit_calendar,
                                    color: Colors.blue.shade600),
                                onPressed: () =>
                                    _seleccionarFechaInicio(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.blue.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.blue.shade50.withOpacity(0.2),
                              contentPadding:
                                  ResponsiveUtils.getAdaptivePadding(
                                context,
                                mobile: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                tablet: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                desktop: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 24),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 16, tablet: 18, desktop: 20),
                            ),
                            onTap: () => _seleccionarFechaInicio(context),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, selecciona la fecha de inicio';
                              }
                              return null;
                            },
                          ),

                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 20, tablet: 24, desktop: 28)),

                          // Campo Duración del tratamiento
                          _buildInputLabel('Duración (días)', Icons.date_range),
                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 8, tablet: 10, desktop: 12)),
                          TextFormField(
                            controller: _duracionController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ej: 7, 14, 30...',
                              prefixIcon: Icon(Icons.date_range,
                                  color: Colors.blue.shade600),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.blue.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.blue.shade50.withOpacity(0.2),
                              contentPadding:
                                  ResponsiveUtils.getAdaptivePadding(
                                context,
                                mobile: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                tablet: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                desktop: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 24),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 16, tablet: 18, desktop: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, introduce la duración';
                              }
                              if (int.tryParse(value) == null ||
                                  int.parse(value) <= 0) {
                                return 'Introduce un número válido de días';
                              }
                              return null;
                            },
                          ), // Ya no se usan días de la semana, solo la duración del tratamiento

                          SizedBox(
                              height: ResponsiveUtils.getAdaptiveSize(context,
                                  mobile: 24, tablet: 32, desktop: 40)),

                          // Botones
                          Column(
                            children: [
                              // Botón guardar
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _guardarMedicamento,
                                  icon: Icon(Icons.save,
                                      size: ResponsiveUtils.getAdaptiveSize(
                                          context,
                                          mobile: 18,
                                          tablet: 20,
                                          desktop: 22)),
                                  label: Text('GUARDAR MEDICAMENTO',
                                      style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18),
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            ResponsiveUtils.getAdaptiveSize(
                                                context,
                                                mobile: 16,
                                                tablet: 18,
                                                desktop: 20)),
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  height: ResponsiveUtils.getAdaptiveSize(
                                      context,
                                      mobile: 12,
                                      tablet: 16,
                                      desktop: 20)),
                              // Botón cancelar
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(Icons.close,
                                      size: ResponsiveUtils.getAdaptiveSize(
                                          context,
                                          mobile: 18,
                                          tablet: 20,
                                          desktop: 22)),
                                  label: Text('CANCELAR',
                                      style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18),
                                          fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            ResponsiveUtils.getAdaptiveSize(
                                                context,
                                                mobile: 16,
                                                tablet: 18,
                                                desktop: 20)),
                                    foregroundColor: Colors.grey.shade700,
                                    side:
                                        BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Widget para crear etiquetas de entrada con iconos
  Widget _buildInputLabel(String label, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: ResponsiveUtils.getAdaptivePadding(
        context,
        mobile: const EdgeInsets.only(left: 4, bottom: 4),
        tablet: const EdgeInsets.only(left: 6, bottom: 6),
        desktop: const EdgeInsets.only(left: 8, bottom: 8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: ResponsiveUtils.getAdaptiveSize(context,
                mobile: 18, tablet: 20, desktop: 22),
            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
          ),
          SizedBox(
              width: ResponsiveUtils.getAdaptiveSize(context,
                  mobile: 8, tablet: 10, desktop: 12)),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                  mobile: 15, tablet: 17, desktop: 19),
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
