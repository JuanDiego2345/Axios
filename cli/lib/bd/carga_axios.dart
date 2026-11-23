import 'dart:io';
import 'lexico_repo.dart';

/// Resultado de cargar un archivo en el formato oficial de Axios.
class ResultadoAxios {
  /// Señales nuevas (las que ya existían no se cuentan).
  final int senales;

  /// Correcciones del manual que se aplicaron.
  final int correcciones;

  ResultadoAxios(this.senales, this.correcciones);

  int get filas => senales + correcciones;
}

/// Carga de archivos en el formato oficial de Axios:
///
///   # comentario
///   SENAL|dia|voz|transcripcion|salida
///   CORRECCION|lengua|palabra|significado anterior|significado nuevo
extension CargaAxios on LexicoRepo {
  String _hoyAxios() => DateTime.now().toIso8601String().substring(0, 10);

  String _limpiar(String cruda) => cruda.replaceAll('\uFEFF', '').trim();

  /// Indica si el archivo está en el formato de Axios, mirando el tipo de
  /// la primera línea que no sea comentario ni esté vacía.
  bool esFormatoAxios(String ruta) {
    final archivo = File(ruta);
    if (!archivo.existsSync()) return false;

    for (final cruda in archivo.readAsLinesSync()) {
      final linea = _limpiar(cruda);
      if (linea.isEmpty || linea.startsWith('#')) continue;

      final tipo = linea.split('|').first.trim().toUpperCase();
      return tipo == 'SENAL' || tipo == 'CORRECCION';
    }

    return false;
  }

  List<List<String>> _leerAxios(String ruta) {
    final archivo = File(ruta);

    if (!archivo.existsSync()) {
      throw FileSystemException('El archivo no existe', ruta);
    }

    final filas = <List<String>>[];

    for (final cruda in archivo.readAsLinesSync()) {
      final linea = _limpiar(cruda);
      if (linea.isEmpty || linea.startsWith('#')) continue;

      final campos = linea.split('|').map((c) => c.trim()).toList();
      campos[0] = campos[0].toUpperCase();
      filas.add(campos);
    }

    return filas;
  }

