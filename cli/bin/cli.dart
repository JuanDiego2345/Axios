import 'dart:io';
import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';
import 'package:cli/generadores.dart';

void main(List<String> args) {
  final config = ConfiguracionCli.parse(args);

  if (config.mostrarAyuda) {
    _imprimirAyuda();
    return;
  }

  // 1. Localizar la carpeta de datos
  final rutaDatos = _resolverRutaDatos();
  if (rutaDatos == null) {
    stderr.writeln('Error: No se encontró la carpeta "datos" con el léxico y gramática.');
    exit(1);
  }

  // 2. Inicializar los servicios del pipeline
  final fuenteEspanol = FuenteLexicoJson('$rutaDatos/espanol');
  final parser = AnalizadorSintactico.desde(fuenteEspanol);
  final lexico = FaseLexica(parser.vocabulario);
  final kethari = GeneradorKethari(FuenteKethariJson('$rutaDatos/kethari'));

  // 3. Ejecutar modo según argumentos
  if (config.textoDirecto != null && config.textoDirecto!.isNotEmpty) {
    _procesarEntrada(
      entrada: config.textoDirecto!,
      lexico: lexico,
      parser: parser,
      kethari: kethari,
      mostrarTraza: config.mostrarTraza,
      mostrarArbol: config.mostrarArbol,
      mostrarTokens: config.mostrarTokens,
    );
  } else {
    _iniciarModoInteractivo(
      lexico: lexico,
      parser: parser,
      kethari: kethari,
      configInicial: config,
    );
  }
}

/// Pipeline completo de traducción
void _procesarEntrada({
  required String entrada,
  required FaseLexica lexico,
  required AnalizadorSintactico parser,
  required GeneradorKethari kethari,
  required bool mostrarTraza,
  required bool mostrarArbol,
  required bool mostrarTokens,
}) {
  stdout.writeln('\n----------------------------------------');
  stdout.writeln('Entrada: "$entrada"');

  // --- FASE 1: LÉXICO ---
  final resLexico = lexico.procesar(entrada);

  if (mostrarTokens) {
    stdout.writeln('\n[Tokens Léxicos]');
    for (final tok in resLexico.tokens) {
      final extra = tok.valor != null ? ' (valor: ${tok.valor})' : '';
      stdout.writeln('  • ${tok.tipo.name.padRight(20)} : "${tok.lexema}" (columna: ${tok.columna})$extra');
    }
  }

  if (resLexico.correcciones.isNotEmpty) {
    stdout.writeln('\n[Correcciones aplicadas]');
    for (final c in resLexico.correcciones) {
      stdout.writeln('  • "${c.original}" -> "${c.corregida}" (distancia: ${c.distancia})');
    }
  }

  // --- FASE 2: SINTÁCTICO ---
  final resSintactico = parser.analizar(resLexico.tokens, conTraza: mostrarTraza);

  if (mostrarTraza && resSintactico.traza.isNotEmpty) {
    stdout.writeln('\n[Traza Sintáctica]');
    for (final paso in resSintactico.traza) {
      stdout.writeln('  $paso');
    }
  }

  if (resSintactico.error != null) {
    stderr.writeln('\n[Error Sintáctico]: ${resSintactico.error!.mensaje}');
    return;
  }

  final arbol = resSintactico.arbol;
  if (arbol == null) {
    stderr.writeln('\n[Error]: No se pudo generar el árbol sintáctico.');
    return;
  }

  if (resSintactico.advertencias.isNotEmpty) {
    stdout.writeln('\n[Advertencias Sintácticas]');
    for (final adv in resSintactico.advertencias) {
      stdout.writeln('  • $adv');
    }
  }

  if (mostrarArbol) {
    stdout.writeln('\n[Árbol Sintáctico Intermedio]');
    stdout.writeln(arbol.dibujar());
  }

  // --- FASE 3: GENERADOR (KETHARI) ---
  final resGeneracion = kethari.generar(arbol);

  if (mostrarTraza && resGeneracion.traza.isNotEmpty) {
    stdout.writeln('\n[Traza de Generación]');
    for (final paso in resGeneracion.traza) {
      stdout.writeln('  $paso');
    }
  }

  stdout.writeln('\n========================================');
  if (resGeneracion.ok) {
    stdout.writeln('Traducción (Kethari): ${resGeneracion.texto}');
  } else {
    stderr.writeln('No se pudo traducir: ${resGeneracion.error}');
  }
  stdout.writeln('========================================\n');
}

