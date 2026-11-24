import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';
import 'package:test/test.dart';

void main() {
  // Datos reales de datos/espanol, y el módulo léxico usando el
  // vocabulario que le da el parser (palabras + formas verbales).
  final parser = AnalizadorSintactico.desde(FuenteLexicoJson());
  final lexico = FaseLexica(parser.vocabulario);

  ResultadoSintactico analizar(String pregunta) =>
      parser.analizar(lexico.procesar(pregunta).tokens);

  Oracion arbol(String pregunta) {
    final r = analizar(pregunta);
    expect(r.error, isNull, reason: 'no debía fallar: ${r.error}');
    return r.arbol!;
  }

  const ustedes = Pronominal(Persona.segunda, Numero.plural);
  const nosotrosInferido =
      Pronominal(Persona.primera, Numero.plural, inferido: true);
  const ustedesInferido =
      Pronominal(Persona.segunda, Numero.plural, inferido: true);

  group('afirmaciones', () {
    test('"Queremos paz": sujeto omitido y objeto', () {
      final o = arbol('Queremos paz');
      expect(o.modo, Modo.afirmacion);
      expect(o.tiempo, Tiempo.presente);
      expect(o.verbo, 'QUERER');
      expect(o.sujeto, nosotrosInferido);
      expect((o.objeto as Nominal).concepto, 'PAZ');
    });

    test('"Nosotros esperaremos seis ciclos": futuro y cantidad en letras', () {
      final o = arbol('Nosotros esperaremos seis ciclos.');
      expect(o.tiempo, Tiempo.futuro);
      expect(o.verbo, 'ESPERAR');
      expect(o.sujeto, const Pronominal(Persona.primera, Numero.plural));
      final ciclos = o.objeto as Nominal;
      expect(ciclos.concepto, 'CICLO');
      expect(ciclos.cantidad, 6);
      expect(ciclos.numero, Numero.plural);
    });

    test('"Quince naves llegaron": sujeto antes del verbo', () {
      final o = arbol('Quince naves llegaron');
      expect(o.tiempo, Tiempo.pasado);
      expect(o.verbo, 'VENIR');
      final naves = o.sujeto as Nominal;
      expect(naves.concepto, 'NAVE');
      expect(naves.cantidad, 15);
      expect(o.objeto, isNull);
    });
  });

  group('preguntas de sí o no', () {
    test('"¿Ustedes quieren paz?"', () {
      final o = arbol('¿Ustedes quieren paz?');
      expect(o.modo, Modo.preguntaSiNo);
      expect(o.sujeto, ustedes);
      expect((o.objeto as Nominal).concepto, 'PAZ');
    });

    test('sujeto después del verbo: "¿Quieren paz ustedes?"', () {
      final o = arbol('¿Quieren paz ustedes?');
      expect(o.sujeto, ustedes);
      expect((o.objeto as Nominal).concepto, 'PAZ');
    });

    test('negación, pasado y posesivo: "¿Ustedes no vieron nuestro planeta?"',
        () {
      final o = arbol('¿Ustedes no vieron nuestro planeta?');
      expect(o.negada, isTrue);
      expect(o.tiempo, Tiempo.pasado);
      expect(o.verbo, 'VER');
      final planeta = o.objeto as Nominal;
      expect(planeta.concepto, 'PLANETA');
      expect(planeta.poseedor?.persona, Persona.primera);
      expect(planeta.poseedor?.numero, Numero.plural);
    });

    test('sin signos de interrogación solo "?" al final', () {
      expect(arbol('ustedes vienen?').modo, Modo.preguntaSiNo);
    });

    test('sin ningún signo se lee como afirmación (bitácora S-12)', () {
      expect(arbol('ustedes vienen').modo, Modo.afirmacion);
    });

    test('verbo intransitivo: el sustantivo de después es el sujeto', () {
      final o = arbol('¿Llegaron las naves?');
      expect((o.sujeto as Nominal).concepto, 'NAVE');
      expect(o.objeto, isNull);
    });

    test('"a" personal marca el objeto', () {
      final o = arbol('¿Vieron a las criaturas?');
      expect((o.objeto as Nominal).concepto, 'CRIATURA');
      expect(o.sujeto, ustedesInferido);
    });
  });

  group('preguntas con palabra interrogativa', () {
    test('"¿Cuándo vendrán ustedes?" (señal del día 5)', () {
      final o = arbol('¿Cuándo vendrán ustedes?');
      expect(o.modo, Modo.preguntaAbierta);
      expect(o.interrogativo, 'CUANDO');
      expect(o.rolInterrogativo, RolInterrogativo.tiempo);
      expect(o.tiempo, Tiempo.futuro);
      expect(o.verbo, 'VENIR');
      expect(o.sujeto, ustedes);
    });

    test('sujeto omitido en pregunta: "¿Cuándo llegan?" -> ustedes', () {
      final r = analizar('¿Cuándo llegan?');
      expect(r.arbol!.sujeto, ustedesInferido);
      expect(r.advertencias.any((a) => a.contains('sujeto omitido')), isTrue);
    });

    test('"¿Quién envió el mensaje?" (señal del día 6): envio en pasado', () {
      final o = arbol('¿Quién envió el mensaje?');
      expect(o.interrogativo, 'QUIEN');
      expect(o.rolInterrogativo, RolInterrogativo.sujeto);
      expect(o.sujeto, isA<Incognita>());
      expect(o.tiempo, Tiempo.pasado);
      expect((o.objeto as Nominal).concepto, 'MENSAJE');
    });

    test('"¿Qué quieren ustedes?": qué es el objeto', () {
      final o = arbol('¿Qué quieren ustedes?');
      expect(o.rolInterrogativo, RolInterrogativo.objeto);
      expect(o.objeto, isA<Incognita>());
      expect(o.sujeto, ustedes);
    });

    test('"¿Cuántas naves llegaron?": se pregunta la cantidad del sujeto', () {
      final o = arbol('¿Cuántas naves llegaron?');
      expect(o.rolInterrogativo, RolInterrogativo.cantidad);
      final naves = o.sujeto as Nominal;
      expect(naves.concepto, 'NAVE');
      expect(naves.preguntaCantidad, isTrue);
    });

    test('"¿Dónde está su hogar?": posesivo "su" -> de ustedes', () {
      final o = arbol('¿Dónde está su hogar?');
      expect(o.rolInterrogativo, RolInterrogativo.lugar);
      expect(o.verbo, 'SER');
      final hogar = o.sujeto as Nominal;
      expect(hogar.poseedor?.persona, Persona.segunda);
    });

    test('sin tildes ni signos: "cuando llegaran"', () {
      final o = arbol('cuando llegaran');
      expect(o.modo, Modo.preguntaAbierta);
      expect(o.tiempo, Tiempo.futuro);
    });
  });

  group('preposición antes del interrogativo (bitácora S-13)', () {
    test('"¿A quién escuchan ustedes?" (señal del día 9): quién es el objeto',
        () {
      final o = arbol('¿A quién escuchan ustedes?');
      expect(o.interrogativo, 'QUIEN');
      expect(o.rolInterrogativo, RolInterrogativo.objeto);
      expect(o.objeto, isA<Incognita>());
      expect(o.sujeto, ustedes);
      expect(o.verbo, 'ESCUCHAR');
      expect(o.tiempo, Tiempo.presente);
    });

    test('sin "a", quién sigue siendo el sujeto', () {
      final o = arbol('¿Quién escucha?');
      expect(o.rolInterrogativo, RolInterrogativo.sujeto);
      expect(o.sujeto, isA<Incognita>());
    });

    test('"¿A quién vieron?": objeto y sujeto omitido -> ustedes', () {
      final o = arbol('¿A quién vieron?');
      expect(o.rolInterrogativo, RolInterrogativo.objeto);
      expect(o.sujeto, ustedesInferido);
      expect(o.tiempo, Tiempo.pasado);
    });

    test('sin tildes ni signos: "a quien escuchan"', () {
      final o = arbol('a quien escuchan');
      expect(o.modo, Modo.preguntaAbierta);
      expect(o.rolInterrogativo, RolInterrogativo.objeto);
    });

    test('"¿De dónde vienen?" sigue sin traducirse (bitácora S-07)', () {
      final r = analizar('¿De dónde vienen?');
      expect(r.arbol, isNull);
      expect(r.error!.mensaje, contains('"de"'));
    });
  });

  group('futuro con "ir a"', () {
    test('"¿Van a llegar quince naves?"', () {
      final o = arbol('¿Van a llegar quince naves?');
      expect(o.tiempo, Tiempo.futuro);
      expect(o.verbo, 'VENIR');
      expect((o.sujeto as Nominal).cantidad, 15);
    });

    test('"Vamos a esperar" en primera plural', () {
      final o = arbol('Vamos a esperar');
      expect(o.tiempo, Tiempo.futuro);
      expect(o.verbo, 'ESPERAR');
      expect(o.sujeto, nosotrosInferido);
    });
  });

  group('palabras con dos categorías sin tilde', () {
    test('"tu" posesivo y "tú" pronombre', () {
      final posesivo = arbol('¿Tu mundo quiere paz?');
      expect((posesivo.sujeto as Nominal).poseedor?.persona, Persona.segunda);

      final pronombre = arbol('¿Tú vienes?');
      expect(pronombre.sujeto,
          const Pronominal(Persona.segunda, Numero.singular));
    });

    test('"el" artículo y "él" pronombre', () {
      expect(arbol('El viene').sujeto,
          const Pronominal(Persona.tercera, Numero.singular));
      expect((arbol('El mensaje llegó').sujeto as Nominal).concepto,
          'MENSAJE');
    });
  });

  group('pronombres pegados al verbo (bitácora S-14)', () {
    test('"Nosotros no los vimos a ustedes" (señal del día 4)', () {
      final o = arbol('Nosotros no los vimos a ustedes.');
      expect(o.sujeto, const Pronominal(Persona.primera, Numero.plural));
      expect(o.objeto, ustedes);
      expect(o.negada, isTrue);
      expect(o.tiempo, Tiempo.pasado);
      expect(o.verbo, 'VER');
    });

    test('"¿Nos escuchan?": nos es el objeto y el sujeto se deduce', () {
      final o = arbol('¿Nos escuchan?');
      expect(o.objeto, const Pronominal(Persona.primera, Numero.plural));
      expect(o.sujeto, ustedesInferido);
    });

    test('"¿Quién los escucha?": quién sujeto y los objeto', () {
      final o = arbol('¿Quién los escucha?');
      expect(o.sujeto, isA<Incognita>());
      expect(o.objeto, const Pronominal(Persona.tercera, Numero.plural));
    });

    test('"los" sin verbo después sigue siendo artículo', () {
      final o = arbol('Los mensajes llegaron');
      expect((o.sujeto as Nominal).concepto, 'MENSAJE');
    });

    test('"a" + pronombre es objeto, no sujeto', () {
      final o = arbol('¿Vieron a ustedes?');
      expect(o.objeto, ustedes);
      expect(o.sujeto, ustedesInferido);
    });

    test('si ya hay otro objeto, el pronombre no tiene lugar', () {
      final r = analizar('¿Qué nos envían?');
      expect(r.arbol, isNull);
      expect(r.error!.mensaje, contains('"nos"'));
    });
  });

  group('adverbios de tiempo (bitácora S-15)', () {
    test('"Antes enviamos un mensaje": antes elige el pasado', () {
      final o = arbol('Antes enviamos un mensaje.');
      expect(o.tiempo, Tiempo.pasado);
      expect(o.sujeto, nosotrosInferido);
      expect((o.objeto as Nominal).concepto, 'MENSAJE');
    });

    test('sin "antes", "enviamos" queda en presente', () {
      expect(arbol('Enviamos un mensaje').tiempo, Tiempo.presente);
    });

    test('"Antes ellos visitaron nuestro mundo" (señal del día 8)', () {
      final o = arbol('Antes ellos visitaron nuestro mundo.');
      expect(o.tiempo, Tiempo.pasado);
      expect(o.verbo, 'VISITAR');
      expect(o.sujeto, const Pronominal(Persona.tercera, Numero.plural));
      expect((o.objeto as Nominal).poseedor?.persona, Persona.primera);
    });

    test('"Ya los escuchamos": ya elige el pasado y se avisa', () {
      final r = analizar('Ya los escuchamos.');
      final o = r.arbol!;
      expect(o.tiempo, Tiempo.pasado);
      expect(o.objeto, const Pronominal(Persona.tercera, Numero.plural));
      expect(r.advertencias.any((a) => a.contains('"ya"')), isTrue);
    });

    test('"después" y adverbio al final', () {
      expect(arbol('Después vendrán ustedes').tiempo, Tiempo.futuro);
      expect(arbol('Llegamos antes').tiempo, Tiempo.pasado);
    });
  });

  group('ningún / ninguna (bitácora S-16)', () {
    test('"No vimos ninguna nave" (señal del día 4)', () {
      final o = arbol('No vimos ninguna nave.');
      expect(o.negada, isTrue);
      final nave = o.objeto as Nominal;
      expect(nave.concepto, 'NAVE');
      expect(nave.cantidad, isNull);
    });

    test('sin "no", ninguna hace negativa la oración', () {
      final o = arbol('Ninguna nave llegó');
      expect(o.negada, isTrue);
      expect(o.tiempo, Tiempo.pasado);
      expect((o.sujeto as Nominal).concepto, 'NAVE');
    });
  });

  group('sustantivos de varias palabras (bitácora S-17)', () {
    test('"Ellos no quieren territorios reclamados" (señal del día 8)', () {
      final o = arbol('Ellos no quieren territorios reclamados.');
      final t = o.objeto as Nominal;
      expect(t.concepto, 'TERRITORIO_RECLAMADO');
      expect(t.numero, Numero.plural);
      expect(o.negada, isTrue);
    });

    test('con artículo y en singular', () {
      final o = arbol('¿Quieren el territorio reclamado?');
      expect((o.objeto as Nominal).concepto, 'TERRITORIO_RECLAMADO');
    });

    test('"¿Es él un ser vivo?": ser vivo es CRIATURA (S-08 resuelta)', () {
      final o = arbol('¿Es él un ser vivo?');
      expect(o.verbo, 'SER');
      expect((o.objeto as Nominal).concepto, 'CRIATURA');
    });

    test('con cuántos', () {
      final o = arbol('¿Cuántos territorios reclamados quieren?');
      expect(o.rolInterrogativo, RolInterrogativo.cantidad);
      expect((o.objeto as Nominal).concepto, 'TERRITORIO_RECLAMADO');
    });
  });

  group('frases del decodificador (semanas 1 y 2)', () {
    // Salidas en español de senales_semana1.txt y senales_semana2.txt.
    const frases = [
      'Nosotros enviamos mensajes.',
      'Antes enviamos un mensaje.',
      'Nosotros queremos paz.',
      'Ellos quieren paz.',
      'Quince naves llegaron.',
      'Llegarán quince naves.',
      'Nosotros no los vimos a ustedes.',
      'No vimos ninguna nave.',
      '¿Cuándo vendrán ustedes?',
      '¿Cuándo vienen ustedes?',
      '¿Quién envió el mensaje?',
      'Ustedes no hablan.',
      'Ya los escuchamos.',
      'Nosotros esperaremos seis ciclos.',
      'Yo espero seis ciclos.',
      'Ellos no quieren territorios reclamados.',
      'Antes ellos visitaron nuestro mundo.',
      '¿Es él una criatura?',
      '¿A quién escuchan ustedes?',
      'Nosotros vimos veintiséis estrellas.',
      'Ellos no quieren paz.',
    ];
    for (final f in frases) {
      test(f, () => arbol(f));
    }
  });

  group('errores con explicación (nunca se cae)', () {
    test('palabra fuera del vocabulario', () {
      final r = analizar('¿Cuándo llega el presidente?');
      expect(r.exito, isFalse);
      expect(r.error!.mensaje, contains('presidente'));
      expect(r.error!.mensaje, contains('no está en el vocabulario'));
    });

    test('falta el verbo', () {
      final r = analizar('nuestro planeta');
      expect(r.error!.mensaje, contains('se esperaba un verbo'));
    });

    test('"ir" solo no tiene traducción', () {
      final r = analizar('ustedes van');
      expect(r.error!.mensaje, contains('no tiene traducción'));
    });

    test('dos verbos seguidos todavía no se entienden', () {
      final r = analizar('¿Quieren visitar la tierra?');
      expect(r.error!.mensaje, contains('dos verbos'));
    });

    test('carácter desconocido', () {
      final r = analizar('queremos paz #');
      expect(r.error!.mensaje, contains('#'));
    });

    test('entrada vacía', () {
      expect(analizar('').error!.mensaje, contains('vacía'));
    });
  });

  test('modo traza muestra las reglas y el árbol', () {
    final r = parser.analizar(lexico.procesar('queremos paz').tokens,
        conTraza: true);
    expect(r.traza.first, contains('<entrada>'));
    expect(r.traza.any((l) => l.contains('<grupo-verbal>')), isTrue);
    expect(r.traza.any((l) => l.contains('árbol construido')), isTrue);
    expect(parser.analizar(lexico.procesar('queremos paz').tokens).traza,
        isEmpty);
  });
}
