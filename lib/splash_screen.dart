import 'package:flutter/material.dart';
import 'package:medicontrol/login.dart';
import 'package:medicontrol/register.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Verificar si existe una sesión guardada
    _checkSavedSession();
  } // Método para verificar si hay una sesión guardada

  Future<void> _checkSavedSession() async {
    try {
      // Mostrar la pantalla de splash por un breve momento
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // Verificar si ya hay una sesión activa usando la API de Supabase
      final currentSession = Supabase.instance.client.auth.currentSession;
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentSession != null && currentUser != null) {
        print('Sesión activa encontrada para: ${currentUser.email}');

        // Verificar si la sesión es válida intentando acceder a datos
        try {
          // Acceder a un dato básico para asegurar que la sesión es válida
          await Supabase.instance.client
              .from('medicamentos')
              .select('id')
              .limit(1);

          print('Sesión validada correctamente');

          // Si la sesión es válida, redirigir a la página principal
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        } catch (authError) {
          print('Error al verificar sesión: $authError');
          // Si hay error de autenticación, cerramos sesión para limpiar
          await Supabase.instance.client.auth.signOut();
        }
      } else {
        print('No se encontró una sesión activa');
        // Limpiar cualquier dato de sesión residual por seguridad
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'remember_me');
      }
    } catch (e) {
      print('Error al verificar la sesión guardada: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en una pantalla ancha (web/tablet) o móvil
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // En pantallas anchas, limitar el ancho del contenido
                maxWidth: isWideScreen ? 600 : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(
                        flex: 1), // Logo de MediControl con animación sutil
                    Hero(
                      tag: 'splash_logo',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Ajusta el tamaño de la imagen según el ancho disponible
                          double logoWidth = constraints.maxWidth * 0.7;
                          // En dispositivos más grandes, limita el tamaño máximo
                          if (isWideScreen) {
                            logoWidth = MediaQuery.of(context).size.width * 0.3;
                          }

                          return Container(
                            constraints: BoxConstraints(
                              maxWidth: logoWidth,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.3,
                            ),
                            child: Image.asset(
                              'lib/imagenes/logo.png',
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Bienvenido a MediControl',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: isWideScreen ? 32 : 26,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu asistente personal para el control de medicamentos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue.shade800,
                            fontSize: isWideScreen ? 20 : 16,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 1),

                    // Contenedor de botones con diseño mejorado
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // Botón de Iniciar Sesión
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 56),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: isWideScreen ? 18 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Botón de Registro
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => const RegisterPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 56),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Registrarse',
                              style: TextStyle(
                                fontSize: isWideScreen ? 18 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
