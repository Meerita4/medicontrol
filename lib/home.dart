import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/main.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true; // Variables para el resumen de medicamentos
  int _medicamentosHoy = 0;
  int _medicamentosTomados = 0;
  int _medicamentosPendientes = 0;
  Map<String, dynamic>? _proximoMedicamento;

  @override
  void initState() {
    super.initState();
    // Inicializar los datos de localización para español antes de cargar el perfil
    initializeDateFormatting('es_ES', null).then((_) {
      _loadUserProfile();
      _cargarResumenMedicamentos();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Verificar si el usuario está autenticado
      final User? currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        // Si no hay usuario autenticado, redirigir al login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para cargar el resumen de medicamentos del usuario actual
  Future<void> _cargarResumenMedicamentos() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return;
      } // 1. Obtener la fecha de hoy para filtrar medicamentos
      final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 2. Cargar medicamentos del usuario actual
      final medicamentos = await supabase
          .from('medicamentos')
          .select('*, id')
          .eq('usuario_id', userId)
          .order('hora', ascending: true);

      // 3. Filtrar medicamentos para el día actual (sólo basado en la duración)
      final medicamentosHoy = medicamentos.where((med) {
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

        // El medicamento debe estar programado para hoy Y dentro del periodo de tratamiento
        return estaEnPeriodoTratamiento;
      }).toList();

      // 5. Cargar historial de hoy para saber qué medicamentos ya se tomaron
      final historialHoy = await supabase
          .from('historial')
          .select('medicamento_id, tomado')
          .eq('usuario_id', userId)
          .eq('fecha', fechaHoy)
          .eq('tomado', true);

      // 6. Marcar los medicamentos como tomados según el historial
      final medicamentosTomadosIds =
          historialHoy.map((item) => item['medicamento_id'].toString()).toSet();

      final medicamentosConEstado = medicamentosHoy.map((med) {
        final medicamentoId = med['id'].toString();
        final tomado = medicamentosTomadosIds.contains(medicamentoId);
        med['tomado_local'] = tomado;
        return med;
      }).toList();

      // 7. Calcular estadísticas
      final medicamentosTomadosHoy = medicamentosConEstado
          .where((med) => med['tomado_local'] == true)
          .toList();

      final medicamentosPendientesHoy = medicamentosConEstado
          .where((med) => med['tomado_local'] != true)
          .toList();

      // 8. Identificar el próximo medicamento a tomar
      Map<String, dynamic>? proximoMedicamento;
      if (medicamentosPendientesHoy.isNotEmpty) {
        // Obtener la hora actual
        final ahora = DateTime.now();
        final horaActual = DateFormat('HH:mm').format(ahora);

        // Ordenar por hora para encontrar el próximo
        medicamentosPendientesHoy.sort((a, b) {
          final horaA = a['hora'] as String;
          final horaB = b['hora'] as String;

          // Si la hora ya pasó, ponla al final
          final horaAPasada = horaA.compareTo(horaActual) < 0;
          final horaBPasada = horaB.compareTo(horaActual) < 0;

          if (horaAPasada && !horaBPasada) {
            return 1; // A ya pasó, B es próxima
          } else if (!horaAPasada && horaBPasada) {
            return -1; // B ya pasó, A es próxima
          } else {
            // Ambas pasaron o ambas son futuras, ordena por hora
            return horaA.compareTo(horaB);
          }
        });

        // El primer medicamento en la lista ordenada es el próximo a tomar
        proximoMedicamento = medicamentosPendientesHoy.first;
      }

      // 9. Actualizar el estado
      if (mounted) {
        setState(() {
          _medicamentosHoy = medicamentosConEstado.length;
          _medicamentosTomados = medicamentosTomadosHoy.length;
          _medicamentosPendientes = medicamentosPendientesHoy.length;
          _proximoMedicamento = proximoMedicamento;
          _isLoading = false;
        });
      }
    } catch (error) {
      print("Error al cargar resumen de medicamentos: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en modo oscuro para adaptar los colores
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Determinar tamaño de pantalla para diseño adaptativo
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Obtener el nombre del usuario para mostrarlo en el saludo
    final nombreUsuario =
        Supabase.instance.client.auth.currentUser?.email ?? 'Usuario';
    final firstName = nombreUsuario.split('@').first;

    return Scaffold(
      body: Container(
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _cargarResumenMedicamentos();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado con saludo y perfil
                        _buildHeader(
                            firstName, isTablet, isDarkMode, primaryColor),

                        const SizedBox(height: 24),

                        // Tarjeta principal con el resumen de medicamentos
                        _buildMedicationSummaryCard(
                            isTablet, isDarkMode, primaryColor),

                        const SizedBox(height: 30),

                        // Título de secciones
                        Text(
                          'Accesos rápidos',
                          style: TextStyle(
                            fontSize: isTablet ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Grid de accesos rápidos
                        Expanded(
                          child: _buildQuickAccessGrid(
                              isTablet, isDarkMode, primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ), // Botón flotante para acceder al asistente virtual
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/assistant'),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('Asistente IA'),
        elevation: 8,
      ),
    );
  }

  // Widget para el encabezado con saludo y avatar
  Widget _buildHeader(
      String firstName, bool isTablet, bool isDarkMode, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Saludo con nombre de usuario
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${_capitalizeFirstLetter(firstName)}',
                style: TextStyle(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _capitalizeFirstLetter(
                    DateFormat('EEEE, d MMMM', 'es_ES').format(DateTime.now())),
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ],
          ),

          // Avatar del usuario
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/perfil');
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.7),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                radius: isTablet ? 28 : 24,
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : "U",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para la tarjeta principal con resumen de medicamentos
  Widget _buildMedicationSummaryCard(
      bool isTablet, bool isDarkMode, Color primaryColor) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(isDarkMode ? 0.7 : 0.8),
              primaryColor.withOpacity(isDarkMode ? 0.5 : 0.6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de medicamentos',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Información de tus tratamientos',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMedicationStat(
                  icon: Icons.medication,
                  title: 'Para hoy',
                  value: _medicamentosHoy.toString(),
                  color: Colors.white,
                  isTablet: isTablet,
                ),
                _buildMedicationStat(
                  icon: Icons.check_circle,
                  title: 'Tomados',
                  value: _medicamentosTomados.toString(),
                  color: Colors.white,
                  isTablet: isTablet,
                ),
                _buildMedicationStat(
                  icon: Icons.pending_actions,
                  title: 'Pendientes',
                  value: _medicamentosPendientes.toString(),
                  color: Colors.white,
                  isTablet: isTablet,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProximoMedicamento(isTablet),
          ],
        ),
      ),
    );
  }

  // Widget para mostrar el próximo medicamento
  Widget _buildProximoMedicamento(bool isTablet) {
    if (_proximoMedicamento != null) {
      return GestureDetector(
        onTap: () {
          // Navegar a medicamentos al tocar
          Navigator.of(context).pushNamed('/medicamentos');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(text: 'Próximo: '),
                      TextSpan(
                        text:
                            '${_proximoMedicamento!['nombre']} a las ${_proximoMedicamento!['hora']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white.withOpacity(0.9),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'No hay medicamentos pendientes hoy',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Widget para una estadística individual en el resumen
  Widget _buildMedicationStat({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isTablet,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: isTablet ? 28 : 24),
        ),
        SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
  // Widget para el grid de accesos rápidos
  Widget _buildQuickAccessGrid(
      bool isTablet, bool isDarkMode, Color primaryColor) {
    // Lista de accesos rápidos
    final List<Map<String, dynamic>> shortcuts = [
      {
        'title': 'Mis medicamentos',
        'icon': Icons.medication,
        'color': Colors.blue,
        'route': '/medicamentos',
      },
      {
        'title': 'Añadir medicamento',
        'icon': Icons.add_circle_outline,
        'color': Colors.green,
        'route': '/add_medicamento',
      },
      {
        'title': 'Escanear receta',
        'icon': Icons.document_scanner,
        'color': Colors.red,
        'route': '/scan_prescriptions',
      },
      {
        'title': 'Historial',
        'icon': Icons.history,
        'color': Colors.purple,
        'route': '/historial',
      },
      {
        'title': 'Mi perfil',
        'icon': Icons.person,
        'color': Colors.orange,
        'route': '/perfil',
      },
    ];

    // Determinar el número de columnas según el ancho de pantalla
    final crossAxisCount = isTablet ? 3 : 2;

    return GridView.builder(
      padding: EdgeInsets.only(bottom: 20),
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: shortcuts.length,
      itemBuilder: (context, index) {
        final shortcut = shortcuts[index];
        final Color itemColor = shortcut['color'];

        return InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(shortcut['route']).then((_) {
              // Actualizar el resumen de medicamentos cuando regrese a la página de inicio
              _cargarResumenMedicamentos();
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Card(
            elevation: 4,
            shadowColor: itemColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDarkMode
                        ? itemColor.withOpacity(0.1)
                        : itemColor.withOpacity(0.05),
                    isDarkMode
                        ? itemColor.withOpacity(0.05)
                        : itemColor.withOpacity(0.02),
                  ],
                ),
                border: Border.all(
                  color: itemColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      shortcut['icon'],
                      color: itemColor,
                      size: isTablet ? 32 : 28,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    shortcut['title'],
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Método para capitalizar la primera letra de una cadena
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
  // Fin de la clase
}
