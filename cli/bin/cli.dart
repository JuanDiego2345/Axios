import 'dart:io';
import 'package:cli/cli.dart';

void main(List<String> args) {
  // Inicializar orquestador central con base de datos e interfaces
  final AxiosCli axios;
  try {
    axios = AxiosCli.crear();
  } catch (e) {
    stderr.writeln('Error al inicializar Axios: $e');
    exit(1);
  }

  try {
    if (args.isEmpty) {
      _iniciarModoInteractivo(axios);
    } else {
      _ejecutarComandoLinea(args, axios);
    }
  } finally {
    axios.cerrar();
  }
}

/// Ejecuta un comando pasado directamente por argumentos en la terminal.
void _ejecutarComandoLinea(List<String> args, AxiosCli axios) {
  final primerArg = args[0].toLowerCase();

  if (primerArg == '-h' || primerArg == '--help' || primerArg == 'ayuda') {
    _imprimirAyuda();
    return;
  }

  if (primerArg == 'traducir') {
    _manejarComandoTraducir(args.sublist(1), axios);
  } else if (primerArg == 'cargar') {
    if (args.length < 2) {
      stderr.writeln('Uso: cargar <archivo>');
      exit(1);
    }
    _manejarComandoCargar(args[1], axios);
  } else if (primerArg == 'historial') {
    String? desde;
    if (args.length >= 3 && args[1].toLowerCase() == 'desde') {
      desde = args[2];
    } else if (args.length >= 2) {
      desde = args[1];
    }
    _manejarComandoHistorial(desde, axios);
  } else if (primerArg == 'palabra') {
    if (args.length < 2) {
      stderr.writeln('Uso: palabra <término>');
      exit(1);
    }
    _manejarComandoPalabra(args[1], axios);
  } else {
    // Si no es una palabra clave, se asume traducción directa de la frase
    _manejarComandoTraducir(args, axios);
  }
}

