# Bitácora de decisiones: módulo léxico (integrante 1)

Formato: problema, opciones, decisión y prueba que la demuestra
(`cli/test/lexico/`).

---

### L-01 · 12/11/2026 · Tildes y ñ
- **Problema:** las preguntas llegan con o sin tildes y el vocabulario debe coincidir en ambos casos.
- **Opciones:** (a) conservar las tildes; (b) quitarlas y conservar la ñ; (c) quitar todo, incluida la ñ (ñ→n).
- **Decisión:** (b). Se quitan tildes y diéresis y se conserva la ñ, porque "año" y "ano" son palabras distintas. Qué/que y cuándo/cuando se distinguen por los signos y la posición.
- **Prueba:** `normalizador_test.dart` → "pasa a minúsculas y quita tildes", "conserva la ñ".

### L-02 · 12/11/2026 · "un" / "una": ¿artículo o número?
- **Problema:** "una nave" puede ser un artículo o la cantidad 1.
- **Opciones:** (a) convertir siempre a 1; (b) no convertir cuando aparecen solos.
- **Decisión:** (b). Solos son artículos. Dentro de una cantidad sí cuentan ("ciento un", "veintiuna"). "uno" solo sí se convierte en 1.
- **Prueba:** `normalizador_test.dart` → "un / una sueltos son artículos".

### L-03 · 12/11/2026 · Posición de los tokens
- **Problema:** el normalizador cambia la longitud del texto ("dos mil quince" → "2015"), así que la posición en el original y en el normalizado no coinciden.
- **Opciones:** (a) posición en el texto original; (b) posición en el texto normalizado.
- **Decisión:** (b). Es el texto que lee el AFD. El historial guarda los dos textos para poder relacionarlos.
- **Prueba:** `analizador_lexico_test.dart` → "pregunta simple con posiciones".

### L-04 · 12/11/2026 · Umbral del corrector
- **Problema:** un umbral alto inventa palabras y uno bajo no corrige nada.
- **Opciones:** (a) distancia fija de 2; (b) distancia según la longitud.
- **Decisión:** (b). 1–2 letras: no se corrige; 3–5 letras: distancia 1; 6 o más: distancia 2. Las palabras cortas tienen muchas vecinas, y la regla de Axios es "no se inventa nada".
- **Prueba:** `corrector_test.dart` → "umbral según longitud", "palabras de 1 o 2 letras no se corrigen".

### L-05 · 12/11/2026 · Empates en el corrector
- **Problema:** varias palabras pueden quedar a la misma distancia.
- **Opciones:** (a) no corregir si hay empate; (b) desempatar con reglas fijas.
- **Decisión:** (b). Gana la que tiene la misma primera letra, luego la de longitud más parecida y luego el orden alfabético. La corrección se marca `ambigua` y guarda las empatadas para el historial y la traza.
- **Prueba:** `corrector_test.dart` → "desempate: prefiere la misma primera letra".

### L-06 · 12/11/2026 · Palabras numéricas dentro del normalizador
- **Problema:** el enunciado prohíbe escribir el léxico en el código, pero el normalizador debe leer "dos mil quince".
- **Decisión:** las palabras numéricas del español son reglas de lectura de cantidades, no léxico de traducción. Viven en `numeros_texto.dart`. Los números en Kethari y Ozh sí van en la BD.
- **Pendiente:** confirmar con el docente; si no lo acepta, se pasan a la BD.

### L-07 · 12/11/2026 → resuelta el 19/11/2026 · Cantidades en letras mal escritas
- **Problema:** el normalizador convertía las cantidades antes de que actuara el corrector, así que "quinse naves" no se convertía en 15. Volver a convertir después de corregir no bastaba: "dos mil quinse" quedaba como `2000` + `15`.
- **Opciones:** (a) dejarlo como limitación; (b) una segunda conversión después del corrector; (c) separar el normalizador en dos momentos: el texto (tildes, signos) antes del autómata, y las cantidades después del corrector.
- **Decisión (19/11):** (c). Orden final: normalizar texto → AFD → corregir → normalizar números. Las palabras numéricas se agregan al vocabulario del corrector para que se corrijan en vez de confundirse con otras palabras. Las posiciones de los tokens se cuentan sobre el texto antes de convertir (L-03), y el token de número toma la posición de su primera palabra.
- **Prueba:** `fase_lexica_test.dart` → "corrige una cantidad mal escrita y luego la convierte", "error dentro de una cantidad de varias palabras".

### L-08 · 19/11/2026 · Dónde se usan expresiones regulares
- **Problema:** el enunciado solo permite expresiones regulares en la normalización, y la primera versión de `numeros_texto.dart` las usaba para partir el texto.
- **Opciones:** (a) defenderlo porque la conversión de números es parte del normalizador; (b) quitarlas.
- **Decisión:** (b). Con L-07 la lectura de cantidades trabaja sobre la lista de palabras que entrega el autómata, así que ya no necesita expresiones regulares. Ahora las únicas del módulo están en `Normalizador.normalizar` (signos, separadores de miles y espacios). El AFD y el corrector nunca las usaron.
- **Prueba:** `grep -rn RegExp cli/lib/lexico` solo encuentra `normalizador.dart`.
