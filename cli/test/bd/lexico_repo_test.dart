import 'dart:io';
import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';
import '../../lib/bd/lexico_repo.dart';

File _csv(String nombre, String contenido) {
  final dir = Directory.systemTemp.createTempSync();
  return File('${dir.path}/$nombre')..writeAsStringSync(contenido);
}

void main() {
  test('carga el léxico y lo encuentra con buscar', () {
    final csv = _csv(
      'lex.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.cargarLexico(csv.path), 1);

    final t = repo.buscar('agua');

    expect(t?.kethari, 'ilu');
    expect(t?.ozh, 'ba');
    expect(repo.buscar('inexistente'), isNull);

    db.close();
  });

  test('cargar de nuevo con cambios conserva el historial', () {
    final v1 = _csv(
      'v1.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final v2 = _csv(
      'v2.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilun,ba\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(v1.path, fecha: '2026-11-01');
    repo.cargarLexico(v2.path, fecha: '2026-11-10');

    expect(repo.buscar('agua', fecha: '2026-11-05')?.kethari, 'ilu');
    expect(repo.buscar('agua', fecha: '2026-11-15')?.kethari, 'ilun');

    db.close();
  });

  test('carga las señales con día y voz y las lista', () {
    final csv = _csv(
      'sen.csv',
      'dia,voz,transcripcion,salida\n'
      '1,Kethari,anir ombraesh salok,Nosotros enviamos mensajes.\n'
      '6,Desconocida,,Ya los escuchamos.\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.cargarSenales(csv.path), 2);

    final s = repo.listarSenales();
    expect(s.length, 2);
    expect(s[0]['voz'], 'Kethari');
    expect(s[1]['dia'], 6);
    expect(s[1]['transcripcion'], '');

    db.close();
  });

  test('un archivo nuevo agrega solo las señales que no estaban', () {
    final v1 = _csv(
      'v1.csv',
      'dia,voz,transcripcion,salida\n'
      '1,Kethari,anir ombraesh salok,Nosotros enviamos mensajes.\n',
    );
    final v2 = _csv(
      'v2.csv',
      'dia,voz,transcripcion,salida\n'
      '1,Kethari,anir ombraesh salok,Nosotros enviamos mensajes.\n'
      '8,Ozh,bo mar ʔen,Yo espero. [mar]\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.cargarSenales(v1.path), 1);
    expect(repo.cargarSenales(v2.path), 1);
    expect(repo.listarSenales().length, 2);
    expect(repo.historialCargas().length, 2);

    db.close();
  });

  test('consulta todas las versiones de una palabra', () {
    final v1 = _csv(
      'historial1.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final v2 = _csv(
      'historial2.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilun,ba\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(v1.path, fecha: '2026-11-01');
    repo.cargarLexico(v2.path, fecha: '2026-11-10');

    final historial = repo.historialPalabra('agua');

    expect(historial.length, 2);
    expect(historial[0]['kethari'], 'ilu');
    expect(historial[1]['kethari'], 'ilun');
    expect(historial[0]['vigente_desde'], '2026-11-01');
    expect(historial[1]['vigente_desde'], '2026-11-10');

    db.close();
  });

  test('consulta el historial de archivos cargados', () {
    final v1 = _csv(
      'carga1.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final v2 = _csv(
      'carga2.csv',
      'lema_es,categoria,kethari,ozh\nfuego,sustantivo,ara,ka\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(v1.path, fecha: '2026-11-01');
    repo.cargarLexico(v2.path, fecha: '2026-11-02');

    final historial = repo.historialCargas();

    expect(historial.length, 2);
    expect(historial[0]['archivo'], v2.path);
    expect(historial[0]['filas'], 1);
    expect(historial[1]['archivo'], v1.path);
    expect(historial[1]['fecha'], '2026-11-01');

    db.close();
  });

  test('no duplica versiones cuando la traducción no cambia', () {
    final csv = _csv(
      'igual.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(csv.path, fecha: '2026-11-01');
    repo.cargarLexico(csv.path, fecha: '2026-11-02');

    final historial = repo.historialPalabra('agua');

    expect(historial.length, 1);
    expect(repo.historialCargas().length, 2);

    db.close();
  });

  test('rechaza una fecha anterior y conserva la version vigente', () {
    final v1 = _csv(
      'actual.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,ilu,ba\n',
    );

    final v2 = _csv(
      'anterior.csv',
      'lema_es,categoria,kethari,ozh\nagua,sustantivo,antiguo,ba\n',
    );

    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.cargarLexico(v1.path, fecha: '2026-11-10');

    expect(
      () => repo.cargarLexico(v2.path, fecha: '2026-11-05'),
      throwsA(isA<FormatException>()),
    );

    expect(repo.buscar('agua', fecha: '2026-11-12')?.kethari, 'ilu');
    expect(repo.historialPalabra('agua').length, 1);
    expect(repo.historialCargas().length, 1);

    db.close();
  });
}