  /// Carga un archivo de señales y/o correcciones del manual.
  /// Todo ocurre en una sola transacción: si algo falla, no se guarda nada.
  /// Cargar el mismo archivo dos veces no duplica nada.
  ResultadoAxios cargarAxios(String ruta, {String? fecha}) {
    final hoy = fecha ?? _hoyAxios();
    final filas = _leerAxios(ruta);

    if (filas.isEmpty) {
      throw FormatException(
        'El archivo no contiene señales ni correcciones.',
      );
    }

    var nuevas = 0;
    var aplicadas = 0;

    db.execute('BEGIN');

    try {
      db.execute(
        'INSERT INTO carga (archivo, fecha, filas) VALUES (?, ?, ?)',
        [ruta, hoy, filas.length],
      );

      final cargaId = db.lastInsertRowId;

      for (final f in filas) {
        if (f[0] == 'SENAL') {
          nuevas += _insertarSenal(f, cargaId);
        } else if (f[0] == 'CORRECCION') {
          if (_aplicarCorreccion(f, hoy, ruta)) aplicadas++;
        } else {
          throw FormatException(
            'Tipo de registro desconocido "${f[0]}": ${f.join('|')}',
          );
        }
      }

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return ResultadoAxios(nuevas, aplicadas);
  }

  int _insertarSenal(List<String> f, int cargaId) {
    if (f.length != 5 || f[2].isEmpty || f[4].isEmpty) {
      throw FormatException('Fila inválida en las señales: ${f.join('|')}');
    }

    final dia = int.tryParse(f[1]);

    if (dia == null || dia < 0) {
      throw FormatException('Día inválido en las señales: ${f[1]}');
    }

    // Misma forma que las señales cargadas desde CSV: Kethari, Ozh, ...
    final voz = f[2][0].toUpperCase() + f[2].substring(1).toLowerCase();

    db.execute(
      'INSERT OR IGNORE INTO senal '
      '(dia, voz, transcripcion, salida, carga_id) '
      'VALUES (?, ?, ?, ?, ?)',
      [dia, voz, f[3], f[4], cargaId],
    );

    return db.updatedRows;
  }

  /// Cambia el significado en español de una palabra de Kethari u Ozh.
  /// Cierra la versión vigente y abre una nueva desde la fecha de carga.
  /// Devuelve false si la corrección ya estaba aplicada.
  bool _aplicarCorreccion(List<String> f, String hoy, String ruta) {
    if (f.length != 5 || f.skip(1).any((c) => c.isEmpty)) {
      throw FormatException('Fila inválida en la corrección: ${f.join('|')}');
    }

    final lengua = f[1].toLowerCase();

    if (lengua != 'kethari' && lengua != 'ozh') {
      throw FormatException('Lengua desconocida en la corrección: ${f[1]}');
    }

    final palabra = f[2];
    final anterior = f[3];
    final nuevo = f[4];

    // $lengua solo puede ser 'kethari' u 'ozh' (validado arriba).
    final yaAplicada = db.select(
      'SELECT 1 FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? AND v.$lengua = ? AND v.vigente_hasta IS NULL',
      [nuevo, palabra],
    );

    if (yaAplicada.isNotEmpty) return false;

    final previa = db.select(
      'SELECT v.id AS version_id, v.kethari, v.ozh, v.vigente_desde, '
      'l.id AS lexico_id, l.categoria '
      'FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? AND v.$lengua = ? AND v.vigente_hasta IS NULL',
      [anterior, palabra],
    );

    if (previa.isEmpty) {
      throw FormatException(
        'No existe "$palabra" ($lengua) con el significado "$anterior"; '
        'la corrección no se puede aplicar.',
      );
    }

    final p = previa.first;

    if (hoy.compareTo(p['vigente_desde'] as String) < 0) {
      throw FormatException(
        'La fecha $hoy no puede ser anterior a la versión vigente '
        'de "$palabra".',
      );
    }

    // 1. Cierra el significado anterior.
    db.execute(
      'UPDATE lexico_version SET vigente_hasta = ? WHERE id = ?',
      [hoy, p['version_id']],
    );

    // 2. El significado anterior conserva la palabra de la otra lengua.
    final kOtro = lengua == 'kethari' ? null : p['kethari'] as String?;
    final oOtro = lengua == 'ozh' ? null : p['ozh'] as String?;

    if ((kOtro ?? '').isNotEmpty || (oOtro ?? '').isNotEmpty) {
      db.execute(
        'INSERT INTO lexico_version '
        '(lexico_id, kethari, ozh, vigente_desde, origen) '
        'VALUES (?, ?, ?, ?, ?)',
        [p['lexico_id'], kOtro, oOtro, hoy, ruta],
      );
    }

    // 3. El significado nuevo recibe la palabra desde hoy.
    db.execute(
      'INSERT OR IGNORE INTO lexico (lema_es, categoria) VALUES (?, ?)',
      [nuevo, p['categoria']],
    );

    final nuevoId = db.select(
      'SELECT id FROM lexico WHERE lema_es = ? AND categoria = ?',
      [nuevo, p['categoria']],
    ).first['id'] as int;

    String? k = lengua == 'kethari' ? palabra : null;
    String? o = lengua == 'ozh' ? palabra : null;

    final vigente = db.select(
      'SELECT id, kethari, ozh FROM lexico_version '
      'WHERE lexico_id = ? AND vigente_hasta IS NULL',
      [nuevoId],
    );

    if (vigente.isNotEmpty) {
      // Si el significado nuevo ya tenía palabra en la otra lengua, se conserva.
      if (lengua == 'kethari') o = vigente.first['ozh'] as String?;
      if (lengua == 'ozh') k = vigente.first['kethari'] as String?;

      db.execute(
        'UPDATE lexico_version SET vigente_hasta = ? WHERE id = ?',
        [hoy, vigente.first['id']],
      );
    }

    db.execute(
      'INSERT INTO lexico_version '
      '(lexico_id, kethari, ozh, vigente_desde, origen) '
      'VALUES (?, ?, ?, ?, ?)',
      [nuevoId, k, o, hoy, ruta],
    );

    return true;
  }
}