/// Biblioteca principal del CLI de Axios.
///
/// Expone el orquestador [AxiosCli], los comandos obligatorios y los
/// resultados de ejecución.
library;

import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

import 'bd.dart';
import 'generadores.dart';
import 'lexico.dart';
import 'sintactico.dart';

export 'bd.dart';
export 'generadores.dart';
export 'lexico.dart';
export 'sintactico.dart';

/// Resultado del pipeline de traducción a ambas lenguas.
class ResultadoTraducir {
  final String entrada;
  final ResultadoLexico resultadoLexico;
  final ResultadoSintactico resultadoSintactico;
  final ResultadoKethari? resultadoKethari;
  final ResultadoOzh? resultadoOzh;
  final int? idHistorial;

  ResultadoTraducir({
    required this.entrada,
    required this.resultadoLexico,
    required this.resultadoSintactico,
    this.resultadoKethari,
    this.resultadoOzh,
    this.idHistorial,
  });

  bool get exitoso =>
      resultadoSintactico.error == null &&
      (resultadoKethari?.ok == true || resultadoOzh?.ok == true);

  String? get traduccionKethari => resultadoKethari?.texto;
  String? get traduccionOzh => resultadoOzh?.texto;
  String? get traduccion => traduccionKethari ?? traduccionOzh;
  String? get error =>
      resultadoSintactico.error?.mensaje ??
      resultadoKethari?.error ??
      resultadoOzh?.error;
  Oracion? get arbol => resultadoSintactico.arbol;
}

/// Resultado de la carga de un archivo de datos.
class ResultadoCargar {
  final String archivo;
  final String tipo;
  final int filas;

  ResultadoCargar({
    required this.archivo,
    required this.tipo,
    required this.filas,
  });
}

/// Orquestador central de Axios para la interfaz por línea de comandos.
///
/// Integra la base de datos (con historial de preguntas persistente),
/// el módulo léxico, el analizador sintáctico y los generadores de Kethari y Ozh.
class AxiosCli {
  final Database db;
  final LexicoRepo lexicoRepo;
  final AnalizadorSintactico parser;
  final FaseLexica lexico;
  final GeneradorKethari generadorKethari;
  final GeneradorOzh generadorOzh;

  AxiosCli({
    required this.db,
    required this.lexicoRepo,
    required this.parser,
    required this.lexico,
    required this.generadorKethari,
    required this.generadorOzh,
  });

  /// Crea una instancia de [AxiosCli] resolviendo los archivos de datos y
  /// abriendo la base de datos SQLite en [rutaBd] (o en memoria para tests).
  factory AxiosCli.crear({
    String? rutaDatos,
    String? rutaBd,
    Database? dbCustom,
  }) {
    final datos = rutaDatos ?? _resolverRutaDatos() ?? 'datos';
    final db = dbCustom ?? abrirBd(rutaBd ?? '$datos/axios.db');

    final lexicoRepo = LexicoRepo(db);

    final fuenteEspanol = FuenteLexicoJson('$datos/espanol');
    final parser = AnalizadorSintactico.desde(fuenteEspanol);
    final lexico = FaseLexica(parser.vocabulario);
    // El léxico de Kethari y Ozh se lee de la BD: lo que entra con `cargar`
    // se usa en la traducción siguiente (bitácora K-11).
    final generadorKethari = GeneradorKethari(
        FuenteKethariBd(db, fuenteEspanol, carpeta: '$datos/kethari'));
    final generadorOzh =
        GeneradorOzh(FuenteOzhBd(db, fuenteEspanol, carpeta: '$datos/ozh'));

    return AxiosCli(
      db: db,
      lexicoRepo: lexicoRepo,
      parser: parser,
      lexico: lexico,
      generadorKethari: generadorKethari,
      generadorOzh: generadorOzh,
    );
  }

