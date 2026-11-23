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

/// Resultado del pipeline de traducción.
class ResultadoTraducir {
  final String entrada;
  final ResultadoLexico resultadoLexico;
  final ResultadoSintactico resultadoSintactico;
  final ResultadoKethari? resultadoGeneracion;
  final int? idHistorial;
  final String destino;

  ResultadoTraducir({
    required this.entrada,
    required this.resultadoLexico,
    required this.resultadoSintactico,
    this.resultadoGeneracion,
    this.idHistorial,
    required this.destino,
  });

  bool get exitoso =>
      resultadoSintactico.error == null &&
      resultadoGeneracion != null &&
      resultadoGeneracion!.ok;

  String? get traduccion => resultadoGeneracion?.texto;
  String? get error => resultadoSintactico.error?.mensaje ?? resultadoGeneracion?.error;
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
/// el módulo léxico, el analizador sintáctico y los generadores.
class AxiosCli {
  final Database db;
  final LexicoRepo lexicoRepo;
  final AnalizadorSintactico parser;
  final FaseLexica lexico;
  final GeneradorKethari generadorKethari;

  AxiosCli({
    required this.db,
    required this.lexicoRepo,
    required this.parser,
    required this.lexico,
    required this.generadorKethari,
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
    final generadorKethari = GeneradorKethari(FuenteKethariJson('$datos/kethari'));

    return AxiosCli(
      db: db,
      lexicoRepo: lexicoRepo,
      parser: parser,
      lexico: lexico,
      generadorKethari: generadorKethari,
    );
  }

  /// 1. Orden obligatoria: `traducir "<pregunta>"`
  ///
  /// Ejecuta el pipeline completo y REGISTRA la pregunta en la tabla `pregunta`
  /// de la base de datos para que ninguna pregunta se pierda (Axios).
  ResultadoTraducir traducir(
    String pregunta, {
    bool conTraza = false,
    String destino = 'kethari',
  }) {
    // 1. Fase léxica
    final resLex = lexico.procesar(pregunta);

    // 2. Fase sintáctica
    final resSint = parser.analizar(resLex.tokens, conTraza: conTraza);

    ResultadoKethari? resGen;
    if (resSint.arbol != null) {
      if (destino.toLowerCase() == 'kethari') {
        resGen = generadorKethari.generar(resSint.arbol!);
      } else {
        resGen = ResultadoKethari.fallo(
          'Generador para "$destino" aún no implementado',
        );
      }
    }

    // 3. Persistencia en la Base de Datos (Axios exige que ninguna pregunta se pierda)
    final traduccionTexto = resGen?.ok == true ? resGen!.texto : null;
    final validacionTexto = resSint.arbol != null
        ? (resGen?.ok == true ? 'válida' : 'error de generación')
        : 'error sintáctico';

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
      kethari: destino.toLowerCase() == 'kethari' ? traduccionTexto : null,
      ozh: destino.toLowerCase() == 'ozh' ? traduccionTexto : null,
      validacion: validacionTexto,
    );

    return ResultadoTraducir(
      entrada: pregunta,
      resultadoLexico: resLex,
      resultadoSintactico: resSint,
      resultadoGeneracion: resGen,
      idHistorial: id,
      destino: destino,
    );
  }

  /// 2. Orden obligatoria: `cargar <archivo>`
  ///
  /// Carga archivos CSV de léxico o señales en la base de datos con versionamiento.
  /// También acepta el formato oficial de Axios (SENAL|... y CORRECCION|...).
  ResultadoCargar cargar(String rutaArchivo) {
    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) {
      throw FileSystemException('No se encontró el archivo a cargar', rutaArchivo);
    }

    // Formato oficial de Axios: SENAL|... y CORRECCION|...
    if (lexicoRepo.esFormatoAxios(rutaArchivo)) {
      final r = lexicoRepo.cargarAxios(rutaArchivo);
      return ResultadoCargar(
        archivo: rutaArchivo,
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
      filasCargadas = lexicoRepo.cargarLexico(rutaArchivo);
      tipo = 'léxico';
    } else if (encabezado.contains('dia') || encabezado.contains('transcripcion') || encabezado.contains('salida')) {
      filasCargadas = lexicoRepo.cargarSenales(rutaArchivo);
      tipo = 'señales';
    } else {
      filasCargadas = lexicoRepo.cargarLexico(rutaArchivo);
      tipo = 'léxico (inferido)';
    }

    return ResultadoCargar(
      archivo: rutaArchivo,
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