/// Consola interactiva (REPL)
void _iniciarModoInteractivo(AxiosCli axios) {
  bool traza = false;
  bool arbol = false;
  bool tokens = false;

  stdout.writeln('====================================================');
  stdout.writeln('  AXIOS - Sistema de Comunicación Interespecie');
  stdout.writeln('====================================================');
  stdout.writeln('Órdenes obligatorias:');
  stdout.writeln('  traducir "<pregunta>"   Traduce y registra en la BD');
  stdout.writeln('  cargar <archivo>        Carga CSV a la base de datos');
  stdout.writeln('  historial [desde <f>]   Lista el registro de preguntas');
  stdout.writeln('  palabra <término>       Consulta un lema en el léxico');
  stdout.writeln('Opciones de consola:');
  stdout.writeln('  :traza | :arbol | :tokens | ayuda | salir');
  stdout.writeln('----------------------------------------------------');

  while (true) {
    stdout.write('axios> ');
    final linea = stdin.readLineSync();
    if (linea == null) break;

    final input = linea.trim();
    if (input.isEmpty) continue;

    if (input == 'salir' || input == ':salir' || input == ':q' || input == 'exit') {
      stdout.writeln('Cerrando sesión de Axios.');
      break;
    } else if (input == ':traza') {
      traza = !traza;
      stdout.writeln('Modo traza: ${traza ? "ACTIVADO" : "DESACTIVADO"}');
    } else if (input == ':arbol') {
      arbol = !arbol;
      stdout.writeln('Dibujo de árbol: ${arbol ? "ACTIVADO" : "DESACTIVADO"}');
    } else if (input == ':tokens') {
      tokens = !tokens;
      stdout.writeln('Visualización de tokens: ${tokens ? "ACTIVADA" : "DESACTIVADA"}');
    } else if (input == 'ayuda' || input == ':ayuda') {
      _imprimirAyuda();
    } else {
      final partes = _dividirComando(input);
      final orden = partes.first.toLowerCase();

      if (orden == 'traducir') {
        _manejarComandoTraducir(
          partes.sublist(1),
          axios,
          trazaPorDefecto: traza,
          arbolPorDefecto: arbol,
          tokensPorDefecto: tokens,
        );
      } else if (orden == 'cargar') {
        if (partes.length < 2) {
          stdout.writeln('Uso: cargar <archivo>');
        } else {
          _manejarComandoCargar(partes[1], axios);
        }
      } else if (orden == 'historial') {
        String? desde;
        if (partes.length >= 3 && partes[1].toLowerCase() == 'desde') {
          desde = partes[2];
        } else if (partes.length >= 2) {
          desde = partes[1];
        }
        _manejarComandoHistorial(desde, axios);
      } else if (orden == 'palabra') {
        if (partes.length < 2) {
          stdout.writeln('Uso: palabra <término>');
        } else {
          _manejarComandoPalabra(partes[1], axios);
        }
      } else {
        // Frase directa
        _manejarComandoTraducir(
          partes,
          axios,
          trazaPorDefecto: traza,
          arbolPorDefecto: arbol,
          tokensPorDefecto: tokens,
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------
// MANEJADORES DE LAS CUATRO ÓRDENES OBLIGATORIAS
// -----------------------------------------------------------------------------

void _manejarComandoTraducir(
  List<String> args,
  AxiosCli axios, {
  bool trazaPorDefecto = false,
  bool arbolPorDefecto = false,
  bool tokensPorDefecto = false,
}) {
  bool traza = trazaPorDefecto;
  bool arbol = arbolPorDefecto;
  bool tokens = tokensPorDefecto;
  String destino = 'kethari';
  final textoPartes = <String>[];

  for (int i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '-t' || a == '--traza') {
      traza = true;
    } else if (a == '-a' || a == '--arbol') {
      arbol = true;
    } else if (a == '--tokens') {
      tokens = true;
    } else if (a == '-d' || a == '--destino') {
      if (i + 1 < args.length) {
        destino = args[++i];
      }
    } else {
      textoPartes.add(a);
    }
  }

  String frase = textoPartes.join(' ').trim();
  // Quitar comillas si el usuario las incluyó explícitamente
  if ((frase.startsWith('"') && frase.endsWith('"')) ||
      (frase.startsWith("'") && frase.endsWith("'"))) {
    frase = frase.substring(1, frase.length - 1).trim();
  }

  if (frase.isEmpty) {
    stderr.writeln('Error: Falta la pregunta a traducir.');
    stderr.writeln('Uso: traducir "<pregunta>" [-t] [-a] [--tokens] [-d kethari]');
    return;
  }

  stdout.writeln('\n----------------------------------------');
  stdout.writeln('Pregunta: "$frase"');

  final r = axios.traducir(frase, conTraza: traza, destino: destino);

  if (tokens) {
    stdout.writeln('\n[Tokens Léxicos]');
    for (final tok in r.resultadoLexico.tokens) {
      final extra = tok.valor != null ? ' (valor: ${tok.valor})' : '';
      stdout.writeln('  • ${tok.tipo.name.padRight(20)} : "${tok.lexema}" (columna: ${tok.columna})$extra');
    }
  }

  if (r.resultadoLexico.correcciones.isNotEmpty) {
    stdout.writeln('\n[Correcciones ortográficas]');
    for (final c in r.resultadoLexico.correcciones) {
      stdout.writeln('  • "${c.original}" -> "${c.corregida}" (distancia: ${c.distancia})');
    }
  }

  if (traza && r.resultadoSintactico.traza.isNotEmpty) {
    stdout.writeln('\n[Traza Sintáctica]');
    for (final paso in r.resultadoSintactico.traza) {
      stdout.writeln('  $paso');
    }
  }

  if (r.resultadoSintactico.advertencias.isNotEmpty) {
    stdout.writeln('\n[Advertencias Sintácticas]');
    for (final adv in r.resultadoSintactico.advertencias) {
      stdout.writeln('  • $adv');
    }
  }

  if (arbol && r.arbol != null) {
    stdout.writeln('\n[Árbol Sintáctico Intermedio]');
    stdout.writeln(r.arbol!.dibujar());
  }

  if (traza && r.resultadoGeneracion != null && r.resultadoGeneracion!.traza.isNotEmpty) {
    stdout.writeln('\n[Traza de Generación]');
    for (final paso in r.resultadoGeneracion!.traza) {
      stdout.writeln('  $paso');
    }
  }

  stdout.writeln('\n========================================');
  if (r.exitoso) {
    stdout.writeln('Traducción ($destino): ${r.traduccion}');
  } else {
    stderr.writeln('No se pudo traducir: ${r.error}');
  }
  stdout.writeln('========================================');
  stdout.writeln('[Pregunta registrada en BD - ID: ${r.idHistorial}]\n');
}

void _manejarComandoCargar(String rutaArchivo, AxiosCli axios) {
  try {
    final r = axios.cargar(rutaArchivo);
    stdout.writeln('[OK] Se cargaron ${r.filas} filas de ${r.tipo} desde "${r.archivo}".');
  } catch (e) {
    stderr.writeln('Error al cargar archivo: $e');
  }
}

void _manejarComandoHistorial(String? desde, AxiosCli axios) {
  final lista = axios.historial(desde: desde);
  final filtro = desde != null ? ' (desde $desde)' : '';

  if (lista.isEmpty) {
    stdout.writeln('\nNo hay registros en el historial$filtro.\n');
    return;
  }

  stdout.writeln('\n================================================================================');
  stdout.writeln(' HISTORIAL DE PREGUNTAS$filtro');
  stdout.writeln('================================================================================');
  for (final h in lista) {
    final id = h['id'];
    final fechaRaw = h['fecha'] as String? ?? '';
    final fecha = fechaRaw.length >= 19 ? fechaRaw.substring(0, 19) : fechaRaw;
    final validacion = h['validacion'] ?? '';
    final kethari = h['kethari'];
    final ozh = h['ozh'];

    stdout.writeln('#${id.toString().padRight(4)} | $fecha | $validacion');
    stdout.writeln('  Pregunta:   "${h['original']}"');
    if (h['corregido'] != null && h['corregido'] != h['original']) {
      stdout.writeln('  Corregido:  "${h['corregido']}"');
    }
    if (kethari != null) {
      stdout.writeln('  Kethari:    $kethari');
    }
    if (ozh != null) {
      stdout.writeln('  Ozh:        $ozh');
    }
    stdout.writeln('--------------------------------------------------------------------------------');
  }
  stdout.writeln('Total: ${lista.length} registro(s).\n');
}

void _manejarComandoPalabra(String termino, AxiosCli axios) {
  final t = axios.palabra(termino);
  if (t == null) {
    stdout.writeln('\nNo se encontró el término "$termino" en el léxico de la base de datos.\n');
    return;
  }

  stdout.writeln('\n[Léxico BD]');
  stdout.writeln('  Lema:       ${t.lema}');
  stdout.writeln('  Categoría:  ${t.categoria}');
  stdout.writeln('  Kethari:    ${t.kethari ?? "(sin traducción)"}');
  stdout.writeln('  Ozh:        ${t.ozh ?? "(sin traducción)"}\n');
}

void _imprimirAyuda() {
  stdout.writeln('''
AXIOS CLI - Manual de Uso

Órdenes obligatorias:
  traducir "<pregunta>"   Traduce una oración en español a lengua alienígena.
                          Opciones:
                            -t, --traza     Muestra las decisiones tomadas paso a paso.
                            -a, --arbol     Muestra el árbol sintáctico en ASCII.
                            --tokens        Muestra los tokens léxicos y columnas.
                            -d, --destino   Lengua alienígena (por defecto: kethari).
                          Nota: Axios registra CADA pregunta procesada en la BD.

  cargar <archivo>        Carga un archivo CSV de léxico o señales en la base
                          de datos SQLite con control de versiones.

  historial [desde <f>]   Lista las preguntas registradas en la base de datos.
                          Ejemplo: historial desde 2026-11-01

  palabra <término>       Busca un lema en el repositorio léxico de la base
                          de datos y muestra su categoría y traducciones.

Consola interactiva:
  Ejecutar sin argumentos abre la consola interactiva (REPL).
  Comandos en consola: :traza, :arbol, :tokens, ayuda, salir.
''');
}

/// Divide una línea respetando comillas
List<String> _dividirComando(String linea) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  bool dentroComillas = false;
  String comilla = '';

  for (int i = 0; i < linea.length; i++) {
    final char = linea[i];
    if ((char == '"' || char == "'") && !dentroComillas) {
      dentroComillas = true;
      comilla = char;
    } else if (char == comilla && dentroComillas) {
      dentroComillas = false;
      comilla = '';
    } else if (char == ' ' && !dentroComillas) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(char);
    }
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }

  return tokens;
}
