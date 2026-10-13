# Demo de sensor de huellas digitales en Flutter

Proyecto de **Programación Móvil**. Tema: **Biometría (huella / Face ID)** con el paquete [`local_auth`](https://pub.dev/packages/local_auth).

**Integrantes:** Kevin Juliao · Hallan Santiago · Keiver Hernández · Sebastián Cantillo

## ¿Qué hace la app?

Una pantalla de pruebas que usa el sensor biométrico del teléfono y muestra, paso a paso, qué ocurre:

- **Diagnóstico del sensor:** al abrir la pantalla comprueba `isDeviceSupported`, `canCheckBiometrics` y `getAvailableBiometrics`.
- **Autenticación:** llama a `authenticate` con el cuadro nativo del sistema (BiometricPrompt en Android, LocalAuthentication en iOS).
- **Manejo de errores:** captura `LocalAuthException` y traduce cada código a un mensaje.
- **Alternativa con PIN:** un cuadro de PIN de respaldo (en la demo, `1234`), porque siempre hay que ofrecer otra salida.
- **Simulación:** botones *Simular éxito* y *Simular fallo* para probar la pantalla en el computador o en el navegador, donde `local_auth` no funciona.
- **Consola de eventos:** muestra en pantalla todo lo que va ocurriendo.

## Resultados que maneja

| Situación | Código | Qué muestra la app |
| --- | --- | --- |
| La huella coincide | `authenticate` devuelve `true` | Estado "Acceso concedido" |
| La huella no coincide | `authenticate` devuelve `false` | "Autenticación cancelada o huella no coincide" |
| El usuario cierra el cuadro | `userCanceled` | "El usuario cerró el diálogo biométrico" |
| Sin sensor | `noBiometricHardware` | "Dispositivo sin sensor de huellas físico" |
| Sin huellas registradas | `noBiometricsEnrolled` | "No hay huellas registradas en el dispositivo" |
| Demasiados intentos | `temporaryLockout` / `biometricLockout` | "Sensor bloqueado por intentos fallidos excesivos" |
| Error del sistema | `PlatformException` | Mensaje con el error de plataforma |

## Permisos y configuración por plataforma

### Android
- `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`
- `android/app/src/main/kotlin/.../MainActivity.kt`: la actividad extiende **`FlutterFragmentActivity`**, porque el cuadro de huella necesita una `FragmentActivity`.
- El paquete requiere Android 7.0 (API 24) o superior.

### iOS
- `ios/Runner/Info.plist`: clave `NSFaceIDUsageDescription` con el motivo por el que se usa Face ID o Touch ID.

### Web
- `local_auth` **no está soportado en web**. El equivalente del navegador es **WebAuthn** (passkeys), una API distinta que exige HTTPS.

> La huella no tiene un cuadro de "permitir / denegar" como la cámara: el usuario la acepta poniendo su dedo y la niega cancelando.

## Cómo ejecutarla

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) y un teléfono con sensor de huella registrado (o un emulador con huella configurada).

```bash
git clone https://github.com/danteruedas123-glitch/ejemplo-huella-digital.git
cd ejemplo-huella-digital
flutter pub get
flutter run              # con el teléfono conectado y depuración USB activada
flutter run -d chrome    # versión web (solo para probar con los botones de simulación)
flutter test             # prueba de humo
```

## Estructura

| Archivo | Contenido |
| --- | --- |
| `lib/main.dart` | Pantalla, diagnóstico del sensor, autenticación, PIN y consola |
| `pubspec.yaml` | Dependencia `local_auth: ^3.0.2` |
| `test/widget_test.dart` | Prueba de humo de la pantalla |

## Referencias

- [local_auth en pub.dev](https://pub.dev/packages/local_auth)
- [Permiso USE_BIOMETRIC en Android](https://developer.android.com/reference/android/Manifest.permission#USE_BIOMETRIC)
- [Autenticación biométrica en Android](https://developer.android.com/identity/sign-in/biometric-auth)
- [Local Authentication en Apple](https://developer.apple.com/documentation/localauthentication)
- [WebAuthn en MDN](https://developer.mozilla.org/docs/Web/API/Web_Authentication_API)
