/// Generador de Kethari (fase 7): convierte el árbol intermedio en una
/// oración Kethari siguiendo el manual v0.7, sección 3.3.
///
/// Reglas que aplica:
/// - Orden sujeto, objeto, verbo. El sujeto aparece siempre.
/// - Tiempo como sufijo del verbo (`-ok` pasado, `-ime` futuro).
/// - Negación como prefijo del verbo (`nu-`).
/// - Plural como sufijo del sustantivo (`-esh`).
/// - El poseedor va delante de lo poseído. No hay artículos.
/// - Los números van delante del sustantivo, en base 6 (`ra-sel` = 15), y el
///   sustantivo lleva `-esh` también con número.
/// - Las preguntas terminan en `ka`; la palabra interrogativa va al
///   principio.
///
/// Las palabras y los afijos salen de una [FuenteKethari]; aquí solo está
/// el orden. Si falta una palabra, no se inventa: se explica (bitácora K-06).
library;

import '../sintactico/arbol.dart';
import 'fuente_kethari.dart';
import 'numeros.dart';

/// Lo que devuelve el generador: la oración o la explicación de por qué no
/// la hay. [traza] cuenta cada decisión, para el modo traza.
class ResultadoKethari {
  /// Oración en Kethari. `null` si no se pudo generar.
  final String? texto;

  /// Por qué no se generó. `null` si todo salió bien.
  final String? error;

  final List<String> traza;

  const ResultadoKethari._(this.texto, this.error, this.traza);

  bool get ok => texto != null;

  @override
  String toString() => ok ? texto! : 'sin traducción: $error';
}

class GeneradorKethari {
  final FuenteKethari fuente;

  const GeneradorKethari(this.fuente);

  ResultadoKethari generar(Oracion oracion) =>
      _Generacion(fuente, oracion).ejecutar();
}

/// El estado de una sola generación.
class _Generacion {
  final FuenteKethari fuente;
  final Oracion o;

  final partes = <String>[];
  final traza = <String>[];

  /// Conceptos sin palabra Kethari conocida.
  final faltan = <String>[];

  /// Cosas que el árbol pide y el generador todavía no sabe hacer.
  final pendientes = <String>[];

  _Generacion(this.fuente, this.o);

  AfijosKethari get a => fuente.afijos;

  ResultadoKethari ejecutar() {
    _interrogativo();
    _participante(o.sujeto, 'sujeto');
    final objeto = o.objeto;
    if (objeto != null) _participante(objeto, 'objeto');
    _verbo();
    _particulaPregunta();

    if (faltan.isNotEmpty) {
      final error = 'el manual no tiene palabra Kethari para '
          '${faltan.join(', ')}. No se inventan palabras.';
      traza.add('ERROR: $error');
      return ResultadoKethari._(null, error, List.unmodifiable(traza));
    }
    if (pendientes.isNotEmpty) {
      final error = pendientes.join('; ');
      traza.add('ERROR: $error');
      return ResultadoKethari._(null, error, List.unmodifiable(traza));
    }
    final texto = partes.join(' ');
    traza.add('resultado: $texto');
    return ResultadoKethari._(texto, null, List.unmodifiable(traza));
  }

  /// "Si llevan una palabra interrogativa, esa palabra va al principio."
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
    traza.add('interrogativo $concepto -> $palabra (va al principio)');
  }

  void _participante(Participante p, String rol) {
    switch (p) {
      case Incognita(:final concepto):
        // "¿Quién envió...?": la palabra interrogativa ya ocupa el
        // principio, que es justo el lugar del sujeto. No se repite (K-02).
        if (o.modo == Modo.preguntaAbierta && o.interrogativo == concepto) {
          traza.add('$rol: incógnita $concepto, ya está al principio');
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
    final codigo = codigoRasgos(persona, numero);
    final palabra = fuente.pronombre(persona, numero);
    if (palabra == null) {
      faltan.add('el pronombre $codigo');
      return null;
    }
    final nota = codigo == '1p' ? ' (anir: bitácora K-01)' : '';
    traza.add('$rol: pronombre $codigo -> $palabra$nota');
    return palabra;
  }

  void _nominal(Nominal n, String rol) {
    final piezas = <String>[];

    // "El poseedor va delante de lo poseído: ul vael".
    final poseedor = n.poseedor;
    if (poseedor != null) {
      final palabra =
          _pronombre(poseedor.persona, poseedor.numero, 'poseedor del $rol');
      if (palabra != null) piezas.add(palabra);
    }

    // "Los números van delante del sustantivo." Si hay poseedor, va antes
    // del número: el poseedor abre el grupo (bitácora K-08).
    final cantidad = n.cantidad;
    if (cantidad != null) {
      final numero = escribirNumero(cantidad, fuente.numeros, fuente.cifra);
      if (numero.ok) {
        piezas.add(numero.texto!);
        traza.add('cantidad de $rol: $cantidad -> ${numero.texto} '
            '(base ${fuente.numeros.base}: ${numero.cifrasUsadas.join(' ')})');
      } else {
        faltan.add('la cifra ${numero.cifrasDesconocidas.join(', ')} '
            '(cantidad $cantidad)');
      }
    }

    final raiz = fuente.sustantivo(n.concepto);
    if (raiz == null) {
      faltan.add('el sustantivo ${n.concepto}');
      return;
    }
    final plural = n.numero == Numero.plural;
    final palabra = plural ? '$raiz${a.plural}' : raiz;
    piezas.add(palabra);
    traza.add('$rol: ${n.concepto} -> $palabra'
        '${plural ? ' (plural -${a.plural})' : ''}');

    partes.addAll(piezas);
  }

  void _verbo() {
    final raiz = fuente.verbo(o.verbo);
    if (raiz == null) {
      faltan.add('el verbo ${o.verbo}');
      return;
    }
    final sufijo = switch (o.tiempo) {
      Tiempo.presente => a.presente,
      Tiempo.pasado => a.pasado,
      Tiempo.futuro => a.futuro,
    };
    final prefijo = o.negada ? a.negacion : '';
    final palabra = '$prefijo$raiz$sufijo';
    partes.add(palabra);
    traza.add('verbo: ${o.verbo} -> $palabra '
        '(${o.tiempo.name}${o.negada ? ', negado' : ''}, va al final)');
  }

  /// "Las preguntas terminan con la partícula ka."
  void _particulaPregunta() {
    if (o.modo == Modo.afirmacion) return;
    partes.add(a.pregunta);
    traza.add('pregunta -> ${a.pregunta} al final');
  }
}
