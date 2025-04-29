import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/main.dart';
import 'package:medicontrol/register.dart'; // Importamos la pantalla de registro

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Quitar el foco de cualquier campo de texto
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Iniciar sesión
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.session != null) {
        if (mounted) {
          // Pequeño retraso antes de navegar
          await Future.delayed(const Duration(milliseconds: 300));

          if (mounted) {
            // Navegar a la pantalla principal después del inicio de sesión exitoso
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Se produjo un error. Por favor intenta nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() {
    // Quitar el foco antes de navegar
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  Future<void> _resetPassword() async {
    // Quitar el foco de cualquier campo de texto
    FocusManager.instance.primaryFocus?.unfocus();

    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage =
            'Por favor, ingresa tu email para recuperar tu contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Se ha enviado un enlace para restablecer la contraseña a tu email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error al enviar el correo de recuperación';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en una pantalla ancha (web/tablet) o estrecha (móvil)
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // En pantallas anchas, limitar el ancho del formulario
              maxWidth: isWideScreen ? 500 : screenWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo o imagen
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Image.asset(
                        'lib/imagenes/logo.png',
                        height: isWideScreen ? 120 : 100,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Título
                    Text(
                      'MediControl',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                                fontSize: isWideScreen ? 32 : 24,
                              ),
                    ),

                    const SizedBox(height: 32),

                    // Campo de email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Ingresa un email válido';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Campo de contraseña
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu contraseña';
                        }
                        return null;
                      },
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Botón de iniciar sesión
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Iniciar Sesión',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),

                    const SizedBox(height: 16),

                    // Botón para navegar a la pantalla de registro
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isLoading ? null : _navigateToRegister,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('¿No tienes cuenta? Regístrate',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Opción de recuperación de contraseña
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('¿Olvidaste tu contraseña?',
                            style: TextStyle(fontSize: 16)),
                      ),
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
}
