import 'package:flutter/material.dart';
import 'package:medicontrol/login.dart';
import 'package:medicontrol/register.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
              Colors.blue.shade100,
              Colors.blue.shade300,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 1),
                    // Logo de MediControl
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Ajusta el tamaño de la imagen según el ancho disponible
                        double logoWidth = constraints.maxWidth * 0.8;
                        // En dispositivos más grandes, limita el tamaño máximo
                        if (isWideScreen) {
                          logoWidth = MediaQuery.of(context).size.width * 0.35;
                        }

                        return Container(
                          constraints: BoxConstraints(
                            maxWidth: logoWidth,
                            maxHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          child: Image.asset(
                            'lib/imagenes/logo.png',
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Bienvenido a MediControl',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: isWideScreen ? 32 : 24,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tu asistente para el control de medicamentos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue.shade800,
                            fontSize: isWideScreen ? 20 : 16,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 1),
                    // Botón de Iniciar Sesión
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                    ),
                    const SizedBox(height: 20),
                    // Botón de Registro
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
