import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medicontrol/main.dart';
import 'package:intl/intl.dart';
import 'package:medicontrol/medicamentos.dart'; // Importamos la pantalla de medicamentos

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String _userName = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Verificar si el usuario está autenticado
      final User? currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        // Si no hay usuario autenticado, redirigir al login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Usar el email como nombre de usuario por defecto
      String name = '';

      // Método 1: Intentar obtener desde los metadatos del usuario
      if (currentUser.userMetadata != null) {
        name = currentUser.userMetadata!['name'] ?? '';
      }

      // Método 2: Si aún está vacío, usar el email como último recurso
      if (name.isEmpty && currentUser.email != null) {
        // Extraer solo la parte antes del @ del email como un nombre
        name = currentUser.email!.split('@')[0];
      }

      if (mounted) {
        setState(() {
          _userName = name;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los datos del perfil';
          // Intentar usar email como último recurso
          final email = supabase.auth.currentUser?.email;
          _userName = email != null ? email.split('@')[0] : 'Usuario';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cerrar sesión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediControl'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de bienvenida personalizada
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Bienvenido/a, $_userName!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sección de funcionalidades (puedes expandir esto según las necesidades)
                    Text(
                      'Acciones rápidas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 16),

                    // Grid de opciones adaptativo
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        // Determinar si estamos en una pantalla ancha (web/tablet) o estrecha (móvil)
                        final isWideScreen = constraints.maxWidth > 600;
                        final crossAxisCount = isWideScreen ? 3 : 2;

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildFeatureCard(
                              context,
                              'Mis Medicamentos',
                              Icons.medication,
                              () {
                                // Navegación a la pantalla de medicamentos
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MedicamentosScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Recordatorios',
                              Icons.alarm,
                              () {
                                // Navegación a la pantalla de recordatorios (por implementar)
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Mi Perfil',
                              Icons.person,
                              () {
                                // Navegación a la pantalla de perfil (por implementar)
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Historial',
                              Icons.history,
                              () {
                                // Navegación a la pantalla de historial (por implementar)
                              },
                            ),
                          ],
                        );
                      },
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget para crear las tarjetas de funcionalidades
  Widget _buildFeatureCard(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    // Determinar si estamos en una pantalla ancha (web/tablet) o estrecha (móvil)
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                // Tamaño más grande en pantallas anchas
                size: isWideScreen ? 56 : 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isWideScreen ? 18 : 16,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nueva clase HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> medicamentos = [];

  @override
  void initState() {
    super.initState();
    _cargarMedicamentos();
  }

  Future<void> _cargarMedicamentos() async {
    final user = supabase.auth.currentUser;
    final today = DateFormat('HH:mm').format(DateTime.now());

    final response = await supabase
        .from('medicamentos')
        .select()
        .eq('usuario_id', user!.id)
        .order('hora', ascending: true);

    setState(() {
      medicamentos = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombreUsuario =
        Supabase.instance.client.auth.currentUser?.email ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(title: const Text("MediControl")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("👋 Hola, $nombreUsuario", style: TextStyle(fontSize: 22)),
            Text(
                "📅 Hoy es ${DateFormat('EEEE, d MMMM', 'es_ES').format(DateTime.now())}",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (medicamentos.isNotEmpty) ...[
              Text("🔔 Próxima toma:", style: TextStyle(fontSize: 18)),
              Card(
                child: ListTile(
                  title: Text(medicamentos.first['nombre']),
                  subtitle: Text("Dosis: ${medicamentos.first['dosis']} - "
                      "Hora: ${medicamentos.first['hora']}"),
                ),
              ),
            ] else ...[
              Text("No hay medicamentos registrados para hoy."),
            ],
            const SizedBox(height: 20),
            Text("💊 Medicamentos de hoy:", style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                itemCount: medicamentos.length,
                itemBuilder: (context, index) {
                  final m = medicamentos[index];
                  return ListTile(
                    leading: Icon(Icons.medication),
                    title: Text("${m['nombre']} - ${m['dosis']}"),
                    subtitle: Text("⏰ ${m['hora']}"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí puedes navegar a pantalla de añadir medicamento
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
