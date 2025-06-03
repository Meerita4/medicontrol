import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/main.dart'; // Para acceder a la instancia de supabase
import 'package:medicontrol/utils/responsive_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Método para registrar usuario
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Debes aceptar los términos y condiciones';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Registrar usuario en Supabase
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'name': _nameController.text.trim(),
        },
      );

      if (mounted) {
        if (res.user != null) {
          // Registro exitoso, navegar a la página principal
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          setState(() {
            _errorMessage = 'Error al registrar usuario';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
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

    // Responsive settings
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Calculate responsive values
    final logoSize = ResponsiveUtils.getAdaptiveSize(
      context,
      mobile: 100,
      tablet: 120,
      desktop: 140,
    );

    final titleSize = ResponsiveUtils.getAdaptiveSize(context,
        mobile: 26, tablet: 30, desktop: 34);

    final subtitleSize = ResponsiveUtils.getAdaptiveSize(context,
        mobile: 15, tablet: 16, desktop: 18);
    final maxFormWidth = isDesktop
        ? 550.0
        : isTablet
            ? 500.0
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
                : [Colors.white, Color.fromARGB(255, 240, 245, 255)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: ResponsiveUtils.getAdaptivePadding(
                  context,
                  mobile: const EdgeInsets.symmetric(horizontal: 24.0),
                  tablet: const EdgeInsets.symmetric(horizontal: 40.0),
                  desktop: const EdgeInsets.symmetric(horizontal: 60.0),
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
                        tag: 'register_logo',
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
                              mobile: 20, tablet: 24, desktop: 28)),
                      // Título
                      Center(
                        child: Text(
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getAdaptiveSize(context,
                              mobile: 8, tablet: 10, desktop: 12)),
                      // Subtítulo
                      Center(
                        child: Text(
                          'Únete a MediControl para gestionar tus medicamentos',
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
                              mobile: 30, tablet: 36, desktop: 42)),

                      // Tarjeta del formulario de registro
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
                            mobile: const EdgeInsets.all(24.0),
                            tablet: const EdgeInsets.all(32.0),
                            desktop: const EdgeInsets.all(36.0),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Campo de nombre
                                _buildTextField(
                                  controller: _nameController,
                                  hintText: 'Nombre completo',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu nombre';
                                    }
                                    return null;
                                  },
                                  isDarkMode: isDarkMode,
                                ),
                                SizedBox(
                                    height: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 16,
                                        tablet: 18,
                                        desktop: 20)),

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
                                        mobile: 16,
                                        tablet: 18,
                                        desktop: 20)),

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
                                      return 'Por favor ingresa una contraseña';
                                    }
                                    if (value.length < 6) {
                                      return 'La contraseña debe tener al menos 6 caracteres';
                                    }
                                    return null;
                                  },
                                  isDarkMode: isDarkMode,
                                ),
                                SizedBox(
                                    height: ResponsiveUtils.getAdaptiveSize(
                                        context,
                                        mobile: 16,
                                        tablet: 18,
                                        desktop: 20)),

                                // Campo de confirmación de contraseña
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  hintText: 'Confirmar contraseña',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: isDarkMode
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor confirma tu contraseña';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Las contraseñas no coinciden';
                                    }
                                    return null;
                                  },
                                  isDarkMode: isDarkMode,
                                ),

                                const SizedBox(height: 20),

                                // Checkbox de términos y condiciones
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _acceptTerms,
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _acceptTerms = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Acepto los ',
                                            ),
                                            TextSpan(
                                              text: 'Términos y Condiciones',
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  // Mostrar términos y condiciones
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: Text(
                                                          'Términos y Condiciones'),
                                                      content:
                                                          SingleChildScrollView(
                                                        child: Text(
                                                          'Al utilizar MediControl, aceptas nuestros términos y políticas de privacidad. Tus datos se utilizarán únicamente para proporcionarte servicios relacionados con la aplicación.',
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: Text('Cerrar'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24), // Botón de registro
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: ResponsiveUtils.getAdaptivePadding(
                                      context,
                                      mobile: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      tablet: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      desktop: const EdgeInsets.symmetric(
                                          vertical: 20),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                    shadowColor: primaryColor.withOpacity(0.5),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 20,
                                                  tablet: 22,
                                                  desktop: 24),
                                          width:
                                              ResponsiveUtils.getAdaptiveSize(
                                                  context,
                                                  mobile: 20,
                                                  tablet: 22,
                                                  desktop: 24),
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
                                              'Crear cuenta',
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils
                                                    .getAdaptiveSize(context,
                                                        mobile: 16,
                                                        tablet: 17,
                                                        desktop: 18),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(
                                                width: ResponsiveUtils
                                                    .getAdaptiveSize(context,
                                                        mobile: 8,
                                                        tablet: 9,
                                                        desktop: 10)),
                                            Icon(
                                              Icons.arrow_forward,
                                              size: ResponsiveUtils
                                                  .getAdaptiveSize(context,
                                                      mobile: 18,
                                                      tablet: 19,
                                                      desktop: 20),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Mensaje de error
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Enlace para iniciar sesión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿Ya tienes una cuenta?',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushReplacementNamed('/login');
                            },
                            child: Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
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
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
        ),
      ),
      validator: validator,
    );
  }
}
