import 'dart:io';

import 'package:cli/bd.dart';
import 'package:cli/generadores.dart';
import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

// Los generadores leen el léxico de la base de datos (bitácora K-11).
void main() {
  const lexicoInicial = 'datos/lexico_inicial.csv';
  const semana2 = 'datos/senales_semana2.txt';
  final espanol = FuenteLexicoJson();

  late LexicoRepo repo;
  late FuenteKethariBd fuenteK;
  late FuenteOzhBd fuenteO;

  setUp(() {
    final db = abrirBd(':memory:');
    repo = LexicoRepo(db);
    repo.cargarLexico(lexicoInicial, fecha: '2026-11-17');
    fuenteK = FuenteKethariBd(db, espanol);
    fuenteO = FuenteOzhBd(db, espanol);
  });

  String kethari(Oracion o, [FuenteKethari? f]) {
    final r = GeneradorKethari(f ?? fuenteK).generar(o);
    expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
    return r.texto!;
  }

  const nosotros = Pronominal(Persona.primera, Numero.plural, inferido: true);
  const ustedes = Pronominal(Persona.segunda, Numero.plural);

  const queremosPaz = Oracion(
    modo: Modo.afirmacion,
    negada: false,
    tiempo: Tiempo.presente,
    verbo: 'QUERER',
    sujeto: nosotros,
    objeto: Nominal('PAZ', numero: Numero.singular),
  );

  // "¿Ustedes quieren nuestra tierra?"
  const quierenTierra = Oracion(
    modo: Modo.preguntaSiNo,
    negada: false,
    tiempo: Tiempo.presente,
    verbo: 'QUERER',
    sujeto: ustedes,
    objeto: Nominal('TIERRA',
        numero: Numero.singular,
        poseedor: Poseedor(Persona.primera, Numero.plural)),
  );

  group('Kethari con el léxico de la BD', () {
    test('día 5: kom ulesh vinime ka (venir/llegar: mismo concepto)', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'CUANDO',
        rolInterrogativo: RolInterrogativo.tiempo,
        negada: false,
        tiempo: Tiempo.futuro,
        verbo: 'VENIR',
        sujeto: ustedes,
      );
      expect(kethari(o), 'kom ulesh vinime ka');
    });

    test('"anul|anir" de la BD se resuelve con alternativas: anir (K-01)', () {
      expect(kethari(queremosPaz), 'anir parn thal');
    });

    test('día 3: ra-sel kumesh vinok (cifras desde la BD)', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'VENIR',
        sujeto: Nominal('NAVE', numero: Numero.plural, cantidad: 15),
      );
      expect(kethari(o), 'ra-sel kumesh vinok');
    });

    test('día 6: sem ombra salok ka (interrogativo con tilde en la BD)', () {
      const o = Oracion(
        modo: Modo.preguntaAbierta,
        interrogativo: 'QUIEN',
        rolInterrogativo: RolInterrogativo.sujeto,
        negada: false,
        tiempo: Tiempo.pasado,
        verbo: 'ENVIAR',
        sujeto: Incognita('QUIEN'),
        objeto: Nominal('MENSAJE', numero: Numero.singular),
      );
      expect(kethari(o), 'sem ombra salok ka');
    });
  });

  group('correcciones del manual con cargar (criterio 17)', () {
    test('antes de la semana 2, tierra es teka', () {
      expect(kethari(quierenTierra), 'ulesh anir teka thal ka');
    });

    test('después de cargar la semana 2, tierra ya no tiene palabra', () {
      repo.cargarAxios(semana2, fecha: '2026-11-23');
      final r = GeneradorKethari(fuenteK).generar(quierenTierra);
      expect(r.ok, isFalse);
      expect(r.error, contains('TIERRA'));
    });

    test('después de la semana 2, territorio reclamado es teka', () {
      repo.cargarAxios(semana2, fecha: '2026-11-23');
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: Pronominal(Persona.tercera, Numero.plural),
        objeto: Nominal('TERRITORIO_RECLAMADO', numero: Numero.plural),
      );
      expect(kethari(o), 'iresh tekaesh nuthal'); // señal del día 8
    });

    test('en una fecha anterior a la corrección se usa lo que se creía', () {
      repo.cargarAxios(semana2, fecha: '2026-11-23');
      expect(kethari(quierenTierra, fuenteK.enFecha('2026-11-20')),
          'ulesh anir teka thal ka');
    });

    test('un archivo nuevo cambia la traducción sin recompilar', () {
      final dir = Directory.systemTemp.createTempSync();
      final archivo = File('${dir.path}/correccion.csv')
        ..writeAsStringSync('lema_es,categoria,kethari,ozh\n'
            'paz,sustantivo,parnu,ilu\n');
      expect(kethari(queremosPaz), 'anir parn thal');
      repo.cargarLexico(archivo.path, fecha: '2026-11-25');
      expect(kethari(queremosPaz), 'anir parnu thal');
    });
  });

  group('Ozh con el léxico de la BD', () {
    String ozh(Oracion o) {
      final r = GeneradorOzh(fuenteO).generar(o);
      expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
      return r.texto!;
    }

    test('día 10: ne lom tho oruvi ilu', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: Pronominal(Persona.tercera, Numero.plural),
        objeto: Nominal('PAZ', numero: Numero.singular),
      );
      expect(ozh(o), 'ne lom tho oruvi ilu');
    });

    test('día 6: ne tal mar shavi', () {
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: true,
        tiempo: Tiempo.presente,
        verbo: 'HABLAR',
        sujeto: ustedes,
      );
      expect(ozh(o), 'ne tal mar shavi');
    });

    test('territorio reclamado no tiene palabra Ozh: no la inventa', () {
      repo.cargarAxios(semana2, fecha: '2026-11-23');
      const o = Oracion(
        modo: Modo.afirmacion,
        negada: false,
        tiempo: Tiempo.presente,
        verbo: 'QUERER',
        sujeto: ustedes,
        objeto: Nominal('TERRITORIO_RECLAMADO', numero: Numero.singular),
      );
      final r = GeneradorOzh(fuenteO).generar(o);
      expect(r.ok, isFalse);
      expect(r.error, contains('TERRITORIO_RECLAMADO'));
    });
  });
}
