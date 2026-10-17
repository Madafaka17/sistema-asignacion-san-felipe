# Decisiones de implementación y desviaciones del diseño

Este registro anota en qué se aparta lo construido del diseño del capítulo III
de la tesis y de los UML iniciales, y por qué. Las decisiones marcadas como
**pendientes** deben resolverse con la asesora o con la empresa.

## 1. Tecnología: Dart y Flutter en lugar de Python y PyGAD

| Diseño (tesis) | Construido | Motivo |
|---|---|---|
| Python, PyGAD 3.7.0 para el ciclo generacional | Dart 3.13 en el servidor y en el núcleo; algoritmo genético propio que sigue la Tabla 22 línea por línea | Requisito del proyecto: arquitectura MVC con Flutter y Dart, un solo lenguaje en cliente y servidor |
| Interfaz sin tecnología fijada | Flutter 3.47 (web, Windows y Linux) con MVC | idem |

Consecuencias:

* Los operadores (torneo, cruce uniforme, mutación de un gen, reparación,
  elitismo y paradas) se implementaron sin biblioteca, con un generador
  `dart:math Random` con semilla; la reproducibilidad está probada.
* Los resultados del experimento (`formalizacion_algoritmo.md` §6) **no son
  comparables** con la Tabla 19 de la tesis, obtenida con PyGAD sobre otras
  instancias. Se reprodujo el protocolo (Tabla 17), no los números.
* El paquete `dominio` se comparte entre cliente y servidor: modelos,
  contrato y matriz de permisos son el mismo código en ambos lados.

## 2. Método de optimización — algoritmo genético (sección 3.3)

La sección 3.3 de la tesis **determina el algoritmo genético** con la matriz de
decisión empírica de la ejecución oficial v1, definida por un protocolo
registrado antes de ejecutar: AG **4.45**, programación lineal entera 4.05,
búsqueda tabú 2.80 y voraz 2.35 (Tabla 19). La sensibilidad del presupuesto
(v2, Tabla 20) mantiene el orden y sube el AG a **4.85**. El análisis
exploratorio de la definición de `D` (Anexo F) invierte el orden en v1D (PLE
4.50, AG 4.45), por lo que la forma de medir el equilibrio debe ratificarse
con la empresa (pregunta 8 de E-01). La evidencia completa está en
[`experimentos/`](../experimentos/README.md).

Consecuencias para el sistema:

* El método de producción es el AG (`optimizacion.metodo: algoritmo_genetico`
  en `config/parametros.yaml`).
* PLE, voraz y búsqueda tabú son **comparadores experimentales** y no métodos
  adicionales del sistema final. El `AlgoritmoVoraz` del paquete `dominio` se
  conserva como línea base de las pruebas del núcleo y de
  `tool/experimento.dart`; no se ofrece como alternativa en la interfaz.
* Los resultados de `tool/experimento.dart` (AG y voraz en Dart, otras
  instancias) **no son una repetición** de la matriz de decisión, que se
  obtuvo con las implementaciones Python del experimento.
* Las versiones anteriores de este documento citaban un puntaje de 4,35 para
  la PLE y una determinación pendiente: correspondían a una versión previa de
  la tesis y quedan reemplazadas por lo anterior.

## 3. Decisiones del modelo que la tesis no fija

| Tema | Decisión | Dónde |
|---|---|---|
| Γ (ecuación 4) | **Implícito**: el predicado `enConflicto` se evalúa sobre las alternativas elegidas; no se precalcula el conjunto de pares (crecería con `K²`). La evaluación cuesta `O(n²)` en vez de `O(p + K + n log n)` | `optimizacion/evaluador.dart` |
| `H_s` | Salidas autorizadas de la ruta entre la hora solicitada y la hora solicitada **+ 60 min** (`tolerancia_salida_min`) | `constructor_instancia.dart` |
| `Ret(X)` | Solo se mide contra la programación comprometida `b(s)`, como dice la tesis; en la primera generación de un turno mover un servicio dentro de la tolerancia no suma retraso (lo desalienta `Tm`) | `evaluador.dart` |
| Referencias `b_j` | `b_Ret = 60` min, `b_R` = número de servicios con `b(s)` (o 1), `b_Tm = 60 · |V|` min, `b_D = 60` min | `config/parametros.yaml`, `constructor_instancia.dart` |
| `λ(c, v)` | Matriz licencia → categoría vehicular configurable; los valores por defecto **deben contrastarse** con el Reglamento Nacional de Licencias de Conducir vigente | `config/parametros.yaml` |
| `E_c` | Además de `disponible` y la licencia vigente, se excluye al conductor que ya agotó su límite (`H_c0 ≥ H_cmáx`) | `constructor_instancia.dart` |
| Conflictos residuales | Si tras la reparación queda un cruce o un exceso, el **servicio de menor prioridad** se reporta como incidencia con su motivo, para que el conjunto asignado tenga Φ = 0 (línea «Reportar los conflictos residuales» de la Tabla 22) | `decodificador.dart` |
| Ajuste manual (HU-09) | Solo se acepta una alternativa de `A_s`; los cruces que genere se guardan marcados como `conflicto` y bloquean la aprobación | `programacion_servicio.dart` |
| Prioridad | `p_s ∈ {1, 2, 3}`, 3 = más alta (Tabla 11 de la tesis); el cliente la muestra como Baja, Media y Alta | `servicio_programado.dart` |
| Hora local | Desfase fijo UTC−5 (Perú no usa horario de verano); las marcas de tiempo se guardan en hora local | `infraestructura/reloj.dart`, `docker-compose.yml` |

