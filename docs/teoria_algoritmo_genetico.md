# Diseño del algoritmo genético (sección 3.4 de la tesis)

Implementación: `paquetes/dominio/lib/src/optimizacion/algoritmo_genetico.dart`
y `reparacion.dart`. Cada componente remite a la subsección de la tesis que
lo define; el pseudocódigo completo (Tabla 22) y su correspondencia línea a
línea con el código están en
[`formalizacion_algoritmo.md` §3](formalizacion_algoritmo.md#3-algoritmo-genético-tabla-22-y-ecuación-15).

## 1. Fundamento

Un algoritmo genético mantiene una población de soluciones codificadas
(cromosomas), evalúa su aptitud y, generación tras generación, selecciona
progenitores, los recombina (cruce), introduce variaciones (mutación) y
reemplaza la población, conservando a los mejores (elitismo). No garantiza el
óptimo, pero explora varias regiones del espacio a la vez y evalúa
directamente `F(X)`, sin linealizar sus términos no lineales (desviación
estándar `D`, tiempo muerto `Tm`).

## 2. Componentes

| Componente | Subsección | Diseño | Código |
|---|---|---|---|
| Representación | 3.4.1, ec. (15) | un gen por servicio de `S′`; `α_s` = índice de la alternativa en `A_s`. Cumple la asignación única (3) por construcción y nunca usa recursos no disponibles, porque `A_s` ya los excluye | `List<int>` |
| Población inicial | 3.4.2 | `P` cromosomas con genes uniformes en `{0, …, |A_s| − 1}`, cada uno reparado | `resolver`, líneas 49–56 |
| Aptitud | 3.4.3, ec. (7)–(8) | `F = −[M·Φ + E + J]` con `M = 10⁶`: toda solución factible supera a cualquier infactible | `Evaluador` |
| Selección | 3.4.4 | torneo de tamaño `k = 3` con reemplazo: presión selectiva baja, conserva diversidad | `_torneo` |
| Cruce | 3.4.5 | uniforme: cada gen se hereda de uno u otro progenitor con probabilidad ½, en la misma posición (los genes son posiciones de servicios, no permutaciones) | `_cruceUniforme` |
| Mutación | 3.4.6 | con probabilidad `p_m` por descendiente, un servicio con más de una alternativa cambia a otra elegida al azar (vehículo, conductor y salida a la vez; la ruta no cambia) | `_mutar` |
| Elitismo | 3.4.7 | los `redondeo(ε·P)` = 5 mejores pasan intactos: la mejor aptitud nunca empeora | líneas 73–80 |
| Parada | 3.4.8 | la primera que ocurra: `G_máx` generaciones, `g_conv` generaciones sin mejora o `t_lím` segundos | líneas 69–72 |
| Reparación | 3.4.9 | paso 1: en cada conflicto de Γ se conserva el de mayor prioridad (en empate, el más temprano) y se reasigna el otro a la primera alternativa libre; paso 2: se corrigen los excesos de conducción empezando por el servicio de menor prioridad; hasta `ϱ = 5` pasadas; determinista | `Reparador` |

## 3. Parámetros (Tabla 23)

Se leen de `config/parametros.yaml` (`algoritmo_genetico:`); el servidor los
valida al iniciar y guarda los efectivos con cada programación.

| Parámetro | Símbolo | Valor | Clave YAML |
|---|---|---|---|
| Tamaño de la población | P | 50 | `tamano_poblacion` |
| Generaciones máximas | G_máx | 100 | `generaciones_maximas` |
| Probabilidad de cruce | p_c | 0,80 | `probabilidad_cruce` |
| Probabilidad de mutación (por descendiente) | p_m | 0,10 | `probabilidad_mutacion` |
| Tamaño del torneo | k | 3 | `tamano_torneo` |
| Proporción de élite | ε | 0,10 (5 élites) | `proporcion_elite` |
| Generaciones sin mejora | g_conv | 20 | `generaciones_sin_mejora` |
| Límite de tiempo | t_lím | 300 s (RNF-02) | `limite_tiempo_s` |
| Pasadas de reparación | ϱ | 5 | `pasadas_reparacion` |
| Semilla | — | 1 | `semilla` |

Pesos y referencias de `J` (sección `modelo:`): `w_j = 0,25` cada uno (pesos
iguales de las pruebas de concepto, a calibrar con la empresa) y
`b_Ret = 60 min`, `b_R` = servicios comprometidos, `b_Tm = 60 min · |V|`,
`b_D = 60 min`.

## 4. Reproducibilidad

Con la misma semilla, los mismos datos y las mismas versiones (fijadas en
`pubspec.lock`), la propuesta es idéntica; lo comprueban
`paquetes/dominio/test/algoritmos_test.dart` y la prueba de aceptación
«con la misma semilla y los mismos datos la propuesta es la misma». La
semilla y los parámetros efectivos quedan en la tabla `programacion`.

## 5. Calibración pendiente

La tesis prevé calibrar `P` (hasta 100) y `G_máx` (hasta 200) y fijar los
pesos `w_j` con la empresa (secciones 3.4.3 y 3.4.11). Como los parámetros
están en el archivo de configuración, la calibración no requiere cambiar el
código; `paquetes/dominio/tool/experimento.dart` reproduce el protocolo de las
pruebas de concepto para comparar configuraciones.
