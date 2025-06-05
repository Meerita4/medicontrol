import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/main.dart';
import 'package:medicontrol/register.dart';
import 'package:medicontrol/utils/responsive_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController =
      TextEditingController(); // Controlador para el email de recuperación
  bool _isLoading = false;
  bool _isResetting = false; // Flag para reseteo de contraseña
  String? _errorMessage;
  String? _successMessage; // Para mensajes de éxito
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  // Método para iniciar sesión
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null; // También limpiar el mensaje de éxito
    });

    try {
      // Iniciar sesión con Supabase
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Verificar el resultado de autenticación
      if (res.user != null) {
        // Si la opción "Recordarme" está marcada, guardamos el valor para referencia
        final storage = FlutterSecureStorage();
        if (_rememberMe) {
          await storage.write(key: 'remember_me', value: 'true');
          print('Preferencia "Recordarme" guardada');
        } else {
          // Si no está marcado, borrar la preferencia guardada
          await storage.delete(key: 'remember_me');
        }

        // Inicio de sesión exitoso, navegar a la página principal
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Esto no debería ocurrir normalmente, ya que Supabase lanza una excepción si falla el login
        setState(() {
          _errorMessage =
              'Credenciales incorrectas. Por favor, verifica tu correo y contraseña.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Error al iniciar sesión';

        // Identificar el tipo de error y mostrar un mensaje personalizado
        if (e.toString().contains('Invalid login credentials')) {
          errorMsg =
              'Credenciales incorrectas. Por favor, verifica tu correo y contraseña.';
        } else if (e.toString().contains('Email not confirmed')) {
          errorMsg =
              'Correo electrónico no confirmado. Por favor, verifica tu correo para activar tu cuenta.';
        } else if (e.toString().contains('network')) {
          errorMsg =
              'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        } else if (e.toString().contains('too many')) {
          errorMsg =
              'Demasiados intentos fallidos. Por favor, inténtalo más tarde.';
        } else if (e.toString().contains('email')) {
          errorMsg =
              'Correo electrónico no registrado. Verifica tu correo o regístrate.';
        } else if (e.toString().contains('password')) {
          errorMsg = 'Contraseña incorrecta. Por favor, inténtalo de nuevo.';
        }

        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  // Método para mostrar diálogo de recuperación de contraseña
  void _showResetPasswordDialog() {
    // Inicializar con el email ya ingresado, si existe
    if (_emailController.text.isNotEmpty) {
      _resetEmailController.text = _emailController.text;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Recuperar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _resetEmailController,
              hintText: 'Correo electrónico',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa tu correo electrónico';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Ingresa un correo electrónico válido';
                }
                return null;
              },
              isDarkMode: isDarkMode,
            ),
            if (_isResetting)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isResetting ? null : () => _resetPassword(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text('Enviar'),
          ),
        ],
      ),
    );
  }

  // Método para restablecer la contraseña
  Future<void> _resetPassword(BuildContext dialogContext) async {
    // Validar email
    if (_resetEmailController.text.isEmpty ||
        !_resetEmailController.text.contains('@') ||
        !_resetEmailController.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor ingresa un correo electrónico válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isResetting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Enviar solicitud de restablecimiento de contraseña
      await supabase.auth.resetPasswordForEmail(
        _resetEmailController.text.trim(),
      );

      // Cerrar el diálogo
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        setState(() {
          _successMessage =
              'Se ha enviado un enlace de recuperación a tu correo electrónico. Por favor revisa tu bandeja de entrada.';
          _errorMessage = null;
          _isResetting = false;
        });
      }
    } catch (e) {
      // Cerrar el diálogo incluso si hay un error
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }

      if (mounted) {
        String errorMsg = 'Error al enviar el correo de recuperación';

        // Personalizar mensajes de error específicos
        if (e.toString().contains('Invalid email')) {
          errorMsg = 'El correo electrónico no está registrado en el sistema.';
        } else if (e.toString().contains('network')) {
          errorMsg =
              'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        } else if (e.toString().contains('rate limit')) {
          errorMsg =
              'Has realizado demasiadas solicitudes. Inténtalo más tarde.';
        }

        setState(() {
          _errorMessage = errorMsg;
          _successMessage = null;
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en modo oscuro para adaptar los colores
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Responsive settings
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Calculate responsive values
    final logoSize = ResponsiveUtils.getAdaptiveSize(
      context,
      mobile: 120,
      tablet: 150,
      desktop: 180,
    );

    final titleSize = ResponsiveUtils.getAdaptiveSize(context,
        mobile: 28, tablet: 32, desktop: 36);

    final subtitleSize = ResponsiveUtils.getAdaptiveSize(context,
        mobile: 16, tablet: 18, desktop: 20);

    final maxFormWidth = isDesktop
        ? 500.0
        : isTablet
            ? 450.0
            : double.infinity;

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
                : [Colors.blue.shade50, Colors.blue.shade200],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: ResponsiveUtils.getAdaptivePadding(
                  context,
                  mobile: EdgeInsets.symmetric(horizontal: 24.0),
                  tablet: EdgeInsets.symmetric(horizontal: 40.0),
                  desktop: EdgeInsets.symmetric(horizontal: 60.0),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: BoxConstraints(
                    maxWidth: maxFormWidth,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo y título
                      Hero(
                        tag: 'login_logo',
                        child: Center(
                          child: Image.asset(
                            'lib/imagenes/logo.png',
                            height: logoSize,
                            width: logoSize,
                          ),
                        ),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getAdaptiveSize(context,
                              mobile: 30, tablet: 40, desktop: 50)),
                      // Título de bienvenida
                      Center(
                        child: Text(
                          '¡Bienvenido!',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getAdaptiveSize(context,
                              mobile: 8, tablet: 12, desktop: 16)),
                      // Subtítulo
                      Center(
                        child: Text(
                          'Accede a tu cuenta para continuar',
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getAdaptiveSize(context,
                              mobile: 40,
                              tablet: 50,
                              desktop:
                                  60)), // Tarjeta del formulario de inicio de sesión
                      Card(
                        elevation: 8,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        color: isDarkMode
                            ? Color.fromARGB(255, 40, 40, 50)
                            : Colors.white,
                        child: Padding(
                          padding: ResponsiveUtils.getAdaptivePadding(
                            context,
                            mobile: EdgeInsets.all(24.0),
                            tablet: EdgeInsets.all(30.0),
                            desktop: EdgeInsets.all(36.0),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Campo de correo electrónico
                                _buildTextField(
                                  controller: _emailController,
                                  hintText: 'Correo electrónico',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu correo electrónico';
                                    }
                                    if (!value.contains('@') ||
                                        !value.contains('.')) {
                                      return 'Ingresa un correo electrónico válido';
                                    }
                                    return null;
                                  },
                                  isDarkMode: isDarkMode,
                                ),
                                SizedBox(
                                    height: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 20,
                                        tablet: 24,
                                        desktop: 28)),

                                // Campo de contraseña
                                _buildTextField(
                                  controller: _passwordController,
                                  hintText: 'Contraseña',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: isDarkMode
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu contraseña';
                                    }
                                    return null;
                                  },
                                  isDarkMode: isDarkMode,
                                ),

                                SizedBox(
                                    height: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 20,
                                        tablet: 24,
                                        desktop:
                                            28)), // Opciones adicionales (recordar sesión)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Opción recordarme
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: primaryColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Recordarme',
                                          style: TextStyle(
                                            fontSize:
                                                ResponsiveUtils.getAdaptiveSize(
                                                    context,
                                                    mobile: 14,
                                                    tablet: 16,
                                                    desktop: 16),
                                            color: isDarkMode
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Botón de olvido de contraseña
                                    TextButton(
                                      onPressed: () {
                                        _showResetPasswordDialog();
                                      },
                                      child: Text(
                                        '¿Olvidaste la contraseña?',
                                        style: TextStyle(
                                          fontSize:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 16),
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(
                                    height: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 30,
                                        tablet: 36,
                                        desktop: 40)),

                                // Botón de inicio de sesión mejorado
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            ResponsiveUtils.getAdaptiveSize(
                                                context,
                                                mobile: 16,
                                                tablet: 18,
                                                desktop: 20)),
                                    minimumSize: Size(
                                        double.infinity,
                                        ResponsiveUtils.getAdaptiveSize(context,
                                            mobile: 56,
                                            tablet: 60,
                                            desktop: 64)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 3,
                                    shadowColor: primaryColor.withOpacity(0.5),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Iniciar sesión',
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils
                                                    .getAdaptiveSize(context,
                                                        mobile: 18,
                                                        tablet: 20,
                                                        desktop: 22),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Icon(
                                              Icons.arrow_forward,
                                              size: ResponsiveUtils
                                                  .getAdaptiveSize(context,
                                                      mobile: 20,
                                                      tablet: 22,
                                                      desktop: 24),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height:
                              24), // Mensaje de error                      if (_errorMessage != null)
                      if (_errorMessage != null)
                        AnimatedOpacity(
                          opacity: _errorMessage != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: ResponsiveUtils.getAdaptiveSize(context,
                                      mobile: 22, tablet: 24, desktop: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: ResponsiveUtils.getAdaptiveSize(
                                          context,
                                          mobile: 14,
                                          tablet: 15,
                                          desktop: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ), // Mensaje de éxito
                      if (_successMessage != null)
                        AnimatedOpacity(
                          opacity: _successMessage != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green.shade700,
                                  size: ResponsiveUtils.getAdaptiveSize(context,
                                      mobile: 22, tablet: 24, desktop: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: ResponsiveUtils.getAdaptiveSize(
                                          context,
                                          mobile: 14,
                                          tablet: 15,
                                          desktop: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ), // Enlace para registrarse
                      Container(
                        margin: EdgeInsets.only(
                            top: ResponsiveUtils.getAdaptiveSize(context,
                                mobile: 20, tablet: 24, desktop: 30),
                            bottom: ResponsiveUtils.getAdaptiveSize(context,
                                mobile: 20, tablet: 24, desktop: 30)),
                        padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getAdaptiveSize(context,
                                mobile: 16, tablet: 20, desktop: 24),
                            vertical: ResponsiveUtils.getAdaptiveSize(context,
                                mobile: 12, tablet: 14, desktop: 16)),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No tienes una cuenta?',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                fontSize: ResponsiveUtils.getAdaptiveSize(
                                    context,
                                    mobile: 15,
                                    tablet: 16,
                                    desktop: 17),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'Regístrate',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: ResponsiveUtils.getAdaptiveSize(
                                      context,
                                      mobile: 16,
                                      tablet: 17,
                                      desktop: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget para construir los campos de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    required bool isDarkMode,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDarkMode
            ? Colors.grey.shade800.withOpacity(0.3)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
      validator: validator,
    );
  }
}
