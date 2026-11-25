/// Generador de Ozh (fase 7b): convierte el árbol intermedio en una
/// oración Ozh siguiendo el manual v0.7, sección 3.4.
///
/// Orden: [ʔoka | venu] [ne] [ʔa-]VERBO PARTÍCULA SUJETO OBJETO [INTERROGATIVO]
///
/// - El tiempo no cambia el verbo: `ʔoka` (pasado) o `venu` (futuro) van al
///   principio de la oración.
/// - La negación `ne` va justo delante del verbo, después del tiempo (O-02).
/// - Las preguntas llevan `ʔa-` en el verbo; la palabra interrogativa va al
///   final y no se repite en su hueco (O-03).
/// - Justo después del verbo va siempre una partícula (`zi`, `mar`, `tho`),
///   elegida por las reglas de `datos/ozh/gramatica.json` (O-01).
/// - Sustantivos sin plural; el número va delante y el poseedor detrás.
///
/// Las palabras y las reglas salen de una [FuenteOzh]; aquí solo está el
/// orden. Si falta algo, no se omite ni se inventa: se explica (O-04).
library;

import '../sintactico/arbol.dart';
import 'ambiguedad.dart';
import 'fuente_ozh.dart';
import 'numeros.dart';

class ResultadoOzh {
  /// Oración en Ozh. `null` si no se pudo generar.
  final String? texto;

  /// Por qué no se generó. `null` si todo salió bien.
  final String? error;

  final List<String> traza;

  /// Avisos que no impiden traducir (por ejemplo K-07).
  final List<String> advertencias;

  const ResultadoOzh._(this.texto, this.error, this.traza,
      [this.advertencias = const []]);

  const ResultadoOzh.fallo(String error, [List<String> traza = const []])
      : this._(null, error, traza);

  bool get ok => texto != null;

  @override
  String toString() => ok ? texto! : 'sin traducción: $error';
}

class GeneradorOzh {
  final FuenteOzh fuente;

  const GeneradorOzh(this.fuente);

  ResultadoOzh generar(Oracion oracion) =>
      _GeneracionOzh(fuente, oracion).ejecutar();
}

class _GeneracionOzh {
  final FuenteOzh fuente;
  final Oracion o;

  final partes = <String>[];
  final traza = <String>[];

  /// Palabras sin traducción conocida.
  final faltan = <String>[];

  /// Cosas que el árbol pide y el generador no sabe hacer.
  final pendientes = <String>[];

  _GeneracionOzh(this.fuente, this.o);

  bool get _esPregunta => o.modo != Modo.afirmacion;

  ResultadoOzh ejecutar() {
    _tiempo();
    _negacion();
    _verbo();
    _particula();
    _participante(o.sujeto, 'sujeto');
    final objeto = o.objeto;
    if (objeto != null) _participante(objeto, 'objeto');
    _interrogativo();

    if (faltan.isNotEmpty) {
      final error = 'el manual no tiene palabra Ozh para '
          '${faltan.join(', ')}. No se inventan palabras.';
      traza.add('ERROR: $error');
      return ResultadoOzh.fallo(error, List.unmodifiable(traza));
    }
    if (pendientes.isNotEmpty) {
      final error = pendientes.join('; ');
      traza.add('ERROR: $error');
      return ResultadoOzh.fallo(error, List.unmodifiable(traza));
    }
    final texto = partes.join(' ');
    final aviso = avisoAmbiguedad(o);
    if (aviso != null) traza.add('AVISO: $aviso');
    traza.add('resultado: $texto');
    return ResultadoOzh._(texto, null, List.unmodifiable(traza),
        aviso == null ? const [] : [aviso]);
  }

  /// "Para hablar del pasado se pone ʔoka al principio de la oración, y
  /// para el futuro, venu."
  void _tiempo() {
    final marca = switch (o.tiempo) {
      Tiempo.presente => null,
      Tiempo.pasado => fuente.tiempoPasado,
      Tiempo.futuro => fuente.tiempoFuturo,
    };
    if (marca == null) return;
    partes.add(marca);
    traza.add('tiempo ${o.tiempo.name} -> $marca (al principio)');
  }

  /// "La negación es la palabra ne delante del verbo."
  void _negacion() {
    if (!o.negada) return;
    partes.add(fuente.negacion);
    traza.add('negación -> ${fuente.negacion} (delante del verbo)');
  }

