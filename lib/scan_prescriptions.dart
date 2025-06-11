import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/add_medicamento.dart';
import 'utils/responsive_utils.dart';

class ScanPrescriptionsScreen extends StatefulWidget {
  const ScanPrescriptionsScreen({Key? key}) : super(key: key);

  @override
  State<ScanPrescriptionsScreen> createState() =>
      _ScanPrescriptionsScreenState();
}

class _ScanPrescriptionsScreenState extends State<ScanPrescriptionsScreen> {
  bool _isLoading = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _recognizedText = '';
  List<RecognizedMedication> _recognizedMedications = [];
  bool _isScanningComplete = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // Seleccionar imagen de la galería
  Future<void> _getImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    _processImage(image);
  }

  // Tomar foto con la cámara
  Future<void> _getImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    _processImage(image);
  }

  // Procesar la imagen seleccionada
  Future<void> _processImage(XFile? image) async {
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _imageFile = File(image.path);
      _recognizedText = '';
      _isScanningComplete = false;
      _recognizedMedications = [];
    });

    try {
      final InputImage inputImage = InputImage.fromFile(_imageFile!);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      setState(() {
        _recognizedText = recognizedText.text;
        _extractMedications(recognizedText.text);
        _isLoading = false;
        _isScanningComplete = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _recognizedText = 'Error al procesar la imagen: \$e';
      });
    }
  }

  // Extraer posibles medicamentos del texto
  void _extractMedications(String text) {
    // Dividir el texto por líneas
    List<String> lines = text.split('\n');

    // Lista para almacenar los posibles medicamentos
    List<RecognizedMedication> medications = [];

    // Palabras clave que podrían indicar nombres de medicamentos
    List<String> medicationKeywords = [
      'mg',
      'ml',
      'comprimido',
      'cápsula',
      'jarabe',
      'tableta',
      'ampolla',
      'pastilla',
      'cápsulas',
      'comprimidos',
      'gotas',
      'solución',
      'inyectable',
      'parche',
      'pomada',
      'crema',
      'gel',
      'supositorio',
      'suspensión',
      'polvo',
      'sobre',
      'vial',
      'inhalador',
      'spray',
      'ungüento'
    ];

    // Palabras clave para nombres comerciales comunes de medicamentos en España
    List<String> commonMedications = [
      'paracetamol',
      'ibuprofeno',
      'omeprazol',
      'amoxicilina',
      'enalapril',
      'atorvastatina',
      'simvastatina',
      'lorazepam',
      'diazepam',
      'metamizol',
      'aspirina',
      'adiro',
      'nolotil',
      'dalsy',
      'frenadol',
      'gelocatil',
      'enantyum',
      'sintrom',
      'levotiroxina',
      'ventolin',
      'salbutamol',
      'lexatin',
      'orfidal',
      'tramadol',
      'dexketoprofeno',
      'metformina',
      'losartan',
      'amlodipino',
      'dexametasona',
      'prednisona',
      'hidroclorotiazida'
    ];

    // Patrones para dosis comunes (mg, ml, etc.)
    RegExp dosePattern =
        RegExp(r'\b\d+(\.\d+)?\s*(mg|ml|g|mcg|µg|UI)\b', caseSensitive: false);

    // Patrón para posología común
    RegExp posologyPattern = RegExp(
        r'\b\d+(\s*(comprimido|cápsula|pastilla|gota|ml|mg))?(\s*cada\s*\d+\s*(hora|día|semana|mes))|\b\d+\s*veces\s*(al\s*día|por\s*semana|al\s*mes)',
        caseSensitive: false);

    // Procesar cada línea
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty || line.length < 3) continue;
      // Si la línea contiene alguna de las palabras clave o patrón de dosis
      bool containsKeyword = medicationKeywords
          .any((keyword) => line.toLowerCase().contains(keyword.toLowerCase()));
      bool containsDose = dosePattern.hasMatch(line);
      bool containsPosology = posologyPattern.hasMatch(line);
      bool containsCommonMed = commonMedications
          .any((med) => line.toLowerCase().contains(med.toLowerCase()));

      if (containsKeyword ||
          containsDose ||
          containsPosology ||
          containsCommonMed) {
        // Intentar encontrar una dosis en la línea
        String dosis = 'No especificada';
        Match? doseMatch = dosePattern.firstMatch(line);
        Match? posologyMatch = posologyPattern.firstMatch(line);

        if (doseMatch != null) {
          dosis = doseMatch.group(0) ?? dosis;
          // Buscar si hay información de posología
          if (posologyMatch != null) {
            String posologyText = posologyMatch.group(0) ?? '';
            if (posologyText.isNotEmpty) {
              dosis = '$dosis $posologyText';
            }
          }
        } else if (posologyMatch != null) {
          String posologyText = posologyMatch.group(0) ?? '';
          if (posologyText.isNotEmpty) {
            dosis = posologyText;
          }
        }

        // Identificar el posible nombre de medicamento
        String possibleName = line;

        // Si hay una dosis, intenta separar el nombre del medicamento de la dosis
        if (doseMatch != null && doseMatch.group(0) != null) {
          // Eliminar la dosis de la línea para quedarnos con el nombre
          possibleName = line.replaceAll(doseMatch.group(0)!, '').trim();
        }

        // Si hay posología pero no es parte de la dosis ya capturada, eliminarla también
        if (posologyMatch != null && posologyMatch.group(0) != null) {
          String posologyText = posologyMatch.group(0)!;
          if (!dosis.contains(posologyText)) {
            possibleName = possibleName.replaceAll(posologyText, '').trim();
          }
        }
        // Limpiar el nombre de posibles caracteres no deseados al inicio o final
        possibleName = possibleName.replaceAll(
            RegExp(r'^[^a-zA-Z0-9áéíóúÁÉÍÓÚüÜñÑ]+'), '');
        possibleName = possibleName.replaceAll(
            RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚüÜñÑ]+$'), '');

        // Asegurarse de que el nombre no sea demasiado largo (posiblemente un párrafo)
        List<String> possibleNameWords = possibleName.split(' ');
        if (possibleNameWords.length > 10) {
          // Es probablemente un párrafo, intentar extraer algo que parezca un nombre de medicamento
          bool foundCommonMed = false;
          for (String commonMed in commonMedications) {
            if (possibleName.toLowerCase().contains(commonMed.toLowerCase())) {
              // Extraer el contexto cercano al medicamento común encontrado
              int index =
                  possibleName.toLowerCase().indexOf(commonMed.toLowerCase());
              int startIndex = index > 15 ? index - 15 : 0;
              int endIndex = index + commonMed.length + 15;
              if (endIndex > possibleName.length) {
                endIndex = possibleName.length;
              }
              possibleName =
                  possibleName.substring(startIndex, endIndex).trim();
              foundCommonMed = true;
              break;
            }
          }

          // Si no se encontró un medicamento común, usar solo las primeras palabras
          if (!foundCommonMed && possibleNameWords.length > 5) {
            possibleName = possibleNameWords.sublist(0, 5).join(' ');
          }
        }

        // Verificar que el nombre tenga una longitud razonable
        if (possibleName.isNotEmpty &&
            possibleName.length > 3 &&
            possibleName.length < 100) {
          // Crear un nuevo medicamento reconocido
          medications.add(
            RecognizedMedication(
              nombre: possibleName,
              dosis: dosis,
              rawText: line,
            ),
          );
        }
      }
    } // Eliminar posibles duplicados basados en nombres similares
    List<RecognizedMedication> uniqueMedications = [];

    // Ordenar medicamentos por longitud del nombre (primero los más cortos)
    // para favorecer nombres de medicamentos más concisos
    medications.sort((a, b) => a.nombre.length.compareTo(b.nombre.length));

    for (var med in medications) {
      if (med.nombre.isEmpty) continue; // Ignorar nombres vacíos

      bool isDuplicate = false;
      for (var uniqueMed in uniqueMedications) {
        if (_areSimilarTexts(
            med.nombre.toLowerCase(), uniqueMed.nombre.toLowerCase())) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        uniqueMedications.add(med);
      }
    }

    setState(() {
      _recognizedMedications = uniqueMedications;
    });
  }

  // Función auxiliar para determinar si dos textos son similares
  bool _areSimilarTexts(String text1, String text2) {
    // Si los textos están vacíos, no son similares
    if (text1.isEmpty || text2.isEmpty) return false;

    // Si son exactamente iguales
    if (text1 == text2) return true;

    // Si uno contiene al otro
    if (text1.contains(text2) || text2.contains(text1)) return true;

    // Calcula la cantidad de palabras comunes
    List<String> wordsList1 =
        text1.split(' ').where((word) => word.isNotEmpty).toList();
    List<String> wordsList2 =
        text2.split(' ').where((word) => word.isNotEmpty).toList();

    // Si alguna lista está vacía después de filtrar, no son similares
    if (wordsList1.isEmpty || wordsList2.isEmpty) return false;

    Set<String> words1 = wordsList1.toSet();
    Set<String> words2 = wordsList2.toSet();
    int commonWords = words1.intersection(words2).length;

    // Si tienen al menos 60% de palabras comunes y hay al menos una palabra común
    if (commonWords > 0) {
      double ratio1 = commonWords / words1.length;
      double ratio2 = commonWords / words2.length;
      if (ratio1 >= 0.6 || ratio2 >= 0.6) {
        return true;
      }
    }

    return false;
  }

  // Añadir un medicamento a la base de datos
  Future<void> _addMedicationToDatabase(RecognizedMedication medication) async {
    // Navegar a la pantalla de añadir medicamento con los datos prellenados
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnadirMedicamentoScreen(
          nombrePrelleno: medication.nombre,
          dosisPrelleno: medication.dosis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en modo oscuro para adaptar los colores
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Receta'),
        elevation: 4,
        backgroundColor: isDarkMode
            ? Color.fromARGB(255, 30, 30, 40)
            : primaryColor.withOpacity(0.8),
      ),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sección de instrucciones
                Card(
                  elevation: 4,
                  color: isDarkMode
                      ? Color.fromARGB(255, 40, 40, 50)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instrucciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toma una foto de tu receta o prospecto para extraer información de tus medicamentos. ' +
                              'Asegúrate de que el texto sea claramente visible y la imagen esté bien iluminada.',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Botones de cámara y galería
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getImageFromCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text(
                          'Tomar foto',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getImageFromGallery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          Icons.photo_library,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        label: Text(
                          'Galería',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Mostrar la imagen seleccionada o un placeholder
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_imageFile != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Vista previa de la imagen
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _imageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Resultados del escaneo
                          if (_isScanningComplete)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Medicamentos detectados:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                if (_recognizedMedications.isEmpty)
                                  Card(
                                    color: isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Colors.amber),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'No se detectaron medicamentos. Intenta con una imagen más clara.',
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _recognizedMedications.length,
                                    itemBuilder: (context, index) {
                                      final medication =
                                          _recognizedMedications[index];
                                      return Card(
                                        elevation: 2,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        color: isDarkMode
                                            ? Color.fromARGB(255, 50, 50, 60)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            medication.nombre,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Dosis: ${medication.dosis}',
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.add_circle,
                                              color: primaryColor,
                                            ),
                                            onPressed: () =>
                                                _addMedicationToDatabase(
                                                    medication),
                                            tooltip: 'Añadir a medicamentos',
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                // Mostrar el texto completo reconocido (opcional)
                                if (_recognizedText.isNotEmpty)
                                  ExpansionTile(
                                    title: Text(
                                      'Texto completo detectado',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Colors.grey.shade900
                                                    .withOpacity(0.5)
                                                : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          width: double.infinity,
                                          child: Text(
                                            _recognizedText,
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_enhance,
                            size: 80,
                            color: isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Toma una foto o selecciona una imagen\npara escanear tus recetas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Clase para representar un medicamento reconocido
class RecognizedMedication {
  final String nombre;
  final String dosis;
  final String rawText;

  RecognizedMedication({
    required this.nombre,
    required this.dosis,
    required this.rawText,
  });
}
