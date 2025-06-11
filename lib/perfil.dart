import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:medicontrol/main.dart'; // Importar para acceder al controlador de tema
import 'utils/responsive_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({Key? key}) : super(key: key);

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Variables para el estado de la pantalla
  bool _isLoading = true;
  bool _isEditingProfile = false;
  bool _isChangingPassword = false;
  String? _errorMessage;
  String? _successMessage;

  // Datos del usuario
  String _userId = '';
  String _userName = '';
  String _userEmail = '';
  String _createdAt = '';
  int _totalMedicamentos = 0;
  int _medicamentosTomados = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Cargar datos del perfil desde Supabase
  Future<void> _cargarDatosPerfil() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // 1. Obtener datos del usuario actual
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("No hay usuario autenticado");
      }

      _userId = user.id;
      _userEmail = user.email ?? 'Sin email';

      // 2. Intentar obtener datos adicionales desde la tabla profiles
      try {
        final profileData =
            await supabase.from('profiles').select().eq('id', _userId).single();

        // Usar directamente los datos del perfil sin verificación null innecesaria
        _userName = profileData['name'] ?? '';

        // Formatear fecha de creación si está disponible
        if (profileData['created_at'] != null) {
          final createdAtDate = DateTime.parse(profileData['created_at']);
          _createdAt = DateFormat('dd/MM/yyyy').format(createdAtDate);
        }
      } catch (e) {
        print("Error al cargar perfil: $e");
        // Si no hay datos en profiles, usar la información básica
        _userName = user.userMetadata?['name'] ??
            user.email?.split('@')[0] ??
            'Usuario';
        _createdAt = 'No disponible';
      }

      // 3. Cargar estadísticas de medicamentos
      await _cargarEstadisticasMedicamentos();

      // 4. Actualizar controladores con datos actuales
      _nombreController.text = _userName;
      _emailController.text = _userEmail;
    } catch (error) {
      setState(() {
        _errorMessage = 'Error al cargar datos del perfil: ${error.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cargar estadísticas de medicamentos del usuario
  Future<void> _cargarEstadisticasMedicamentos() async {
    try {
      // Total de medicamentos
      final medicamentosResponse = await supabase
          .from('medicamentos')
          .select('count')
          .eq('usuario_id', _userId);

      if (medicamentosResponse.isNotEmpty) {
        _totalMedicamentos = medicamentosResponse[0]['count'];
      }

      // Total de medicamentos tomados (desde historial)
      final historialResponse = await supabase
          .from('historial')
          .select('count')
          .eq('usuario_id', _userId)
          .eq('tomado', true);

      if (historialResponse.isNotEmpty) {
        _medicamentosTomados = historialResponse[0]['count'];
      }
    } catch (e) {
      print("Error al cargar estadísticas: $e");
    }
  }

  // Actualizar datos del perfil
  Future<void> _actualizarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final nuevoNombre = _nombreController.text.trim();
      final nuevoEmail = _emailController.text.trim();

      // Verificar si el email ha cambiado
      bool emailCambiado = nuevoEmail != _userEmail;

      // 1. Actualizar nombre en Supabase Auth y email si ha cambiado
      if (emailCambiado) {
        // Actualizar el email requiere usar updateUser de auth
        await supabase.auth.updateUser(UserAttributes(
          email: nuevoEmail,
          data: {'name': nuevoNombre},
        ));

        print("Email y nombre actualizados en Auth");
        _userEmail = nuevoEmail;
      } else {
        // Solo actualizar los metadatos con el nombre
        await supabase.auth.updateUser(UserAttributes(
          data: {'name': nuevoNombre},
        ));

        print("Solo nombre actualizado en Auth");
      }

      /* La siguiente parte está comentada porque la tabla "profiles" no existe en la base de datos
      // 2. Actualizar datos en la tabla profiles
      await supabase.from('profiles').upsert({
        'id': _userId,
        'name': nuevoNombre,
        'email': nuevoEmail,
        'updated_at': DateTime.now().toIso8601String(),
      });
      */

      setState(() {
        _userName = nuevoNombre;
        _successMessage = 'Perfil actualizado correctamente';
        _isEditingProfile = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Error al actualizar perfil: ${error.toString()}';
      });
      print("Error detallado al actualizar perfil: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cambiar la contraseña
  Future<void> _actualizarContrasena() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Actualizar contraseña
      await supabase.auth.updateUser(
        UserAttributes(
          password: _newPasswordController.text.trim(),
        ),
      );

      // Limpiar campos
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _successMessage = 'Contraseña actualizada correctamente';
        _isChangingPassword = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Error al actualizar contraseña: ${error.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para mostrar diálogo de confirmación de cierre de sesión
  void _mostrarDialogCerrarSesion() {
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
          '¿Cerrar sesión?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Se cerrará tu sesión y volverás a la pantalla de inicio. ¿Quieres continuar?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
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
            onPressed: () async {
              await _cerrarSesion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // Método para cerrar la sesión
  Future<void> _cerrarSesion() async {
    try {
      // Limpiar las credenciales guardadas
      try {
        final storage = FlutterSecureStorage();
        // Eliminar las preferencias de "Recordarme"
        await storage.delete(key: 'remember_me');
        // Eliminar cualquier otro dato relacionado con la sesión
        await storage.delete(key: 'session_token');
        await storage.delete(key: 'user_email');
        print('Credenciales guardadas eliminadas');
      } catch (storageError) {
        print('Error al eliminar credenciales guardadas: $storageError');
      } // Cerrar sesión en Supabase
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive settings
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Mi Perfil",
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
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: ResponsiveUtils.getAdaptiveSize(context,
                  mobile: 24, tablet: 26, desktop: 28),
            ),
            onPressed: _cargarDatosPerfil,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
              child: _buildProfileContent(isTablet, isDarkMode, primaryColor),
            ),
    );
  }

  Widget _buildProfileContent(
      bool isTablet, bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del perfil mejorado con gradiente
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          primaryColor.withOpacity(0.7),
                          primaryColor.withOpacity(0.3)
                        ]
                      : [
                          primaryColor.withOpacity(0.8),
                          primaryColor.withOpacity(0.5)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Elementos decorativos de fondo
                  Positioned(
                    right: -30,
                    top: -30,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -40,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  // Información del usuario
                  Column(
                    children: [
                      Row(
                        children: [
                          // Avatar con la primera letra del nombre
                          CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            radius: isTablet ? 40 : 36,
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : "U",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 36 : 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Nombre y correo del usuario
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  style: TextStyle(
                                    fontSize: isTablet ? 26 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.email,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.9)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _userEmail,
                                        style: TextStyle(
                                          fontSize: isTablet ? 16 : 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_createdAt.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sección de estadísticas con tarjetas mejoradas
            _buildStatsSection(isTablet, isDarkMode, primaryColor),

            const SizedBox(height: 30),

            // Sección de opciones de cuenta
            _buildSectionTitle(
                'Opciones de cuenta', Icons.settings, primaryColor, isDarkMode),

            const SizedBox(height: 16),

            // Solo mostrar las opciones cuando no se está editando perfil ni cambiando contraseña
            if (!_isEditingProfile && !_isChangingPassword)
              _buildOptionsCard(isTablet, isDarkMode),

            // Mostrar el formulario de edición de perfil cuando _isEditingProfile es true
            if (_isEditingProfile) _buildEditProfileForm(isTablet),

            // Mostrar el formulario de cambio de contraseña cuando _isChangingPassword es true
            if (_isChangingPassword) _buildChangePasswordForm(isTablet),

            // Mostrar mensajes de éxito o error con diseño mejorado
            if (_errorMessage != null)
              _buildMessageContainer(_errorMessage!, Colors.red, isDarkMode),

            if (_successMessage != null)
              _buildMessageContainer(
                  _successMessage!, Colors.green, isDarkMode),
          ],
        ),
      ),
    );
  }

  // Widget para crear títulos de sección con iconos
  Widget _buildSectionTitle(
      String title, IconData icon, Color primaryColor, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(isDarkMode ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para las estadísticas del usuario
  Widget _buildStatsSection(
      bool isTablet, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Estadísticas', Icons.bar_chart,
            isDarkMode ? Colors.purple.shade300 : Colors.purple, isDarkMode),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.medication,
                title: "Medicamentos",
                value: _totalMedicamentos.toString(),
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          Colors.blue.shade700.withOpacity(0.7),
                          Colors.blue.shade900.withOpacity(0.7)
                        ]
                      : [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: Colors.white,
                isTablet: isTablet,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                title: "Tomados",
                value: _medicamentosTomados.toString(),
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          Colors.green.shade700.withOpacity(0.7),
                          Colors.green.shade900.withOpacity(0.7)
                        ]
                      : [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: Colors.white,
                isTablet: isTablet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget para una tarjeta de estadística con gradiente
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Gradient gradient,
    required Color textColor,
    required bool isTablet,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: isTablet ? 44 : 38, color: textColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: textColor.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para las opciones de cuenta
  Widget _buildOptionsCard(bool isTablet, bool isDarkMode) {
    final backgroundColor =
        isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return Card(
      elevation: 4,
      color: backgroundColor,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildOptionListTile(
            icon: Icons.edit,
            title: "Editar perfil",
            subtitle: "Cambiar información personal",
            color: Colors.blue,
            onTap: () {
              setState(() {
                _isEditingProfile = true;
                _isChangingPassword = false;
              });
            },
            isTablet: isTablet,
            isDarkMode: isDarkMode,
          ),
          Divider(height: 1, color: borderColor),
          _buildOptionListTile(
            icon: Icons.lock,
            title: "Cambiar contraseña",
            subtitle: "Actualiza tu contraseña",
            color: Colors.amber,
            onTap: () {
              setState(() {
                _isChangingPassword = true;
                _isEditingProfile = false;
              });
            },
            isTablet: isTablet,
            isDarkMode: isDarkMode,
          ),
          Divider(height: 1, color: borderColor),
          _buildOptionListTile(
            icon: Icons.logout,
            title: "Cerrar sesión",
            subtitle: "Salir de la aplicación",
            color: Colors.red,
            onTap: () {
              _mostrarDialogCerrarSesion();
            },
            isTablet: isTablet,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  // Widget para un elemento de la lista de opciones
  Widget _buildOptionListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
    required bool isDarkMode,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isTablet ? 12 : 8,
      ),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: isTablet ? 26 : 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isTablet ? 18 : 16,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: isTablet ? 14 : 13,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
        size: isTablet ? 26 : 22,
      ),
      onTap: onTap,
    );
  }

  // Widget para mostrar mensajes (error o éxito)
  Widget _buildMessageContainer(String message, Color color, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            color == Colors.green
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para el formulario de edición de perfil
  Widget _buildEditProfileForm(bool isTablet) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor =
        isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white;

    return Card(
      elevation: 4,
      color: cardColor,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                  'Editar perfil', Icons.edit_note, primaryColor, isDarkMode),
              const SizedBox(height: 20),

              // Campo Nombre mejorado
              _buildTextField(
                controller: _nombreController,
                labelText: 'Nombre',
                hintText: 'Tu nombre completo',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Campo Email mejorado
              _buildTextField(
                controller: _emailController,
                labelText: 'Email',
                hintText: 'Tu dirección de email',
                icon: Icons.email,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Por favor ingresa un email válido';
                  }
                  return null;
                },
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Selección de tema
              _buildThemeSelector(isDarkMode),

              const SizedBox(height: 30),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        // Restaurar datos originales
                        _nombreController.text = _userName;
                        _emailController.text = _userEmail;
                        _isEditingProfile = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade400,
                      ),
                      foregroundColor: isDarkMode
                          ? Colors.grey.shade200
                          : Colors.grey.shade800,
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _actualizarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isDarkMode ? 4 : 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save),
                        const SizedBox(width: 10),
                        const Text(
                          'Guardar cambios',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para campos de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    bool isDarkMode = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final fillColor = isDarkMode
        ? Colors.grey.shade800.withOpacity(0.3)
        : Colors.grey.shade50;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade300 : null,
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        prefixIcon:
            Icon(icon, color: primaryColor.withOpacity(isDarkMode ? 0.8 : 1.0)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      validator: validator,
    );
  }

  // Widget para el formulario de cambio de contraseña
  Widget _buildChangePasswordForm(bool isTablet) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Colors.amber;
    final cardColor =
        isDarkMode ? Color.fromARGB(255, 40, 40, 50) : Colors.white;

    return Card(
      elevation: 4,
      color: cardColor,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Cambiar contraseña', Icons.lock_reset,
                  accentColor, isDarkMode),
              const SizedBox(height: 20),

              // Campo Contraseña actual
              _buildTextField(
                controller: _currentPasswordController,
                labelText: 'Contraseña actual',
                hintText: 'Ingresa tu contraseña actual',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu contraseña actual';
                  }
                  return null;
                },
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Nueva contraseña
              _buildTextField(
                controller: _newPasswordController,
                labelText: 'Nueva contraseña',
                hintText: 'Ingresa tu nueva contraseña',
                icon: Icons.lock,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nueva contraseña';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Confirmación de nueva contraseña
              _buildTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirmar nueva contraseña',
                hintText: 'Confirma tu nueva contraseña',
                icon: Icons.lock_reset,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor confirma tu nueva contraseña';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 30),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        // Limpiar campos
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                        _isChangingPassword = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _actualizarContrasena,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isDarkMode ? 4 : 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check),
                        const SizedBox(width: 10),
                        const Text(
                          'Actualizar contraseña',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para el selector de tema
  Widget _buildThemeSelector(bool isDarkMode) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.palette,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tema de la aplicación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.grey.shade800.withOpacity(0.3)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildThemeOption(
                title: 'Claro',
                icon: Icons.light_mode,
                isSelected: themeController.themeMode == ThemeMode.light,
                onTap: () => themeController.setThemeMode(ThemeMode.light),
                isDarkMode: isDarkMode,
              ),
              Divider(
                  height: 1,
                  color:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
              _buildThemeOption(
                title: 'Oscuro',
                icon: Icons.dark_mode,
                isSelected: themeController.themeMode == ThemeMode.dark,
                onTap: () => themeController.setThemeMode(ThemeMode.dark),
                isDarkMode: isDarkMode,
              ),
              Divider(
                  height: 1,
                  color:
                      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
              _buildThemeOption(
                title: 'Sistema',
                icon: Icons.settings_system_daydream,
                isSelected: themeController.themeMode == ThemeMode.system,
                onTap: () => themeController.setThemeMode(ThemeMode.system),
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget para una opción de tema
  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? primaryColor
            : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing:
          isSelected ? Icon(Icons.check_circle, color: primaryColor) : null,
      onTap: onTap,
      dense: true,
    );
  }
}