  /// "Las preguntas llevan el prefijo ʔa- en el verbo."
  void _verbo() {
    final raiz = fuente.verbo(o.verbo);
    if (raiz == null) {
      faltan.add('el verbo ${o.verbo}');
      return;
    }
    final palabra = _esPregunta ? '${fuente.prefijoPregunta}$raiz' : raiz;
    partes.add(palabra);
    traza.add('verbo: ${o.verbo} -> $palabra'
        '${_esPregunta ? ' (pregunta: ${fuente.prefijoPregunta}-)' : ''}');
  }

  /// "Justo después del verbo va siempre una de estas tres partículas."
  void _particula() {
    final s = o.sujeto;
    // Un sustantivo o "quién" se comportan como tercera persona.
    final (persona, numero) = switch (s) {
      Pronominal(:final persona, :final numero) => (persona, numero),
      Nominal(:final numero) => (Persona.tercera, numero),
      Incognita() => (Persona.tercera, Numero.singular),
    };
    final p = fuente.particulaPara(
        persona: persona, numero: numero, tiempo: o.tiempo);
    if (p == null) {
      pendientes.add('ninguna regla de datos/ozh/gramatica.json da la '
          'partícula para ${persona.name} ${numero.name} en ${o.tiempo.name}; '
          'Ozh no admite oraciones sin partícula');
      return;
    }
    partes.add(p);
    traza.add('partícula: $p (${persona.name} ${numero.name}, '
        '${o.tiempo.name}; bitácora O-01)');
  }

  void _participante(Participante p, String rol) {
    switch (p) {
      case Incognita(:final concepto):
        // La palabra interrogativa va al final y ocupa este hueco (O-03).
        if (o.modo == Modo.preguntaAbierta && o.interrogativo == concepto) {
          traza.add('$rol: incógnita $concepto, va al final');
        } else {
          pendientes.add('el $rol es la incógnita $concepto, pero la '
              'oración no es una pregunta abierta con esa palabra');
        }
      case Pronominal(:final persona, :final numero):
        final palabra = _pronombre(persona, numero, rol);
        if (palabra != null) partes.add(palabra);
      case final Nominal n:
        _nominal(n, rol);
    }
  }

  String? _pronombre(Persona persona, Numero numero, String rol) {
    final palabra = fuente.pronombre(persona, numero);
    final codigo = '${persona.index + 1}${numero == Numero.singular ? 's' : 'p'}';
    if (palabra == null) {
      faltan.add('el pronombre $codigo');
      return null;
    }
    traza.add('$rol: pronombre $codigo -> $palabra');
    return palabra;
  }

  void _nominal(Nominal n, String rol) {
    final piezas = <String>[];

    // "La cantidad la indica el número": va delante del sustantivo.
    final cantidad = n.cantidad;
    if (cantidad != null) {
      final numero = escribirNumero(cantidad, fuente.reglasNumero, fuente.cifra);
      if (numero.ok) {
        piezas.add(numero.texto!);
        traza.add('cantidad de $rol: $cantidad -> ${numero.texto}');
      } else {
        faltan.add('la cifra ${numero.cifrasDesconocidas.join(', ')} '
            '(cantidad $cantidad)');
      }
    }

    // "Los sustantivos no tienen plural."
    final sustantivo = fuente.sustantivo(n.concepto);
    if (sustantivo == null) {
      faltan.add('el sustantivo ${n.concepto}');
    } else {
      piezas.add(sustantivo);
      traza.add('$rol: ${n.concepto} -> $sustantivo (sin plural)');
    }

    // "El poseedor va detrás de lo poseído: thüm sha."
    final poseedor = n.poseedor;
    if (poseedor != null) {
      final palabra =
          _pronombre(poseedor.persona, poseedor.numero, 'poseedor del $rol');
      if (palabra != null) piezas.add(palabra);
    }

    partes.addAll(piezas);
  }

  /// "Si tienen palabra interrogativa, esa palabra va al final."
  void _interrogativo() {
    if (o.modo != Modo.preguntaAbierta) return;
    final concepto = o.interrogativo;
    if (concepto == null) {
      pendientes.add('la pregunta abierta no trae palabra interrogativa');
      return;
    }
    final palabra = fuente.interrogativo(concepto);
    if (palabra == null) {
      faltan.add('el interrogativo $concepto');
      return;
    }
    partes.add(palabra);
    traza.add('interrogativo $concepto -> $palabra (va al final)');
  }
}