  /// 1. Orden obligatoria: `traducir "<pregunta>"`
  ///
  /// Traduce SIEMPRE a ambas lenguas (Kethari y Ozh) según lo exige el enunciado
  /// y REGISTRA la pregunta en la tabla `pregunta` de la base de datos con
  /// validación "sin validar" mientras no exista un componente validador.
  ResultadoTraducir traducir(
    String pregunta, {
    bool conTraza = false,
  }) {
    // 1. Fase léxica
    final resLex = lexico.procesar(pregunta);

    // 2. Fase sintáctica
    final resSint = parser.analizar(resLex.tokens, conTraza: conTraza);

    ResultadoKethari? resKethari;
    ResultadoOzh? resOzh;

    if (resSint.arbol != null) {
      resKethari = generadorKethari.generar(resSint.arbol!);
      resOzh = generadorOzh.generar(resSint.arbol!);
    }

    // 3. Persistencia en la Base de Datos (Axios exige que ninguna pregunta se pierda)
    // Sin validador activo, se guarda como "sin validar" si la sintaxis fue correcta
    final validacionTexto = resSint.arbol != null ? 'sin validar' : 'error sintáctico';

    // Determinar texto corregido si hubo correcciones ortográficas
    final textoCorregido = resLex.correcciones.isNotEmpty
        ? resLex.tokens
            .where((t) => t.tipo == TipoToken.palabra || t.tipo == TipoToken.numero)
            .map((t) => t.lexema)
            .join(' ')
        : null;

    final id = lexicoRepo.registrarPregunta(
      original: pregunta,
      corregido: textoCorregido,
      kethari: resKethari?.ok == true ? resKethari!.texto : null,
      ozh: resOzh?.ok == true ? resOzh!.texto : null,
      validacion: validacionTexto,
    );

    return ResultadoTraducir(
      entrada: pregunta,
      resultadoLexico: resLex,
      resultadoSintactico: resSint,
      resultadoKethari: resKethari,
      resultadoOzh: resOzh,
      idHistorial: id,
    );
  }

  /// 2. Orden obligatoria: `cargar <archivo>`
  ///
  /// Carga archivos CSV de léxico o señales en la base de datos con versionamiento.
  /// También acepta el formato oficial de Axios (SENAL|... y CORRECCION|...).
  ResultadoCargar cargar(String rutaArchivo) {
    // Quitar comillas si las tiene
    var rutaLimpia = rutaArchivo.trim();
    if ((rutaLimpia.startsWith('"') && rutaLimpia.endsWith('"')) ||
        (rutaLimpia.startsWith("'") && rutaLimpia.endsWith("'"))) {
      rutaLimpia = rutaLimpia.substring(1, rutaLimpia.length - 1).trim();
    }

    var archivo = File(rutaLimpia);
    if (!archivo.existsSync()) {
      // Buscar en ubicaciones relativas comunes y por nombre de archivo
      final nombre = rutaLimpia.split(RegExp(r'[/\\]')).last;
      final posibles = [
        'cli/$rutaLimpia',
        'datos/$rutaLimpia',
        'cli/datos/$rutaLimpia',
        'datos/$nombre',
        'cli/datos/$nombre',
        '../cli/datos/$nombre',
      ];
      for (final p in posibles) {
        if (File(p).existsSync()) {
          archivo = File(p);
          rutaLimpia = p;
          break;
        }
      }
    }

    if (!archivo.existsSync()) {
      throw FileSystemException('No se encontró el archivo a cargar', rutaArchivo);
    }

    // Formato oficial de Axios: SENAL|... y CORRECCION|...
    if (lexicoRepo.esFormatoAxios(rutaLimpia)) {
      final r = lexicoRepo.cargarAxios(rutaLimpia);
      return ResultadoCargar(
        archivo: rutaLimpia,
        tipo: 'señales y correcciones del manual',
        filas: r.filas,
      );
    }

    final lineas = archivo.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    if (lineas.isEmpty) {
      throw FormatException('El archivo está vacío: $rutaArchivo');
    }

    final encabezado = lineas.first.toLowerCase();
    int filasCargadas = 0;
    String tipo = '';

    if (encabezado.contains('lema_es') || encabezado.contains('categoria')) {
      filasCargadas = lexicoRepo.cargarLexico(rutaLimpia);
      tipo = 'léxico';
    } else if (encabezado.contains('dia') || encabezado.contains('transcripcion') || encabezado.contains('salida')) {
      filasCargadas = lexicoRepo.cargarSenales(rutaLimpia);
      tipo = 'señales';
    } else {
      filasCargadas = lexicoRepo.cargarLexico(rutaLimpia);
      tipo = 'léxico (inferido)';
    }

    return ResultadoCargar(
      archivo: rutaLimpia,
      tipo: tipo,
      filas: filasCargadas,
    );
  }

  /// 3. Orden obligatoria: `historial [desde <fecha>]`
  ///
  /// Consulta las preguntas registradas en la base de datos.
  List<Map<String, dynamic>> historial({String? desde}) {
    return lexicoRepo.historialPreguntas(desde: desde);
  }

  /// 4. Orden obligatoria: `palabra <término>`
  ///
  /// Busca un término en el léxico de la base de datos.
  Traduccion? palabra(String termino, {String? fecha}) {
    return lexicoRepo.buscar(termino, fecha: fecha);
  }

  void cerrar() {
    db.close();
  }

  static String? _resolverRutaDatos() {
    const opciones = ['datos', 'cli/datos', '../cli/datos'];
    for (final ruta in opciones) {
      if (Directory('$ruta/espanol').existsSync() &&
          Directory('$ruta/kethari').existsSync()) {
        return ruta;
      }
    }
    return null;
  }
}