/// Modo consola REPL
void _iniciarModoInteractivo({
  required FaseLexica lexico,
  required AnalizadorSintactico parser,
  required GeneradorKethari kethari,
  required ConfiguracionCli configInicial,
}) {
  bool traza = configInicial.mostrarTraza;
  bool arbol = configInicial.mostrarArbol;
  bool tokens = configInicial.mostrarTokens;

  stdout.writeln('====================================================');
  stdout.writeln('  AXIOS - Traductor Interespecie (Kethari / Español)');
  stdout.writeln('====================================================');
  stdout.writeln('Escribe una frase en español o usa un comando:');
  stdout.writeln('  :traza    Activa/desactiva traza (actual: $traza)');
  stdout.writeln('  :arbol    Activa/desactiva dibujo del árbol (actual: $arbol)');
  stdout.writeln('  :tokens   Activa/desactiva tokens léxicos (actual: $tokens)');
  stdout.writeln('  :ayuda    Muestra la ayuda');
  stdout.writeln('  :salir    Finaliza el programa');
  stdout.writeln('----------------------------------------------------');

  while (true) {
    stdout.write('axios> ');
    final linea = stdin.readLineSync();
    if (linea == null) break;

    final input = linea.trim();
    if (input.isEmpty) continue;

    // Comandos de control
    if (input == ':salir' || input == ':q') {
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
    } else if (input == ':ayuda') {
      _imprimirAyuda();
    } else {
      _procesarEntrada(
        entrada: input,
        lexico: lexico,
        parser: parser,
        kethari: kethari,
        mostrarTraza: traza,
        mostrarArbol: arbol,
        mostrarTokens: tokens,
      );
    }
  }
}

/// Opciones de configuración leídas de la línea de comandos
class ConfiguracionCli {
  final bool mostrarAyuda;
  final bool mostrarTraza;
  final bool mostrarArbol;
  final bool mostrarTokens;
  final String? destino;
  final String? textoDirecto;

  ConfiguracionCli({
    this.mostrarAyuda = false,
    this.mostrarTraza = false,
    this.mostrarArbol = false,
    this.mostrarTokens = false,
    this.destino,
    this.textoDirecto,
  });

  factory ConfiguracionCli.parse(List<String> args) {
    bool ayuda = false;
    bool traza = false;
    bool arbol = false;
    bool tokens = false;
    String? destino = 'kethari';
    final textoPartes = <String>[];

    for (int i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '-h' || a == '--help' || a == '--ayuda') {
        ayuda = true;
      } else if (a == '-t' || a == '--traza') {
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

    return ConfiguracionCli(
      mostrarAyuda: ayuda,
      mostrarTraza: traza,
      mostrarArbol: arbol,
      mostrarTokens: tokens,
      destino: destino,
      textoDirecto: textoPartes.isEmpty ? null : textoPartes.join(' '),
    );
  }
}

/// Resuelve la ruta relativa hacia `datos/`
String? _resolverRutaDatos() {
  const opciones = ['datos', 'cli/datos', '../cli/datos'];
  for (final ruta in opciones) {
    if (Directory('$ruta/espanol').existsSync() && Directory('$ruta/kethari').existsSync()) {
      return ruta;
    }
  }
  return null;
}

void _imprimirAyuda() {
  stdout.writeln('''
Uso: dart run bin/cli.dart [opciones] ["oración en español"]

Opciones:
  -t, --traza      Muestra el paso a paso léxico, sintáctico y de generación.
  -a, --arbol      Muestra la representación visual del árbol sintáctico intermedio.
  --tokens         Muestra la lista de tokens generada por el analizador léxico.
  -d, --destino    Lengua alienígena destino (por defecto: kethari).
  -h, --help       Muestra este mensaje de ayuda.

Si no se pasa ninguna oración, se inicia la consola interactiva (REPL).
''');
}