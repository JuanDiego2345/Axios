/// Interfaz gráfica de Axios: `dart run bin/gui.dart [--puerto 8080] [--no-abrir]`
///
/// Abre el navegador en http://127.0.0.1:8080 con las mismas órdenes del CLI.
library;

import 'dart:io';

import 'package:cli/cli.dart';
import 'package:cli/gui.dart';

Future<void> main(List<String> args) async {
  var puerto = 8080;
  var abrir = true;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--puerto' && i + 1 < args.length) {
      puerto = int.tryParse(args[++i]) ?? puerto;
    } else if (args[i] == '--no-abrir') {
      abrir = false;
    }
  }

  File? pagina;
  for (final ruta in ['web/index.html', 'cli/web/index.html']) {
    if (File(ruta).existsSync()) {
      pagina = File(ruta);
      break;
    }
  }
  if (pagina == null) {
    stderr.writeln('No se encontró web/index.html. Ejecuta desde la carpeta cli.');
    exit(1);
  }

  final AxiosCli axios;
  try {
    axios = AxiosCli.crear();
  } catch (e) {
    stderr.writeln('Error al inicializar Axios: $e');
    exit(1);
  }

  final servidor = ServidorAxios(ApiAxios(axios), pagina);
  try {
    await servidor.iniciar(puerto: puerto);
  } on SocketException {
    stderr.writeln('El puerto $puerto está ocupado. Usa --puerto 8081.');
    axios.cerrar();
    exit(1);
  }

  final url = 'http://127.0.0.1:${servidor.puerto}';
  stdout.writeln('Axios — interfaz gráfica en $url');
  stdout.writeln('Ctrl+C para salir.');

  if (abrir) {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {
      // Si no se puede abrir solo, el usuario copia la dirección.
    }
  }

  ProcessSignal.sigint.watch().listen((_) async {
    await servidor.detener();
    axios.cerrar();
    exit(0);
  });
}
