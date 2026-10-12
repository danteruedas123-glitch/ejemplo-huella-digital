import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BiometricDemoApp());
}

class BiometricDemoApp extends StatelessWidget {
  const BiometricDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo Sensor de Huellas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1325),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00C9A7),
          surface: Color(0xFF131F37),
          error: Color(0xFFFF5252),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF131F37),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E2D4A), width: 1),
          ),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const BiometricHomePage(),
    );
  }
}

class BiometricHomePage extends StatefulWidget {
  const BiometricHomePage({super.key});

  @override
  State<BiometricHomePage> createState() => _BiometricHomePageState();
}

class _BiometricHomePageState extends State<BiometricHomePage> {
  final LocalAuthentication _auth = LocalAuthentication();

  // Estados del dispositivo y autenticación
  bool _canCheckBiometrics = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isAuthenticated = false;
  String _statusMessage = 'Listo para realizar pruebas';
  Color _statusColor = Colors.grey;
  bool _isAuthenticating = false;

  // Registro de eventos en vivo para la exposición
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkDeviceSupport();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _logs.insert(0, "[$timeStr] $message");
      if (_logs.length > 25) _logs.removeLast();
    });
  }

  // =========================================================================
  // PASO 2: Verificar soporte biométrico (Diapositiva 9)
  // BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG)
  // =========================================================================
  Future<void> _checkDeviceSupport() async {
    _addLog("Verificando soporte de hardware...");
    bool canCheck = false;
    bool isSupported = false;
    List<BiometricType> available = [];

    try {
      isSupported = await _auth.isDeviceSupported();
      canCheck = await _auth.canCheckBiometrics;
      available = await _auth.getAvailableBiometrics();

      _addLog(
          "Hardware compatible: $isSupported | Huellas registradas: $canCheck");
      _addLog(
          "Sensores disponibles: ${available.isEmpty ? 'Ninguno' : available.map((e) => e.name).join(', ')}");
    } on PlatformException catch (e) {
      _addLog("Error de plataforma: ${e.message}");
    } catch (e) {
      _addLog("Aviso: $e");
    }

    if (!mounted) return;
    setState(() {
      _isDeviceSupported = isSupported;
      _canCheckBiometrics = canCheck;
      _availableBiometrics = available;
    });
  }

  // =========================================================================
  // PASO 3 y 4: Disparar BiometricPrompt / LocalAuthentication (Diaps 10 y 11)
  // =========================================================================
  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Mostrando prompt del sistema...';
      _statusColor = Colors.amber;
    });

    _addLog("Invocando diálogo nativo (BiometricPrompt / LAContext)...");

    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason:
            'Usa tu huella digital para acceder a la aplicación',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _statusMessage = '¡Autenticación biométrica exitosa!';
        _statusColor = const Color(0xFF00C9A7);
        _addLog("Éxito: Coincidencia confirmada por TEE / Secure Enclave");
      } else {
        _statusMessage = 'Autenticación cancelada o huella no coincide';
        _statusColor = Colors.orange;
        _addLog("Cancelación o fallo de lectura");
      }
    } on LocalAuthException catch (e) {
      _addLog("LocalAuthException: ${e.code.name} - ${e.description}");
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          _statusMessage = 'Dispositivo sin sensor de huellas físico';
          break;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          _statusMessage = 'No hay huellas registradas en el dispositivo';
          break;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          _statusMessage = 'Sensor bloqueado por intentos fallidos excesivos';
          break;
        case LocalAuthExceptionCode.userCanceled:
          _statusMessage = 'El usuario cerró el diálogo biométrico';
          break;
        default:
          _statusMessage = 'Error biométrico: ${e.description ?? e.code.name}';
      }
      _statusColor = Colors.redAccent;
    } on PlatformException catch (e) {
      _addLog("PlatformException: ${e.code} - ${e.message}");
      _statusMessage = 'Error de plataforma: ${e.message ?? e.code}';
      _statusColor = Colors.redAccent;
    } catch (e) {
      _addLog("Excepción general: $e");
      _statusMessage = 'Error al ejecutar biometría';
      _statusColor = Colors.redAccent;
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _isAuthenticated = authenticated;
        });
      }
    }
  }

  // =========================================================================
  // BUENAS PRÁCTICAS: Método alternativo (PIN/Password - Diaps 16 y 20)
  // "Ofrecer alternativa siempre: un método de PIN o contraseña"
  // =========================================================================
  void _authenticateWithPinFallback() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131F37),
        title: const Row(
          children: [
            Icon(Icons.pin_outlined, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Método Alternativo', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Según la diapositiva 16, siempre se debe ofrecer un método alternativo de respaldo si no hay huella disponible:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Introduce tu PIN (Ej: 1234)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (pinController.text == '1234') {
                setState(() {
                  _isAuthenticated = true;
                  _statusMessage = '¡Autenticado mediante PIN de respaldo!';
                  _statusColor = const Color(0xFF00C9A7);
                });
                _addLog("Éxito: Acceso concedido mediante PIN alternativo");
              } else {
                setState(() {
                  _statusMessage = 'PIN incorrecto (usa 1234 para demo)';
                  _statusColor = Colors.redAccent;
                });
                _addLog("Fallo: PIN de respaldo incorrecto");
              }
            },
            child: const Text('Validar PIN'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SIMULACIÓN DEMO (Para pruebas rápidas en PC, Web o Emulador)
  // =========================================================================
  void _simulateDemoAuthentication(bool succeed) {
    setState(() {
      if (succeed) {
        _isAuthenticated = true;
        _statusMessage = '[Demo] Simulación: Huella validada correctamente';
        _statusColor = const Color(0xFF00C9A7);
        _addLog("Demo: Simulación de éxito recibida desde TEE / Secure Enclave");
      } else {
        _isAuthenticated = false;
        _statusMessage = '[Demo] Simulación: Huella rechazada o no reconocida';
        _statusColor = Colors.orange;
        _addLog("Demo: Simulación de fallo en coincidencia de huella");
      }
    });
  }

  void _resetStatus() {
    setState(() {
      _isAuthenticated = false;
      _statusMessage = 'Estado reiniciado. Listo para probar.';
      _statusColor = Colors.grey;
    });
    _addLog("Estado reiniciado a No Autenticado");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1325),
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor de Huellas Digitales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'App Dummy de Pruebas · Programación Móvil',
              style: TextStyle(fontSize: 12, color: Color(0xFF00E5FF)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reiniciar prueba',
            icon: const Icon(Icons.refresh),
            onPressed: _resetStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TARJETA DE ESTADO ACTUAL
            _buildStatusCard(),

            const SizedBox(height: 18),

            // 2. BOTÓN INTERACTIVO DE HUELLA DIGITAL
            _buildFingerprintButton(),

            const SizedBox(height: 18),

            // 3. BOTONES DE ACCIÓN (NATIVO Y ALTERNATIVOS)
            _buildActionButtons(),

            const SizedBox(height: 16),

            // 4. DIAGNÓSTICO DE SOPORTE BIOMÉTRICO (PASO 2)
            _buildHardwareCard(),

            const SizedBox(height: 16),

            // 5. GUÍA RÁPIDA DE LAS DIAPOSITIVAS
            _buildSlidesGuideCard(),

            const SizedBox(height: 16),

            // 6. CONSOLA DE EVENTOS EN VIVO
            _buildLogConsole(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _isAuthenticated
                  ? const Color(0xFF063B2B)
                  : const Color(0xFF131F37),
              const Color(0xFF0E172A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _isAuthenticated
                ? const Color(0xFF00C9A7)
                : const Color(0xFF1E2D4A),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAuthenticated
                    ? Icons.lock_open_rounded
                    : Icons.fingerprint_rounded,
                color: _statusColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAuthenticated ? 'ESTADO: ACCESO CONCEDIDO' : 'ESTADO: BLOQUEADO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFingerprintButton() {
    return Center(
      child: GestureDetector(
        onTap: _isAuthenticating ? null : _authenticateWithBiometrics,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _isAuthenticated
                  ? [const Color(0xFF00C9A7), const Color(0xFF00897B)]
                  : [const Color(0xFF00E5FF), const Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isAuthenticated
                        ? const Color(0xFF00C9A7)
                        : const Color(0xFF00E5FF))
                    .withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 54,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                _isAuthenticating ? 'Leyendo...' : 'Tocar Sensor',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.fingerprint),
          label: const Text(
            'Probar BiometricPrompt (Hardware Real)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.pin, size: 16),
                label: const Text('PIN Alternativo', style: TextStyle(fontSize: 11)),
                onPressed: _authenticateWithPinFallback,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C9A7),
                  side: const BorderSide(color: Color(0xFF00C9A7)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Simular Éxito', style: TextStyle(fontSize: 11)),
                onPressed: () => _simulateDemoAuthentication(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Simular Fallo', style: TextStyle(fontSize: 11)),
                onPressed: () => _simulateDemoAuthentication(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHardwareCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.memory_rounded,
                        color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Paso 2: Diagnóstico del Sensor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _checkDeviceSupport,
                  child: const Text('Re-verificar',
                      style: TextStyle(fontSize: 12, color: Color(0xFF00E5FF))),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E2D4A)),
            _buildCheckItem(
              'Hardware biométrico soportado',
              _isDeviceSupported,
              'BiometricManager.canAuthenticate() / isDeviceSupported',
            ),
            const SizedBox(height: 8),
            _buildCheckItem(
              'Huellas registradas en el dispositivo',
              _canCheckBiometrics,
              'El usuario ha configurado biometría en el sistema',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                const Text('Tipos detectados: ',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                Text(
                  _availableBiometrics.isEmpty
                      ? 'Ninguno o sin sensor físico'
                      : _availableBiometrics.map((b) => b.name).join(', '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String title, bool value, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          value ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: value ? const Color(0xFF00C9A7) : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlidesGuideCard() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        collapsedIconColor: const Color(0xFF00E5FF),
        iconColor: const Color(0xFF00E5FF),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Row(
          children: [
            Icon(Icons.slideshow_rounded, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Puntos Clave de la Exposición',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Divider(color: Color(0xFF1E2D4A)),
                _GuideBullet(
                  number: '1',
                  title: 'Seguridad y Privacidad (Diap. 4 y 5)',
                  description:
                      'La app nunca recibe la huella en crudo. Todo se procesa en el TEE (Android) o Secure Enclave (iOS). La app solo recibe éxito, fallo o cancelación.',
                ),
                _GuideBullet(
                  number: '2',
                  title: 'APIs Oficiales (Diap. 6, 8 y 12)',
                  description:
                      'Android usa androidx.biometric:biometric:1.1.0 (BiometricPrompt). iOS usa LocalAuthentication (LAContext).',
                ),
                _GuideBullet(
                  number: '3',
                  title: 'Permisos Requeridos (Diap. 14 y 15)',
                  description:
                      'Android: <uses-permission android:name="android.permission.USE_BIOMETRIC"/>\niOS: Clave NSFaceIDUsageDescription en Info.plist.',
                ),
                _GuideBullet(
                  number: '4',
                  title: 'Políticas de Tiendas (Diap. 18, 19 y 20)',
                  description:
                      'Declarar en Data Safety de Google Play, ofrecer método alternativo (PIN/Pass) y avisar antes de solicitar el prompt.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogConsole() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Registro de Eventos (Logs)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _logs.clear()),
                  child: const Text('Limpiar',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 110,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E2D4A)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin actividad reciente',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[i],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _GuideBullet({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
