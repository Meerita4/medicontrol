import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/login.dart';
import 'package:medicontrol/splash_screen.dart';
import 'package:medicontrol/home.dart';
import 'package:medicontrol/medicamentos.dart';
import 'package:medicontrol/add_medicamento.dart';
import 'package:medicontrol/historial.dart';
import 'package:medicontrol/perfil.dart';
import 'package:medicontrol/register.dart';
import 'package:medicontrol/ai_assistant.dart';
import 'package:medicontrol/scan_prescriptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service_fixed.dart';

// Controlador de tema global
class ThemeController with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeController() {
    _loadThemeMode();
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }
}

// Instancia global del controlador de tema
final themeController = ThemeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final NotificationService notificationService = NotificationService();
  await notificationService.init();
  print("Notification service initialized");
  // Load environment variables from .env file
  await dotenv.load();
  // Initialize Supabase with persistent authentication
  await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  runApp(const MyApp());
}

// Create a client to use throughout the app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos esquemas de color mejorados para ambos temas
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.lightBlueAccent,
      brightness: Brightness.dark,
      primary: Colors.lightBlueAccent,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
      onBackground:
          Colors.white.withOpacity(0.9), // Texto claro sobre fondo oscuro
      onSurface: Colors.white
          .withOpacity(0.95), // Mejor contraste en superficies oscuras
    );

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'MediControl',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            fontFamily: 'Montserrat',
            brightness: Brightness.light,
            // Configuraciones específicas para tema claro
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: Colors.black87),
              bodyMedium: TextStyle(color: Colors.black87),
              displayLarge: TextStyle(color: Colors.black),
              displayMedium: TextStyle(color: Colors.black),
              displaySmall: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black),
            ),
            cardTheme: CardTheme(
              color: Colors.white,
            ),
            appBarTheme: AppBarTheme(
              titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            fontFamily: 'Montserrat',
            brightness: Brightness.dark,
            // Configuraciones específicas para tema oscuro
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: Colors.white.withOpacity(0.9)),
              bodyMedium: TextStyle(color: Colors.white.withOpacity(0.9)),
              displayLarge: TextStyle(color: Colors.white),
              displayMedium: TextStyle(color: Colors.white),
              displaySmall: TextStyle(color: Colors.white.withOpacity(0.95)),
              titleLarge: TextStyle(color: Colors.white),
            ),
            cardTheme: CardTheme(
              color: const Color(0xFF2C2C2C),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          themeMode: themeController.themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/home': (context) => const HomePage(),
            '/medicamentos': (context) => const MedicamentosScreen(),
            '/add_medicamento': (context) => const AnadirMedicamentoScreen(),
            '/historial': (context) => const HistorialScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/assistant': (context) => const AIAssistantScreen(),
            '/scan_prescriptions': (context) => const ScanPrescriptionsScreen(),
          },
          // Add responsive builder to maintain consistent text scaling
          builder: (context, child) {
            return MediaQuery(
              // Ensure consistent text scaling regardless of device settings
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: child!,
            );
          },
        );
      },
    );
  }
}

// Mantenemos la clase MyHomePage para compatibilidad con código existente
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
