import 'dart:io';
import 'package:test/test.dart';
import '../../lib/bd/carga_axios.dart';
import '../../lib/bd/conexion.dart';
import '../../lib/bd/lexico_repo.dart';

File _archivo(String nombre, String contenido) {
  final dir = Directory.systemTemp.createTempSync();
  return File('${dir.path}/$nombre')..writeAsStringSync(contenido);
}

int _contar(dynamic db, String tabla) =>
    db.select('SELECT COUNT(*) AS n FROM $tabla').first['n'] as int;

void main() {
  const semana1 = 'datos/senales_semana1.txt';
  const semana2 = 'datos/senales_semana2.txt';
  const lexico = 'datos/lexico_inicial.csv';

  test('carga las 15 señales de la semana 1 sin tocar el código', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    final r = repo.cargarAxios(semana1);

    expect(r.senales, 15);
    expect(r.correcciones, 0);
    expect(_contar(db, 'senal'), 15);

    db.close();
  });

  test('guarda la señal desconocida con transcripción vacía', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarAxios(semana1);

    final desconocida =
        repo.listarSenales().where((s) => s['voz'] == 'Desconocida').toList();

    expect(desconocida.length, 1);
    expect(desconocida.first['transcripcion'], '');
    expect(desconocida.first['salida'], 'Ya los escuchamos.');

    db.close();
  });

  test('semana 2: agrega señales y corrige "teka" con historial', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(lexico, fecha: '2026-11-10');
    repo.cargarAxios(semana1, fecha: '2026-11-10');

    final r = repo.cargarAxios(semana2, fecha: '2026-11-24');

    expect(r.senales, 6);
    expect(r.correcciones, 1);

    // Antes de la corrección, teka significaba "tierra".
    expect(repo.buscar('tierra', fecha: '2026-11-20')?.kethari, 'teka');
    expect(repo.buscar('territorio reclamado', fecha: '2026-11-20'), isNull);

    // Después, significa "territorio reclamado".
    expect(
      repo.buscar('territorio reclamado', fecha: '2026-11-25')?.kethari,
      'teka',
    );

    // "tierra" conserva su palabra en Ozh pero pierde la de Kethari.
    final tierra = repo.buscar('tierra', fecha: '2026-11-25');
    expect(tierra?.kethari, isNull);
    expect(tierra?.ozh, 'mak');

    db.close();
  });

  test('cargar el mismo archivo dos veces no duplica nada', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(lexico, fecha: '2026-11-10');
    repo.cargarAxios(semana2, fecha: '2026-11-24');

    final segunda = repo.cargarAxios(semana2, fecha: '2026-11-25');

    expect(segunda.senales, 0);
    expect(segunda.correcciones, 0);
    expect(_contar(db, 'senal'), 6);

    db.close();
  });

  test('una corrección imposible revierte toda la carga', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    final malo = _archivo(
      'malo.txt',
      'SENAL|1|kethari|anir ombraesh salok|Nosotros enviamos mensajes.\n'
      'CORRECCION|kethari|noexiste|nada|otra cosa\n',
    );

    expect(() => repo.cargarAxios(malo.path), throwsFormatException);
    expect(_contar(db, 'senal'), 0);
    expect(_contar(db, 'carga'), 0);

    db.close();
  });

  test('rechaza un día inválido y no guarda nada', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    final malo = _archivo('malo.txt', 'SENAL|x|kethari|a b|Hola.\n');

    expect(() => repo.cargarAxios(malo.path), throwsFormatException);
    expect(_contar(db, 'senal'), 0);

    db.close();
  });

  test('acepta saltos de línea de Windows y comentarios', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    final f = _archivo(
      'crlf.txt',
      '# comentario\r\n\r\nSENAL|1|ozh|ʔoka dra|Antes enviamos. [zi]\r\n',
    );

    expect(repo.cargarAxios(f.path).senales, 1);

    db.close();
  });

  test('reconoce el formato de Axios y no confunde un CSV', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.esFormatoAxios(semana1), isTrue);
    expect(repo.esFormatoAxios(semana2), isTrue);
    expect(repo.esFormatoAxios(lexico), isFalse);
    expect(repo.esFormatoAxios('datos/senales_inicial.csv'), isFalse);

    db.close();
  });
}