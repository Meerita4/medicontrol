import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importar para inicializar locale
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'utils/responsive_utils.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({Key? key}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final supabase = Supabase.instance.client;
  DateTime fechaSeleccionada = DateTime.now();
  List<dynamic> historial = [];
  List<dynamic> todosLosMedicamentos =
      []; // Para almacenar todos los medicamentos
  bool _localeInitialized = false;
  bool _isLoading = true;
  bool _mostrarTodosMedicamentos =
      false; // Para controlar si mostrar todos los medicamentos

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  // Inicializar los datos de localización
  Future<void> _initializeLocale() async {
    await initializeDateFormatting('es_ES', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
      _cargarHistorial(); // Cargar historial después de inicializar locale
    }
  }

  // Método para cargar historial por fecha
  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final fechaStr = DateFormat('yyyy-MM-dd').format(fechaSeleccionada);

      final response = await supabase
          .from('historial')
          .select('*, medicamentos(nombre, dosis)')
          .eq('usuario_id', userId)
          .eq('fecha', fechaStr)
          .order('hora_toma', ascending: true);

      setState(() {
        historial = response;
        _isLoading = false;
      });

      // También cargamos todos los medicamentos para tenerlos disponibles
      await _cargarTodosMedicamentos();
    } catch (e) {
      print("Error al cargar historial: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para cargar todos los medicamentos del historial
  Future<void> _cargarTodosMedicamentos() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Podemos usar diferentes filtros dependiendo del período que queramos mostrar
      final response = await supabase
          .from('historial')
          .select('*, medicamentos(nombre, dosis)')
          .eq('usuario_id', userId)
          .order('fecha',
              ascending:
                  false) // Ordenar por fecha descendente (más reciente primero)
          .order('hora_toma', ascending: true);

      setState(() {
        todosLosMedicamentos = response;
      });
    } catch (e) {
      print("Error al cargar todos los medicamentos: $e");
    }
  }

  void _seleccionarFecha() async {
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (nuevaFecha != null) {
      setState(() => fechaSeleccionada = nuevaFecha);
      await _cargarHistorial();
    }
  }

  // Método para exportar historial a PDF
  Future<void> _exportarPDF() async {
    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando PDF...'),
            ],
          ),
        );
      },
    );

    try {
      // Crear un documento PDF
      final pdf = pw.Document(); // Obtener la fecha actual formateada
      final fechaGeneracion =
          DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(DateTime.now());
      final fechaArchivo =
          DateFormat('yyyyMMdd_HHmmss', 'es_ES').format(DateTime.now());

      // Obtener el nombre del paciente y manejar cualquier error
      String nombrePaciente;
      try {
        nombrePaciente = await _obtenerNombrePaciente() ?? "Paciente";
        print("Nombre del paciente obtenido: $nombrePaciente");
      } catch (e) {
        print("Error al obtener el nombre del paciente: $e");
        nombrePaciente = "Paciente";
      }

      // Determinar qué datos exportar
      final datosExportar =
          _mostrarTodosMedicamentos ? todosLosMedicamentos : historial;
      final tituloPDF = _mostrarTodosMedicamentos
          ? "Historial completo de medicamentos"
          : "Historial del día ${DateFormat('dd/MM/yyyy', 'es_ES').format(fechaSeleccionada)}";

      final nombreArchivo = _mostrarTodosMedicamentos
          ? "MediControl_HistorialCompleto_$fechaArchivo.pdf"
          : "MediControl_Historial_${DateFormat('yyyyMMdd', 'es_ES').format(fechaSeleccionada)}.pdf";

      // Añadir página al PDF
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'MediControl - Informe de medicamentos',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),

                // Información del paciente y del informe
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Paciente: $nombrePaciente',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 5),
                      pw.Text('Fecha de generación: $fechaGeneracion',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 5),
                      pw.Text('Informe: $tituloPDF',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Tabla de medicamentos
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Encabezados de la tabla
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildHeaderCell('Fecha'),
                        _buildHeaderCell('Hora'),
                        _buildHeaderCell('Medicamento'),
                        _buildHeaderCell('Dosis'),
                        _buildHeaderCell('Estado'),
                      ],
                    ),

                    // Datos de la tabla
                    ...datosExportar.map((item) {
                      final med = item['medicamentos'];
                      final nombre =
                          med != null ? med['nombre'] ?? 'N/A' : 'N/A';
                      final dosis = med != null ? med['dosis'] ?? 'N/A' : 'N/A';
                      final fecha = item['fecha'] ?? 'N/A';
                      final hora = item['hora_toma'] ?? 'N/A';
                      final tomado = item['tomado'] == true;

                      return pw.TableRow(
                        children: [
                          _buildContentCell(fecha),
                          _buildContentCell(hora),
                          _buildContentCell(nombre),
                          _buildContentCell(dosis),
                          _buildContentCell(tomado ? 'Tomado' : 'No tomado',
                              color: tomado
                                  ? PdfColors.green700
                                  : PdfColors.red700),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Pie de página
                pw.Footer(
                  title: pw.Text(
                    'MediControl - Exportado el $fechaGeneracion',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Cerrar el diálogo de progreso
      Navigator.of(context).pop(); // Guardar el PDF en el dispositivo
      final pdfBytes = await pdf.save();

      // Obtener el directorio adecuado según la plataforma
      final Directory appDocDir;
      if (Platform.isAndroid) {
        // Para Android, intentamos usar el directorio de almacenamiento externo
        final directory = await getApplicationDocumentsDirectory();
        appDocDir = directory;
      } else {
        // Para iOS y otras plataformas, usamos el directorio de documentos
        appDocDir = await getApplicationDocumentsDirectory();
      }

      final downloadsDir = Directory('${appDocDir.path}/MediControl');

      // Crear directorio si no existe
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/$nombreArchivo');
      await file.writeAsBytes(pdfBytes);

      // Mostrar diálogo de éxito con opciones para ver o compartir
      await _mostrarDialogoExito(file);
    } catch (e) {
      // Cerrar el diálogo de progreso en caso de error
      Navigator.of(context).pop();

      print('Error al generar PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar el PDF: ${e.toString()}')),
      );
    }
  }

  // Método auxiliar para crear celdas de encabezado en la tabla PDF
  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Método auxiliar para crear celdas de contenido en la tabla PDF
  pw.Widget _buildContentCell(String text, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: color != null ? pw.TextStyle(color: color) : null,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Método para obtener el nombre del paciente desde la base de datos
  Future<String?> _obtenerNombrePaciente() async {
    try {
      final userId = supabase.auth.currentUser!
          .id; // Primero verificamos si existe el usuario en perfiles
      final perfilesResponse =
          await supabase.from('perfiles').select('nombre').eq('id', userId);

      if (perfilesResponse.isNotEmpty) {
        // Si encontramos el perfil, devolvemos el nombre
        print("Perfil encontrado: ${perfilesResponse[0]['nombre']}");
        return perfilesResponse[0]['nombre'];
      } else {
        // Si no existe en perfiles, buscamos en la tabla de usuarios
        final userResponse = await supabase.auth.getUser();
        final email = userResponse.user?.email;
        print("Usando email como nombre: $email");
        return email ?? "Paciente";
      }
    } catch (e) {
      print('Error al obtener nombre del paciente: $e');
      // En caso de error, devolvemos el email o un valor por defecto
      try {
        final userResponse = await supabase.auth.getUser();
        return userResponse.user?.email ?? "Paciente";
      } catch (_) {
        return "Paciente";
      }
    }
  }

  // Método para mostrar diálogo de éxito después de guardar PDF
  Future<void> _mostrarDialogoExito(File file) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF guardado con éxito'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('El archivo se ha guardado en:\n${file.path}'),
                const SizedBox(height: 10),
                const Text('¿Qué deseas hacer con el archivo?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abrir'),
              onPressed: () {
                Navigator.of(context).pop();
                _abrirArchivoPDF(file);
              },
            ),
            TextButton(
              child: const Text('Compartir'),
              onPressed: () {
                Navigator.of(context).pop();
                Share.shareXFiles([XFile(file.path)],
                    subject: 'Historial de MediControl');
              },
            ),
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Método para abrir el archivo PDF
  Future<void> _abrirArchivoPDF(File file) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => file.readAsBytesSync(),
        name: file.path.split('/').last,
      );
    } catch (e) {
      print('Error al abrir el PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el PDF: ${e.toString()}')),
      );
    }
  }

  // Método para cambiar entre mostrar historial por fecha o todos los medicamentos
  void _toggleMostrarTodos() {
    setState(() {
      _mostrarTodosMedicamentos = !_mostrarTodosMedicamentos;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si la localización no está inicializada, mostrar indicador de carga
    if (!_localeInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Historial",
            style: TextStyle(
              fontSize: ResponsiveUtils.getAdaptiveSize(context,
                  mobile: 20, tablet: 22, desktop: 24),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fechaTexto =
        DateFormat('dd MMMM yyyy', 'es_ES').format(fechaSeleccionada);

    // Determinar si estamos en modo oscuro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Historial",
          style: TextStyle(
            fontSize: ResponsiveUtils.getAdaptiveSize(context,
                mobile: 20, tablet: 22, desktop: 24),
          ),
        ),
        elevation: 4,
        backgroundColor: isDarkMode
            ? Color.fromARGB(255, 30, 30, 40)
            : primaryColor.withOpacity(0.8),
        actions: [
          // Botón para alternar entre vista por fecha y todos los medicamentos
          IconButton(
            icon: Icon(_mostrarTodosMedicamentos
                ? Icons.calendar_today
                : Icons.list_alt),
            tooltip: _mostrarTodosMedicamentos
                ? 'Mostrar por fecha'
                : 'Mostrar todos',
            onPressed: _toggleMostrarTodos,
          ),
          // Botón para exportar a PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar a PDF',
            onPressed: _exportarPDF,
          ),
          // Botón para seleccionar fecha (solo visible en modo fecha)
          if (!_mostrarTodosMedicamentos)
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Seleccionar fecha',
              onPressed: _seleccionarFecha,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar información de vista (fecha o todos los medicamentos)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                      _mostrarTodosMedicamentos
                          ? Icons.list_alt
                          : Icons.calendar_month,
                      color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    _mostrarTodosMedicamentos
                        ? "Mostrando todos los medicamentos"
                        : "Fecha: $fechaTexto",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const Spacer(),
                  if (!_mostrarTodosMedicamentos)
                    InkWell(
                      onTap: _seleccionarFecha,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Text("Cambiar",
                                style: TextStyle(color: Colors.blue.shade700)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Lista de historial
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _mostrarListaMedicamentos(),
            ),
          ],
        ),
      ),
      // Botón flotante para exportar a PDF
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportarPDF,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Exportar a PDF'),
        backgroundColor: primaryColor,
      ),
    );
  }

  // Widget para mostrar la lista de medicamentos según el modo actual
  Widget _mostrarListaMedicamentos() {
    final listaActual =
        _mostrarTodosMedicamentos ? todosLosMedicamentos : historial;

    if (listaActual.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _mostrarTodosMedicamentos
                  ? "No hay registros de medicamentos"
                  : "No hay registros para esta fecha",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: listaActual.length,
      itemBuilder: (context, index) {
        final item = listaActual[index];
        final medicamentos = item['medicamentos'];
        final nombre =
            medicamentos != null ? medicamentos['nombre'] ?? 'N/A' : 'N/A';
        final dosis =
            medicamentos != null ? medicamentos['dosis'] ?? 'N/A' : 'N/A';
        final fecha = item['fecha'] ?? 'N/A';
        final hora = item['hora_toma'] ?? '--:--';
        final tomado = item['tomado'] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor:
                  tomado ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                tomado ? Icons.check_circle : Icons.cancel,
                color: tomado ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              nombre,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Dosis: $dosis'),
                // Mostrar fecha solo en modo "todos los medicamentos"
                if (_mostrarTodosMedicamentos)
                  Text(
                    'Fecha: $fecha',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  'Hora: $hora',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: tomado ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tomado ? 'Tomado' : 'No tomado',
                style: TextStyle(
                  color: tomado ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
