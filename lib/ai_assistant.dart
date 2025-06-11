import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIAssistantScreen extends StatefulWidget {
  final Function? onMedicationAction;

  const AIAssistantScreen({
    Key? key,
    this.onMedicationAction,
  }) : super(key: key);

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}


class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final supabase = Supabase.instance.client;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _initDrugBankAPI();
    // Mostrar mensaje de bienvenida al iniciar
    _addBotMessage(_getBienvenida());
  }

  Future<void> _initDrugBankAPI() async {
    try {
      // Obtener la API key desde .env
      _apiKey = dotenv.env['DRUGBANK_API_KEY'] ?? '';

      if (_apiKey.isEmpty) {
        _addBotMessage(
            "Error: No se ha configurado la API key de DrugBank. El asistente funcionará con información limitada.");
        return;
      }
    } catch (e) {
      print("Error al inicializar DrugBank API: $e");
      _addBotMessage(
          "Error al inicializar el asistente. El asistente funcionará con información limitada.");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Método para añadir un mensaje del usuario
  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // Método para añadir un mensaje del bot
  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // Método para procesar el mensaje del usuario y generar respuesta
  Future<void> _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;

    _addUserMessage(text);
    _textController.clear();

    // Mostrar animación de escritura
    setState(() {
      _isTyping = true;
    });

    try {
      String respuesta;

      if (_apiKey.isEmpty) {
        // Usar modo offline si no hay API key
        respuesta = await _generateLocalResponse(text);
      } else {
        // Intentar buscar información de medicamentos en DrugBank
        respuesta = await _generateDrugBankResponse(text);
      }

      // Ocultar animación de escritura y mostrar respuesta
      setState(() {
        _isTyping = false;
      });

      _addBotMessage(respuesta);
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _addBotMessage(
          "Lo siento, ha ocurrido un error al procesar tu consulta. ¿Puedes intentarlo de nuevo?");
      print("Error al generar respuesta: $e");
    }
  }

  // Generar respuesta usando DrugBank API
  Future<String> _generateDrugBankResponse(String text) async {
    try {
      // Extraer posibles nombres de medicamentos del texto del usuario
      List<String> medicamentos = _extractDrugNames(text);

      // Si no se encontraron posibles medicamentos, usar respuesta local
      if (medicamentos.isEmpty) {
        return await _generateLocalResponse(text);
      }

      // Obtener información de DrugBank para el primer medicamento encontrado
      String medicamentoNombre = medicamentos.first;
      Map<String, dynamic>? drugInfo =
          await _searchDrugByName(medicamentoNombre);

      if (drugInfo == null) {
        // Si no encontramos información en DrugBank, usar respuesta local
        return await _generateLocalResponse(text);
      }

      // Obtener información del usuario para personalizar la respuesta
      final user = supabase.auth.currentUser;
      final userName = user?.userMetadata?['name'] ??
          user?.email?.split('@')[0] ??
          'Usuario';

      // Formatear respuesta con la información obtenida
      String respuesta =
          "Hola $userName, aquí tienes información sobre $medicamentoNombre:\n\n";

      // Añadir información básica del medicamento
      if (drugInfo.containsKey('name')) {
        respuesta += "**Nombre**: ${drugInfo['name']}\n";
      }

      if (drugInfo.containsKey('description')) {
        respuesta += "**Descripción**: ${drugInfo['description']}\n\n";
      }

      // Añadir información de indicaciones si está disponible
      if (drugInfo.containsKey('indications')) {
        respuesta += "**Indicaciones**: ${drugInfo['indications']}\n\n";
      }

      // Añadir información de efectos adversos si está disponible
      if (drugInfo.containsKey('adverse_effects')) {
        respuesta +=
            "**Efectos adversos comunes**: ${drugInfo['adverse_effects']}\n\n";
      }

      // Añadir información de dosis si está disponible
      if (drugInfo.containsKey('dosage')) {
        respuesta += "**Dosificación**: ${drugInfo['dosage']}\n\n";
      }

      respuesta +=
          "Esta información es proporcionada por DrugBank y tiene carácter informativo. Siempre consulta con un profesional de la salud para tu caso específico.";

      return respuesta;
    } catch (e) {
      print("Error usando DrugBank API: $e");
      // Si falla DrugBank, usar respuesta local como respaldo
      return await _generateLocalResponse(text);
    }
  }

  // Método para extraer posibles nombres de medicamentos del texto del usuario
  List<String> _extractDrugNames(String text) {
    // Lista de palabras a ignorar (artículos, preposiciones, etc.)
    final ignoredWords = [
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'unos',
      'unas',
      'sobre',
      'como',
      'qué',
      'que',
      'cuál',
      'cual',
      'cuáles',
      'cuando',
      'donde',
      'quien',
      'por',
      'para',
      'al',
      'del',
      'dame',
      'dime',
      'quiero',
      'necesito',
      'información',
      'sobre',
      'acerca',
      'conocer',
      'saber'
    ];

    // Dividir el texto en palabras y filtrar palabras cortas y las que estén en la lista de ignoradas
    final words = text
        .toLowerCase()
        .split(RegExp(r'[,\.\s;:!¡?¿]+'))
        .where((word) => word.length > 3 && !ignoredWords.contains(word))
        .toList();

    // Lista de nombres de medicamentos comunes que queremos detectar directamente
    final commonDrugNames = [
      'paracetamol',
      'ibuprofeno',
      'amoxicilina',
      'omeprazol',
      'atorvastatina',
      'aspirina',
      'loratadina',
      'metformina',
      'levotiroxina',
      'salbutamol',
      'acetaminofén',
      'diazepam',
      'valium',
      'lexatin',
      'nolotil',
      'tramadol',
      'morfina',
      'codeína',
      'fluoxetina',
      'prozac',
      'simvastatina',
      'enalapril',
      'losartan',
      'captopril',
      'valsartan',
      'amlodipino',
      'insulina',
      'ranitidina',
      'amoxicilina',
      'claritromicina',
      'azitromicina',
      'ciprofloxacino',
      'alprazolam',
      'digoxina',
      'warfarina',
      'sintrom',
      'adiro',
      'prednisona',
      'cortisona',
      'cetirizina',
      'escitalopram',
      'paroxetina',
      'sertralina',
      'tamoxifeno',
      'furosemida',
      'hidroclorotiazida',
      'almax',
      'viagra',
      'sildenafilo',
      'cialis',
      'tadalafilo',
      'ventolin',
      'symbicort',
      'eutirox',
      'augmentine',
      'neobrufen'
    ];

    // Buscar palabras que puedan ser nombres de medicamentos
    final potentialDrugWords = [
      'medicamento',
      'medicina',
      'pastilla',
      'píldora',
      'tableta',
      'cápsula',
      'jarabe',
      'dosis',
      'tratamiento',
      'fármaco',
      'droga',
      'comprimido',
      'receta',
      'inyección',
      'antibiótico',
      'analgésico',
      'antiinflamatorio',
      'antihistamínico',
      'antidepresivo',
      'ansiolítico',
      'tomar',
      'ingerir'
    ];

    List<String> result = [];

    // Primero, verificar si alguna de las palabras coincide con medicamentos comunes
    for (var word in words) {
      if (commonDrugNames.contains(word)) {
        result.add(word);
      }
    }

    // Si ya encontramos medicamentos conocidos, no buscamos más
    if (result.isNotEmpty) {
      return result;
    }

    // Buscar palabras en el texto original que puedan ser medicamentos
    for (var i = 0; i < words.length; i++) {
      String word = words[i];

      // Verificar si es un posible nombre de medicamento
      bool isPotentialDrug = false;
      // Si la palabra está cerca de una palabra clave relacionada con medicamentos
      for (var j = math.max(0, i - 3);
          j <= math.min(words.length - 1, i + 3);
          j++) {
        if (j != i && potentialDrugWords.contains(words[j])) {
          isPotentialDrug = true;
          break;
        }
      }

      // Si la palabra original en el texto empezaba con mayúscula (podría ser un nombre propio)
      String originalWord = text
          .split(RegExp(r'[,\.\s;:!¡?¿]+'))
          .firstWhere((w) => w.toLowerCase() == word, orElse: () => '');
      if (originalWord.isNotEmpty &&
          originalWord[0] == originalWord[0].toUpperCase()) {
        isPotentialDrug = true;
      }

      if (isPotentialDrug && !result.contains(word)) {
        result.add(word);
      }
    }

    // Si aún no encontramos nada, agregar la primera palabra sustantiva que no sea un verbo común
    if (result.isEmpty && words.isNotEmpty) {
      for (var word in words) {
        if (word.length > 4 &&
            !['tengo', 'quiero', 'puedo', 'debo', 'estoy', 'tomar']
                .contains(word)) {
          result.add(word);
          break;
        }
      }
    }

    return result;
  }

  // Método para buscar información de un medicamento en DrugBank por nombre
  Future<Map<String, dynamic>?> _searchDrugByName(String name) async {
    if (_apiKey.isEmpty) return null;

    try {
      // Simular una respuesta de la API de DrugBank (en un caso real, harías una petición HTTP)
      // Nota: DrugBank API requiere suscripción de pago, por eso simulamos la respuesta
      // Información simulada para algunos medicamentos comunes
      final mockDrugs = {
        'paracetamol': {
          'name': 'Paracetamol (Acetaminofén)',
          'description':
              'El paracetamol es un medicamento analgésico y antipirético utilizado para el tratamiento del dolor leve a moderado y la fiebre.',
          'indications':
              'Dolor de cabeza, dolor muscular, dolor de articulaciones, dolor dental, fiebre.',
          'adverse_effects':
              'Náuseas, erupciones cutáneas. En dosis altas puede causar daño hepático.',
          'dosage':
              'Adultos: 500-1000 mg cada 4-6 horas según sea necesario, sin exceder los 4000 mg al día.'
        },
        'ibuprofeno': {
          'name': 'Ibuprofeno',
          'description':
              'El ibuprofeno es un antiinflamatorio no esteroideo (AINE) que reduce las hormonas que causan inflamación y dolor en el cuerpo.',
          'indications':
              'Dolor, fiebre, inflamación, artritis, migrañas, dolor menstrual.',
          'adverse_effects':
              'Dolor de estómago, acidez, náuseas, vómitos, dolor de cabeza, mareos, erupción cutánea.',
          'dosage':
              'Adultos: 200-400 mg cada 4-6 horas según sea necesario, sin exceder los 1200 mg al día.'
        },
        'amoxicilina': {
          'name': 'Amoxicilina',
          'description':
              'La amoxicilina es un antibiótico del grupo de las penicilinas usado para tratar diferentes tipos de infecciones causadas por bacterias.',
          'indications':
              'Infecciones del oído, nariz, garganta, tracto urinario, piel y pulmones.',
          'adverse_effects':
              'Diarrea, malestar estomacal, erupción cutánea, náuseas, vómitos.',
          'dosage':
              'Adultos: 250-500 mg cada 8 horas dependiendo de la infección.'
        },
        'omeprazol': {
          'name': 'Omeprazol',
          'description':
              'El omeprazol es un inhibidor de la bomba de protones que disminuye la cantidad de ácido producido en el estómago.',
          'indications':
              'Úlceras gástricas y duodenales, reflujo gastroesofágico, síndrome de Zollinger-Ellison.',
          'adverse_effects':
              'Dolor de cabeza, dolor abdominal, náuseas, diarrea, vómitos, gases.',
          'dosage':
              'Adultos: 20-40 mg una vez al día, preferiblemente por la mañana.'
        },
        'atorvastatina': {
          'name': 'Atorvastatina',
          'description':
              'La atorvastatina es un medicamento de la clase de las estatinas usado para reducir el colesterol en sangre y prevenir enfermedades cardiovasculares.',
          'indications':
              'Hipercolesterolemia, prevención de enfermedades cardiovasculares.',
          'adverse_effects':
              'Dolor muscular, dolor articular, debilidad, náuseas, diarrea.',
          'dosage':
              'Adultos: 10-80 mg una vez al día, generalmente por la noche.'
        },
        'loratadina': {
          'name': 'Loratadina',
          'description':
              'La loratadina es un antihistamínico que reduce los efectos de la histamina natural en el cuerpo, aliviando los síntomas de alergia.',
          'indications': 'Rinitis alérgica, urticaria, alergias cutáneas.',
          'adverse_effects':
              'Somnolencia (menos común que otros antihistamínicos), sequedad bucal, dolor de cabeza.',
          'dosage': 'Adultos y niños mayores de 12 años: 10 mg una vez al día.'
        },
        'aspirina': {
          'name': 'Aspirina (Ácido acetilsalicílico)',
          'description':
              'La aspirina es un medicamento antiinflamatorio no esteroideo (AINE) con propiedades analgésicas, antipiréticas y anticoagulantes.',
          'indications':
              'Dolor, inflamación, fiebre, prevención de eventos cardiovasculares.',
          'adverse_effects':
              'Irritación gástrica, úlceras, sangrado, reacciones alérgicas. Síndrome de Reye en niños.',
          'dosage':
              'Adultos: 325-650 mg cada 4-6 horas para dolor o fiebre; 81-325 mg diarios para prevención cardiovascular.'
        },
        'metformina': {
          'name': 'Metformina',
          'description':
              'La metformina es un medicamento antidiabético que ayuda a controlar los niveles de azúcar en sangre en pacientes con diabetes tipo 2.',
          'indications':
              'Diabetes tipo 2, síndrome de ovario poliquístico, prediabetes.',
          'adverse_effects':
              'Malestar estomacal, diarrea, náuseas, acidosis láctica (rara pero grave).',
          'dosage':
              'Adultos: Iniciar con 500 mg dos veces al día, pudiendo aumentar gradualmente hasta 2000-2500 mg diarios divididos en 2-3 tomas.'
        },
        'levotiroxina': {
          'name': 'Levotiroxina',
          'description':
              'La levotiroxina es una hormona tiroidea sintética utilizada para reemplazar la hormona que normalmente produce la glándula tiroides.',
          'indications':
              'Hipotiroidismo, bocio multinodular, cáncer de tiroides.',
          'adverse_effects':
              'Nerviosismo, insomnio, temblores, dolor de cabeza, cambios en el apetito, diarrea, sudoración.',
          'dosage':
              'Adultos: Dosis inicial de 25-50 mcg/día, ajustándose gradualmente según respuesta.'
        },
        'salbutamol': {
          'name': 'Salbutamol (Albuterol)',
          'description':
              'El salbutamol es un broncodilatador que relaja los músculos de las vías respiratorias para mejorar la respiración.',
          'indications':
              'Asma, broncoespasmo, EPOC (enfermedad pulmonar obstructiva crónica).',
          'adverse_effects':
              'Temblores, nerviosismo, dolor de cabeza, taquicardia, palpitaciones.',
          'dosage':
              'Inhalador: 1-2 inhalaciones cada 4-6 horas según sea necesario.'
        },
      };

      // Buscar en la base de datos simulada
      for (final entry in mockDrugs.entries) {
        if (name.toLowerCase().contains(entry.key)) {
          return entry.value;
        }
      }

      // Si no se encuentra el medicamento, devolver null
      return null;
    } catch (e) {
      print("Error al buscar información del medicamento: $e");
      return null;
    }
  }

  // Método para generar una respuesta local (sin OpenAI) basada en el texto del usuario
  Future<String> _generateLocalResponse(String text) async {
    // Convertir el texto a minúsculas para facilitar la comparación
    final lowerText = text.toLowerCase();

    try {
      // Obtener información del usuario actual para personalizar respuestas
      final user = supabase.auth.currentUser;
      final userName = user?.userMetadata?['name'] ??
          user?.email?.split('@')[0] ??
          'Usuario';

      // Verificar medicamentos del usuario para respuestas contextuales
      final medicamentos = await _getMedicamentosUsuario();

      // Patrones de respuesta basados en el texto del usuario

      // Saludos
      if (_containsAnyOf(
          lowerText, ['hola', 'buenos días', 'buenas tardes', 'saludos'])) {
        return "¡Hola $userName! Soy tu asistente de MediControl. ¿En qué puedo ayudarte hoy? Puedes preguntarme por tus medicamentos, cómo añadir uno nuevo, o pedirme recordatorios.";
      }

      // Preguntas sobre medicamentos pendientes
      else if (_containsAnyOf(lowerText,
          ['pendientes', 'faltan', 'tomar', 'siguientes', 'medicamentos'])) {
        if (medicamentos.isEmpty) {
          return "No tienes medicamentos registrados actualmente. ¿Quieres que te ayude a añadir uno?";
        } else {
          final medicamentosPendientes =
              medicamentos.where((med) => med['tomado_local'] != true).toList();
          if (medicamentosPendientes.isEmpty) {
            return "¡Felicidades! Has tomado todos tus medicamentos programados para hoy.";
          } else {
            String respuesta =
                "Tienes ${medicamentosPendientes.length} medicamentos pendientes para hoy:\n\n";
            for (var med in medicamentosPendientes) {
              respuesta += "• ${med['nombre']} a las ${med['hora']}\n";
            }
            return respuesta;
          }
        }
      }

      // Ayuda para añadir medicamentos
      else if (_containsAnyOf(lowerText,
          ['añadir', 'agregar', 'nuevo medicamento', 'como agrego'])) {
        return "Para añadir un nuevo medicamento, ve a la sección 'Añadir medicamento' desde la pantalla principal. Allí podrás introducir el nombre, dosis, horario y días de la semana. También puedes tocar el botón de '+' en la sección de medicamentos. ¿Necesitas que te guíe paso a paso?";
      }

      // Información sobre efectos secundarios o información médica
      else if (_containsAnyOf(
          lowerText, ['efectos secundarios', 'interacción', 'síntomas'])) {
        return "Como asistente virtual no puedo proporcionar consejos médicos específicos. Si tienes dudas sobre efectos secundarios o interacciones medicamentosas, es importante que consultes a tu médico o farmacéutico. ¿Puedo ayudarte con algo más relacionado con el uso de la aplicación?";
      }

      // Preguntas sobre la aplicación
      else if (_containsAnyOf(lowerText,
          ['cómo funciona', 'para qué sirve', 'app', 'aplicación'])) {
        return "MediControl es una aplicación para gestionar tus medicamentos y tratamientos. Te permite:\n\n• Registrar tus medicamentos con horarios y dosis\n• Recibir recordatorios cuando debas tomarlos\n• Llevar un historial de medicamentos tomados\n• Visualizar estadísticas de cumplimiento\n\n¿Hay alguna función específica sobre la que quieras saber más?";
      }

      // Agradecimientos
      else if (_containsAnyOf(
          lowerText, ['gracias', 'thank', 'te lo agradezco'])) {
        return "¡De nada! Estoy aquí para ayudarte con tu tratamiento. Si tienes más preguntas, no dudes en consultarme.";
      }

      // Despedidas
      else if (_containsAnyOf(
          lowerText, ['adiós', 'chao', 'hasta luego', 'bye'])) {
        return "¡Hasta pronto! Recuerda tomar tus medicamentos a tiempo. Estaré aquí cuando me necesites.";
      }

      // Recordatorios
      else if (_containsAnyOf(
          lowerText, ['recordar', 'recordatorio', 'avisa', 'alerta'])) {
        return "MediControl te enviará notificaciones para recordarte cuando debas tomar tus medicamentos. Para que funcionen correctamente, asegúrate de tener las notificaciones activadas en los ajustes de tu dispositivo para esta aplicación.";
      }

      // Respuesta por defecto cuando no se reconoce la intención
      else {
        return "Entiendo que me estás preguntando sobre \"$text\". Como asistente de MediControl, puedo ayudarte con información sobre tus medicamentos, recordatorios, o cómo usar la aplicación. ¿Puedes reformular tu pregunta?";
      }
    } catch (e) {
      print("Error al generar respuesta local: $e");
      return "Lo siento, ha ocurrido un error al procesar tu consulta. ¿Puedes intentarlo de nuevo?";
    }
  }

  // Verificar si el texto contiene alguna de las palabras clave
  bool _containsAnyOf(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  // Obtener mensaje de bienvenida personalizado
  String _getBienvenida() {
    final hora = DateTime.now().hour;
    String saludo;

    if (hora < 12) {
      saludo = "¡Buenos días!";
    } else if (hora < 18) {
      saludo = "¡Buenas tardes!";
    } else {
      saludo = "¡Buenas noches!";
    }

    final user = supabase.auth.currentUser;
    final userName =
        user?.userMetadata?['name'] ?? user?.email?.split('@')[0] ?? 'Usuario';

    return "$saludo $userName.\n\nSoy MediBot, tu asistente virtual con información de DrugBank. Puedo ayudarte con:\n• Información farmacológica de medicamentos\n• Recordatorios de tomas pendientes\n• Posibles efectos secundarios de medicamentos\n• Interacciones medicamentosas\n\n¿En qué puedo ayudarte hoy?";
  }

  // Obtener medicamentos del usuario actual
  Future<List<dynamic>> _getMedicamentosUsuario() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      // Obtener la fecha de hoy para filtrar
      final fechaHoy = DateTime.now().toString().split(' ')[0];

      // Obtener el día de la semana actual (1-7, donde 1 es lunes)
      final diaSemanaActual = DateTime.now().weekday;

      // Cargar medicamentos del usuario
      final response = await supabase
          .from('medicamentos')
          .select('*')
          .eq('usuario_id', userId)
          .order('hora', ascending: true);

      // Proceso de respuesta

      // Filtrar medicamentos para el día actual
      final medicamentosHoy = response.where((med) {
        // Verificar si este medicamento está programado para el día actual
        bool estaProgramadoParaHoy = false;

        // Verificar días específicos configurados
        if (med['dias'] != null) {
          List<dynamic> diasMedicamento = med['dias'];
          estaProgramadoParaHoy = diasMedicamento.contains(diaSemanaActual);
        } else {
          estaProgramadoParaHoy = true; // Por defecto, todos los días
        }

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

        return estaProgramadoParaHoy && estaEnPeriodoTratamiento;
      }).toList();

      // Cargar historial para saber qué medicamentos ya se tomaron
      final historialHoy = await supabase
          .from('historial')
          .select('medicamento_id, tomado')
          .eq('usuario_id', userId)
          .eq('fecha', fechaHoy)
          .eq('tomado', true);

      // Marcar medicamentos como tomados según el historial
      final medicamentosTomadosIds =
          historialHoy.map((item) => item['medicamento_id'].toString()).toSet();

      for (var med in medicamentosHoy) {
        final medicamentoId = med['id'].toString();
        med['tomado_local'] = medicamentosTomadosIds.contains(medicamentoId);
      }

      return medicamentosHoy;
    } catch (e) {
      print("Error al cargar medicamentos: $e");
      return [];
    }
  }

  // Método para hacer scroll hasta el final de la lista de mensajes
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_information, size: 24),
            SizedBox(width: 8),
            Text('DrugBank - MediBot'),
          ],
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? Color(0xFF1F1F21) : Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF343541) : Colors.white,
        ),
        child: Column(
          children: [
            // Área de mensajes
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  // Mostrar animación de escritura al final
                  if (_isTyping && index == _messages.length) {
                    return _buildTypingIndicator(isDarkMode, primaryColor);
                  }

                  // Mostrar mensaje
                  final message = _messages[index];
                  return _buildMessageBubble(message, isDarkMode, primaryColor);
                },
              ),
            ), // Separador
            Divider(
                height: 1,
                thickness: 1,
                color:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),

            // Sugerencias de medicamentos populares
            _buildSuggestionChips(),

            // Área de entrada de texto
            _buildMessageInputArea(isDarkMode, primaryColor),
            // Widget para mostrar chips de medicamentos populares como sugerencias
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  // Widget para el indicador de "escribiendo..."
  Widget _buildTypingIndicator(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: isDarkMode ? Color(0xFF444654) : Color(0xFFF7F7F8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFF4CAF50),
            radius: 16,
            child: Icon(
              Icons.medical_information,
              size: 20,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16),
          Row(
            children: [
              _buildDot(primaryColor),
              SizedBox(width: 4),
              _buildDot(primaryColor, delay: 300),
              SizedBox(width: 4),
              _buildDot(primaryColor, delay: 600),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para un punto animado en el indicador de escritura
  Widget _buildDot(Color color, {int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(math.sin(value * math.pi * 2) * 0.5 + 0.5),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // Widget para una burbuja de mensaje
  Widget _buildMessageBubble(
      ChatMessage message, bool isDarkMode, Color primaryColor) {
    final isUser = message.isUser;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: isUser
          ? (isDarkMode ? Color(0xFF343541) : Colors.white)
          : (isDarkMode ? Color(0xFF444654) : Color(0xFFF7F7F8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: isUser ? Colors.grey : Color(0xFF4CAF50),
            radius: 16,
            child: Icon(
              isUser ? Icons.person : Icons.medical_information,
              size: 20,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16),
          // Mensaje
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'Tú' : 'MediBot',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isUser
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : Color(0xFF4CAF50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para el área de entrada de mensajes
  Widget _buildMessageInputArea(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF343541) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF40414F) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Pregúntame sobre un medicamento...',
                        hintStyle: TextStyle(
                          color:
                              isDarkMode ? Colors.grey : Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (text) => _handleUserMessage(text),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: _textController.text.trim().isEmpty
                          ? (isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade400)
                          : Color(0xFF4CAF50),
                    ),
                    onPressed: () {
                      if (_textController.text.trim().isNotEmpty) {
                        _handleUserMessage(_textController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar chips de medicamentos populares como sugerencias
  Widget _buildSuggestionChips() {
    final popularDrugs = [
      'Paracetamol',
      'Ibuprofeno',
      'Amoxicilina',
      'Omeprazol',
      'Aspirina'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        children: popularDrugs
            .map((drug) => ActionChip(
                  avatar: Icon(Icons.medication,
                      size: 18, color: Color(0xFF4CAF50)),
                  label: Text(drug),
                  onPressed: () {
                    _handleUserMessage("Información sobre $drug");
                  },
                ))
            .toList(),
      ),
    );
  }

  // Formatear timestamp para mostrarlo en el mensaje
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
