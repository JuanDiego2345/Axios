# Axios CLI — Sistema de Comunicación Interespecie

Aplicación de consola (CLI) para la traducción entre el español y lenguas alienígenas (Kethari y Ozh), con análisis léxico, análisis sintáctico por descenso recursivo, generación de lenguaje y persistencia completa en SQLite.

---

## 1. Requisitos Previos

- **Dart SDK**: `^3.13.5` o superior instalado.
- Instalar dependencias del proyecto:
  ```bash
  dart pub get
  ```

---

## 2. Cómo Compilar (Criterio 3)

El proyecto utiliza `package:sqlite3` con enlaces nativos (FFI). Para compilar a binario ejecutable nativo optimizado:

```bash
dart build cli -o build
```

El binario ejecutable y sus dependencias se generarán en:
- **Windows**: `build/bundle/bin/cli.exe`
- **Linux / macOS**: `build/bundle/bin/cli`

Para ejecutar el binario compilado:
```bash
# Windows
.\build\bundle\bin\cli.exe --help

# Linux / macOS
./build/bundle/bin/cli --help
```

---

## 3. Cómo Ejecutar en Modo Desarrollo

Se puede ejecutar directamente con el Dart SDK sin necesidad de compilar previamente:

```bash
# Desde la carpeta cli/
dart run bin/cli.dart [orden] [opciones]

# O desde la raíz del repositorio Axios/
dart run cli/bin/cli.dart [orden] [opciones]
```

Si se ejecuta sin argumentos, inicia la **consola interactiva (REPL)**.

---

## 4. Cuatro Órdenes Obligatorias (Criterio 19)

El CLI implementa las cuatro órdenes fundamentales del sistema Axios:

### 1. `traducir "<pregunta>"`
Procesa una pregunta u oración en español a través del pipeline (Fase Léxica $\rightarrow$ Analizador Sintáctico $\rightarrow$ Generadores Kethari y Ozh), entregando **ambas lenguas** simultáneamente, y **registra obligatoriamente cada consulta en la base de datos** (`axios.db`) con estado `sin validar` para garantizar que ninguna pregunta se pierda.

```bash
dart run bin/cli.dart traducir "¿Cuándo vendrán ustedes?"
```

**Banderas y opciones opcionales:**
- `-t`, `--traza`: Muestra las decisiones paso a paso en cada fase.
- `-a`, `--arbol`: Dibuja el árbol sintáctico intermedio en ASCII.
- `--tokens`: Muestra los tokens identificados y sus posiciones.

**Ejemplo con traza y árbol:**
```bash
dart run bin/cli.dart traducir "¿Cuándo vendrán ustedes?" -a -t
```

### 2. `cargar <archivo>`
Carga un archivo CSV (de léxico o de señales) en la base de datos SQLite con control de versiones:
```bash
dart run bin/cli.dart cargar datos/lexico_inicial.csv
dart run bin/cli.dart cargar datos/senales_inicial.csv
```

### 3. `historial [desde <fecha>]`
Consulta el registro cronológico de todas las preguntas traducidas o intentadas, junto con su estado y traducción:
```bash
# Todo el historial
dart run bin/cli.dart historial

# Filtrado a partir de una fecha ISO (YYYY-MM-DD)
dart run bin/cli.dart historial desde 2026-11-01
```

### 4. `palabra <término>`
Consulta un lema en el repositorio léxico de la base de datos, mostrando su categoría gramatical y sus traducciones conocidas en Kethari y Ozh:
```bash
dart run bin/cli.dart palabra agua
dart run bin/cli.dart palabra casa
```

---

## 5. Modo Consola Interactiva (REPL)

Al ejecutar `dart run bin/cli.dart` sin argumentos se entra a la sesión interactiva:

```text
axios> palabra agua
axios> traducir "¿Cuándo vendrán ustedes?"
axios> :arbol
axios> Queremos paz
axios> historial
axios> salir
```

**Comandos rápidos en consola:**
- `:traza`: Activa/desactiva la visualización de trazas.
- `:arbol`: Activa/desactiva la visualización del árbol sintáctico.
- `:tokens`: Activa/desactiva la visualización de tokens léxicos.
- `ayuda`: Muestra el manual de órdenes.
- `salir` o `:q`: Finaliza la sesión.

---

## 6. Pruebas Automatizadas

Para ejecutar la suite completa de pruebas unitarias y de integración:

```bash
dart test
```

Para ejecutar únicamente las pruebas del CLI y sus órdenes:
```bash
dart test test/cli_test.dart
```
