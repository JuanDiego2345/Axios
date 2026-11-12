# Interfaz del módulo léxico (integrante 1)

> **Estado: PROPUESTA (12/11/2026). Pendiente de aprobación del grupo.**
> Si alguien necesita otro campo o tipo de token, lo dice antes de que el parser dependa de esto.

## Cómo se usa

```dart
import 'package:cli/lexico.dart';

// El vocabulario español sale de la BD (integrante 4) + formas verbales (integrante 2).
final fase = FaseLexica(vocabularioEspanol);
final r = fase.procesar('¿Kuando LLEGAN las nabes?');

r.tokens;               // List<Token>  -> lo que consume el parser
r.normalizado;          // '¿kuando llegan las nabes?'
r.correcciones;         // [kuando -> cuando (d=1), nabes -> naves (d=1)]
r.numerosConvertidos;   // cantidades en letras pasadas a cifras
r.palabrasDesconocidas; // palabras sin corrección posible
r.erroresLexicos;       // caracteres que el AFD no reconoce
r.traza;                // transiciones del AFD si se llamó con conTraza: true
```

## Token (`lib/lexico/token.dart`)

| Campo | Tipo | Descripción |
|---|---|---|
| `tipo` | `TipoToken` | `palabra`, `numero`, `abreInterrogacion`, `cierraInterrogacion`, `coma`, `punto`, `desconocido`, `fin` |
| `lexema` | `String` | Texto del token, **ya corregido** y en minúsculas sin tildes (`cuando`, `llegaran`) |
| `posicion` | `int` | Índice desde 0 en el texto normalizado |
| `columna` | `int` | `posicion + 1`, para mensajes |
| `valor` | `int?` | Solo en `numero` |
| `original` | `String?` | Lexema antes de corregir; `null` si no se corrigió |

Reglas para quien consume los tokens:

1. La lista **siempre termina en un token `fin`**. El parser no tiene que revisar límites.
2. El léxico **no clasifica** las palabras (pronombre, verbo, interrogativo...). Eso necesita el vocabulario de la BD y lo hace el parser. Así el léxico no lleva vocabulario dentro del código.
3. Las palabras llegan **sin tildes**: `que`/`qué` y `cuando`/`cuándo` son el mismo lexema. Si es pregunta o no se decide por `¿`, `?` y la posición de la palabra, no por la tilde.
4. Las cantidades en letras llegan como `numero` (`dos mil quince` → `numero(2015)`). `un`/`una` sueltos llegan como `palabra` (son artículos).
5. Un token `desconocido` no detiene el análisis. El sistema debe responder explicando que hay un carácter inválido (condición 1 de Axios: ninguna pregunta se pierde).

## Lo que el léxico necesita de otros módulos

- **Integrante 4 (BD):** una función que devuelva todas las palabras españolas conocidas, `Iterable<String>`.
- **Integrante 2 (morfología):** las formas conjugadas de los verbos (`llegan`, `llegaron`, `vendran`...) tienen que estar en ese vocabulario. Si no, el corrector cambiaría un verbo bien escrito por otra palabra parecida. Hay que acordar si la BD guarda las formas o si la morfología las genera.
