# 💊 MediControl

**MediControl** es una aplicación móvil desarrollada con Flutter para ayudar a los usuarios a gestionar y controlar su medicación de forma sencilla y segura. Permite registrar medicamentos, programar recordatorios, escanear recetas y generar informes en PDF.

---

## ✨ Características principales

- 📋 **Gestión de medicamentos** — Registra, edita y organiza todos tus medicamentos en un solo lugar.
- ⏰ **Recordatorios y notificaciones** — Recibe alertas locales para no olvidar ninguna toma, con soporte completo de zonas horarias.
- 🔍 **Escaneo de recetas** — Usa la cámara del dispositivo y Google ML Kit para extraer información de recetas médicas.
- 📄 **Generación de informes PDF** — Exporta tu historial o listado de medicamentos como PDF y compártelo fácilmente.
- ☁️ **Backend con Supabase** — Sincronización y almacenamiento seguro de datos en la nube.
- 🔐 **Almacenamiento seguro** — Las credenciales y datos sensibles se guardan con `flutter_secure_storage`.
- 🌐 **Multiplataforma** — Compatible con Android, iOS, Web, macOS y Windows.

---

## 🛠️ Tecnologías utilizadas

| Categoría | Tecnología |
|---|---|
| Framework | Flutter 3.x / Dart ≥ 3.1.0 |
| Backend | Supabase |
| Notificaciones | flutter_local_notifications + timezone |
| Machine Learning | Google ML Kit |
| Cámara / Imágenes | camera, image_picker |
| PDF | pdf, printing |
| Almacenamiento local | shared_preferences, flutter_secure_storage |
| Red | http |
| Compartir archivos | share_plus, cross_file |
| Variables de entorno | flutter_dotenv |

---

## 🚀 Instalación y puesta en marcha

### Prerrequisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.1.0
- Dart ≥ 3.1.0
- Una cuenta en [Supabase](https://supabase.com) con un proyecto creado

### 1. Clona el repositorio

```bash
git clone https://github.com/Meerita4/medicontrol.git
cd medicontrol
```

### 2. Configura las variables de entorno

Crea un archivo `.env` en la raíz del proyecto con tus credenciales de Supabase:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu_anon_key
```

### 3. Instala las dependencias

```bash
flutter pub get
```

### 4. Ejecuta la aplicación

```bash
# Android / iOS
flutter run

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

---

## 📁 Estructura del proyecto

medicontrol/
├── android/            # Configuración nativa Android
├── ios/                # Configuración nativa iOS
├── macos/              # Configuración nativa macOS
├── windows/            # Configuración nativa Windows
├── web/                # Configuración Web
├── lib/                # Código fuente principal (Dart)
│   └── imagenes/       # Assets de imágenes (logo, etc.)
├── test/               # Tests unitarios y de widget
├── documentacion/      # Documentación adicional del proyecto
├── .env                # Variables de entorno (no subir a Git)
├── pubspec.yaml        # Dependencias y configuración del proyecto
└── README.md
## 🧪 Tests

```bash
flutter test

## 📄 Licencia
Este proyecto es de uso privado y no está publicado en pub.dev. Todos los derechos reservados © 2024 Meerita4.
## 🤝 Contribuciones
Las contribuciones no están abiertas actualmente. Si encuentras un bug o tienes una sugerencia, abre un [issue](https://github.com/Meerita4/medicontrol/issues).
> Desarrollado usando Flutter y Supabase.
