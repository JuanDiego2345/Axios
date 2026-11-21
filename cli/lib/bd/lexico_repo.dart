
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class Traduccion {
  final String lema;
  final String categoria;
  final String? kethari;
  final String? ozh;

  Traduccion(this.lema, this.categoria, this.kethari, this.ozh);
}

class LexicoRepo {
  final Database db;

  LexicoRepo(this.db);

  String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  // Lee un archivo CSV respetando las comillas y las columnas.
  List<List<String>> _leerCsv(String ruta, {int? columnas}) {
    final archivo = File(ruta);

    if (!archivo.existsSync()) {
      throw FileSystemException('El archivo no existe', ruta);
    }

    final lineas = archivo.readAsLinesSync();

    if (lineas.isEmpty) {
      throw FormatException('El archivo CSV está vacío: $ruta');
    }

    final filas = <List<String>>[];

    for (final linea in lineas.skip(1)) {
      if (linea.trim().isEmpty) continue;

      final campos = _partir(linea);

      if (columnas != null && campos.length != columnas) {
        throw FormatException(
          'Se esperaban $columnas columnas, '
          'pero se encontraron ${campos.length}: $linea',
        );
      }

      filas.add(campos);
    }

    return filas;
  }

  // Separa los campos CSV respetando las comillas.
  List<String> _partir(String linea) {
    final campos = <String>[];
    final buffer = StringBuffer();
    bool entreComillas = false;

    for (int i = 0; i < linea.length; i++) {
      final caracter = linea[i];

      if (caracter == '"') {
        if (entreComillas &&
            i + 1 < linea.length &&
            linea[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          entreComillas = !entreComillas;
        }
      } else if (caracter == ',' && !entreComillas) {
        campos.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(caracter);
      }
    }

    if (entreComillas) {
      throw FormatException('CSV con comillas sin cerrar: $linea');
    }

    campos.add(buffer.toString().trim());

    return campos;
  }

  // Carga el léxico y conserva las versiones anteriores.
  int cargarLexico(String ruta, {String? fecha}) {
    final hoy = fecha ?? _hoy();
    final filas = _leerCsv(ruta);

    if (filas.isEmpty) {
      throw FormatException('El léxico no contiene datos.');
    }

    db.execute('BEGIN');

    try {
      for (final f in filas) {
        if (f.length != 4 || f[0].isEmpty || f[1].isEmpty) {
          throw FormatException('Fila inválida en el léxico: $f');
        }

        final lema = f[0];
        final cat = f[1];
        final k = f[2];
        final o = f[3];

        db.execute(
          'INSERT OR IGNORE INTO lexico (lema_es, categoria) VALUES (?, ?)',
          [lema, cat],
        );

        final id = db.select(
          'SELECT id FROM lexico WHERE lema_es = ? AND categoria = ?',
          [lema, cat],
        ).first['id'] as int;

        final vigente = db.select(
          'SELECT id, kethari, ozh, vigente_desde '
          'FROM lexico_version '
          'WHERE lexico_id = ? AND vigente_hasta IS NULL',
          [id],
        );

        if (vigente.isNotEmpty) {
          final actual = vigente.first;

          if (actual['kethari'] == k && actual['ozh'] == o) {
            continue;
          }

          final fechaActual = actual['vigente_desde'] as String;

          if (hoy.compareTo(fechaActual) < 0) {
            throw FormatException(
              'La fecha $hoy no puede ser anterior '
              'a la versión vigente de "$lema".',
            );
          }

          db.execute(
            'UPDATE lexico_version SET vigente_hasta = ? '
            'WHERE id = ?',
            [hoy, actual['id']],
          );
        }

        db.execute(
          'INSERT INTO lexico_version '
          '(lexico_id, kethari, ozh, vigente_desde, origen) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, k, o, hoy, ruta],
        );
      }

      db.execute(
        'INSERT INTO carga (archivo, fecha, filas) VALUES (?, ?, ?)',
        [ruta, hoy, filas.length],
      );

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return filas.length;
  }

  // Carga señales sin repetir registros existentes.
  int cargarSenales(String ruta, {String? fecha}) {
    final hoy = fecha ?? _hoy();
    final filas = _leerCsv(ruta, columnas: 4);

    if (filas.isEmpty) {
      throw FormatException('El archivo de señales no contiene datos.');
    }

    var nuevas = 0;

    db.execute('BEGIN');

    try {
      db.execute(
        'INSERT INTO carga (archivo, fecha, filas) VALUES (?, ?, ?)',
        [ruta, hoy, filas.length],
      );

      final cargaId = db.lastInsertRowId;

      for (final f in filas) {
        if (f.length != 4 || f[1].isEmpty || f[3].isEmpty) {
          throw FormatException('Fila inválida en las señales: $f');
        }

        final dia = int.tryParse(f[0]);

        if (dia == null || dia < 0) {
          throw FormatException('Día inválido en las señales: ${f[0]}');
        }

        db.execute(
          'INSERT OR IGNORE INTO senal '
          '(dia, voz, transcripcion, salida, carga_id) '
          'VALUES (?, ?, ?, ?, ?)',
          [dia, f[1], f[2], f[3], cargaId],
        );

        nuevas += db.updatedRows;
      }

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    return nuevas;
  }

  // Busca una palabra según su fecha de vigencia.
  Traduccion? buscar(String lema, {String? fecha}) {
    final f = fecha ?? _hoy();

    final r = db.select(
      'SELECT l.lema_es, l.categoria, v.kethari, v.ozh '
      'FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? AND v.vigente_desde <= ? '
      'AND (v.vigente_hasta IS NULL OR v.vigente_hasta > ?) '
      'ORDER BY v.vigente_desde DESC '
      'LIMIT 1',
      [lema, f, f],
    );

    if (r.isEmpty) return null;

    final x = r.first;

    return Traduccion(
      x['lema_es'] as String,
      x['categoria'] as String,
      x['kethari'] as String?,
      x['ozh'] as String?,
    );
  }

  // Lista las señales registradas, ordenadas por día.
  List<Map<String, dynamic>> listarSenales() {
    return db
        .select(
          'SELECT dia, voz, transcripcion, salida '
          'FROM senal ORDER BY dia, id',
        )
        .map((r) => {
              'dia': r['dia'],
              'voz': r['voz'],
              'transcripcion': r['transcripcion'],
              'salida': r['salida'],
            })
        .toList();
  }

  // Consulta todas las versiones de una palabra.
  List<Map<String, dynamic>> historialPalabra(String lema) {
    final resultados = db.select(
      'SELECT l.lema_es, l.categoria, '
      'v.kethari, v.ozh, v.vigente_desde, '
      'v.vigente_hasta, v.origen '
      'FROM lexico l '
      'JOIN lexico_version v ON v.lexico_id = l.id '
      'WHERE l.lema_es = ? '
      'ORDER BY v.vigente_desde ASC',
      [lema],
    );

    return resultados
        .map((r) => {
              'lema_es': r['lema_es'],
              'categoria': r['categoria'],
              'kethari': r['kethari'],
              'ozh': r['ozh'],
              'vigente_desde': r['vigente_desde'],
              'vigente_hasta': r['vigente_hasta'],
              'origen': r['origen'],
            })
        .toList();
  }

  // Consulta el historial de archivos cargados.
  List<Map<String, dynamic>> historialCargas() {
    final resultados = db.select(
      'SELECT archivo, fecha, filas '
      'FROM carga ORDER BY fecha DESC, id DESC',
    );

    return resultados
        .map((r) => {
              'archivo': r['archivo'],
              'fecha': r['fecha'],
              'filas': r['filas'],
            })
        .toList();
  }

  // Registra una pregunta, sus correcciones y traducciones.
  int registrarPregunta({
    required String original,
    String? corregido,
    String? kethari,
    String? ozh,
    String? validacion,
    String? fecha,
  }) {
    if (original.trim().isEmpty) {
      throw ArgumentError('La pregunta original no puede estar vacía.');
    }

    db.execute(
      'INSERT INTO pregunta (fecha, texto_original, texto_corregido, '
      'traduccion_kethari, traduccion_ozh, validacion) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        fecha ?? DateTime.now().toIso8601String(),
        original,
        corregido,
        kethari,
        ozh,
        validacion,
      ],
    );

    return db.lastInsertRowId;
  }

  // Lista preguntas, opcionalmente desde una fecha.
  List<Map<String, dynamic>> historialPreguntas({String? desde}) {
    final filas = desde == null
        ? db.select('SELECT * FROM pregunta ORDER BY fecha, id')
        : db.select(
            'SELECT * FROM pregunta WHERE fecha >= ? ORDER BY fecha, id',
            [desde],
          );

    return filas
        .map((r) => {
              'id': r['id'],
              'fecha': r['fecha'],
              'original': r['texto_original'],
              'corregido': r['texto_corregido'],
              'kethari': r['traduccion_kethari'],
              'ozh': r['traduccion_ozh'],
              'validacion': r['validacion'],
            })
        .toList();
  }
}