## 4. Arquitectura y UML

| Diseño inicial | Construido | Motivo |
|---|---|---|
| Núcleo de optimización que intercambia instancias y programaciones con la lógica de negocio en **JSON** (RNF-03) | El núcleo es un paquete Dart que recibe y devuelve **objetos tipados** (`InstanciaTurno`, `ResultadoOptimizacion`) y se ejecuta en un `Isolate` del servidor; JSON solo en la frontera HTTP | Mismo lenguaje en ambos lados: el contrato lo impone el compilador. El aislamiento (RNF-07) se mantiene: el núcleo no importa nada de la base de datos ni de la interfaz |
| Capas presentación / lógica / datos | Cliente **MVC** (vistas, controladores `ChangeNotifier`, modelo con repositorios remotos) y servidor **Controller–Service–Repository** | Separación verificable: solo `cliente/lib/modelo/api/` usa HTTP y solo `servidor/lib/src/repositorios/` usa SQL |
| — | `GET /api/programaciones` devuelve **resúmenes** sin asignaciones; el detalle se pide por id | Evita transferir el historial completo; el controlador del cliente pide el detalle de la ejecución abierta |
| — | Verificación de versión en los dos sentidos (`X-Version-Api`, `X-Version-Cliente` → 426) | Requisito de compatibilidad cliente–servidor (Sesión 7) |

## 5. Seguridad

* Contraseñas: PBKDF2-HMAC-SHA256 con 100 000 iteraciones y sal aleatoria
  (la tesis pide «una función de resumen criptográfico»).
* Sesión: JWT HS256 de 15 min en memoria + token de actualización rotativo en
  cookie `HttpOnly; SameSite=Strict; Secure`.
* **TLS con MySQL sin verificación del certificado.** MySQL 8.4 exige TLS con
  `caching_sha2_password`, y el conector `mysql_client_plus 0.1.3` cifra la
  conexión pero no verifica el certificado del servidor. En Docker el tráfico
  no sale de la red interna del proyecto; si la base se instala en otro
  equipo, debe quedar en una red privada.
* Puertos publicados solo en `127.0.0.1`; para la red de la empresa se
  recomienda HTTPS delante de nginx.

## 6. Alcance no cubierto o no verificado en esta versión

* **RNF-04 (usabilidad)** requiere una prueba con el personal de despacho.
* **Cliente de escritorio en Windows**: el proyecto incluye el *runner* de
  Windows, pero solo se compiló y probó en Linux y en la web (los
  navegadores de Windows usan el cliente web).
* **RNF-05**: `herramientas/respaldo.sh` hace el respaldo y la restauración;
  programarlo a diario (cron o Programador de tareas) es parte de la
  instalación en la empresa.
* El cliente web pide a `fonts.gstatic.com` las fuentes de respaldo de
  caracteres poco comunes solo si hay internet; Roboto y los íconos van
  empaquetados.

## 7. Restos del prototipo anterior en Python

Las carpetas y archivos `src/`, `tests/`, `requirements.txt`, `pytest.ini`,
`.python-version` y `config/parametros_ga.yaml` pertenecen a un primer
prototipo en Python que esta versión reemplaza. **No los usa ninguna parte
del sistema** (ni Docker ni las pruebas); se conservan en el historial y
pueden eliminarse con un commit propio cuando el autor lo decida.

## 8. Seguimiento de la Tabla 48 de la tesis (diferencias con el diseño requerido)

La versión de la tesis con el capítulo V revisó el commit `b54c86b` y listó
en su Tabla 48 lo que el prototipo debía adecuar. Estado en este repositorio:

| Aspecto (Tabla 48) | Pendiente señalado | Estado |
|---|---|---|
| Tecnología y comparación | publicar `core/` y `experimentos/poc_cap3/`; no presentar los resultados Dart como repetición de la matriz | Paquete `experimentos/sanfelipe/` publicado sin cambios (huellas verificadas). `core/` y `poc_cap3/` **no se recibieron**: siguen pendientes del autor ([`experimentos/README.md`](../experimentos/README.md)). Los resultados Dart se presentan como verificación del prototipo (§2) |
| Operación por cola | modelar la posición de cola y el par habitual/reemplazo | en desarrollo |
| Duraciones y horas | conservar 30/150 min de ida declarados sin tratarlos como ciclos demostrados | en desarrollo (datos de demostración) |
| Procedencia y versiones | snapshot inmutable de entrada, huella, versión del algoritmo y versión de cada ajuste | en desarrollo |
| Comunicación y concurrencia | probar concurrencia e idempotencia; el plan 202 es ampliación propuesta | en desarrollo (versión esperada al aprobar) |
| Tiempo y complejidad | aislar el tiempo del núcleo del tiempo de la API | en desarrollo |
| Repositorio y pruebas | etiquetas remotas; reporte E2E; cobertura; usabilidad y recuperación | CI publica la salida E2E y las capturas de cada commit (artefacto `evidencia-e2e`) y la cobertura del núcleo (artefacto `cobertura-dominio`, umbral 80 %). Las etiquetas existen localmente pero la sesión que las creó no pudo subirlas: ver README. Usabilidad y recuperación requieren la instalación en la empresa |
| Documentación previa | alinear con GA 4.45 (v1), 4.85 (v2) y la sección 3.3 | hecho (§2) |
