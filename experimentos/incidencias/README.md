# Prueba de reasignación ante incidencias de despacho

¿Recomienda el núcleo de optimización una reasignación válida de unidades y conductores
cuando ocurre una incidencia a mitad del turno? Esta carpeta conserva el protocolo, el
código, los resultados y los registros de esa prueba. Las instancias son **turnos
sintéticos** con la estructura de la operación de Soritor: **no son datos de la empresa**.

## Procedencia

Los 16 archivos de esta carpeta (todos menos este `README.md`) son los del paquete
`experimentos_incidencias.zip` entregado por el autor el 24/11/2026, copiados **sin
cambios**. El protocolo se registró antes de ejecutar la prueba, con dos adendas
posteriores (`registro_protocolo.txt`):

| Registro (UTC) | Qué se fijó | Antes o después de observar resultados |
|---|---|---|
| 24/11/2026 03:32:00 | Secciones 1 a 7 de `PROTOCOLO.md` (variante **v1**), `reasignacion.py` y las huellas de los módulos que usa | Antes de ejecutar |
| 24/11/2026 03:36:18 | Sección 8: mínimos exactos (`minimos.py`) y variante **v2** (regla de contingencia) | Después de v1 y antes de v2 |
| 24/11/2026 03:47:17 | Sección 8.3: mínimo sin límite de conducción (exploratorio) | Después de un diagnóstico de v1 y v2 |

Las huellas de los tres archivos de la carpeta coinciden con las **últimas** registradas
para cada uno, y las de los módulos importados —`generador_sanfelipe.py`, `metodos.py` y
`validador.py` de [`../sanfelipe`](../sanfelipe) y [`../poc_cap3`](../poc_cap3), y
`core/{domain,fitness,conflicts,repair,scheduler}.py`— coinciden con las de este
repositorio: la prueba usa el mismo generador, el mismo AG (configuración oficial v1 de
la Tabla 18), la misma regla voraz, la misma F(X) y el mismo validador independiente que
el experimento del capítulo 3. La integración continua lo comprueba en cada commit.

## Diseño

- **Turnos:** n = 28, 56 y 112 servicios; instancias 101, 102 y 103 del generador. La
  programación aprobada es la oculta del generador, sin cruces ni excesos.
- **Momento:** minuto 300 del turno (11:00). Los servicios ya iniciados se mantienen;
  solo se reasignan los pendientes.
- **Incidencias** (una por escenario, recurso elegido con regla fija): I1 avería de la
  unidad con más servicios pendientes; I2 ausencia del conductor con más servicios
  pendientes; I3 demora de 60 min de un viaje en curso. 9 turnos × 3 = **27 escenarios**.
- **Métodos:** sin reasignar; regla voraz (determinista); AG v1 con las semillas 1 a 10
  (270 ejecuciones).
- **Medidas:** validez (Φ = 0 y 0 incumplimientos según el validador), servicios
  cambiados (obligados y adicionales), retraso respecto de la salida aprobada y tiempo de
  cómputo (presupuesto de RNF-02: 300 s).
- **v2 (supuesto por validar con la empresa):** ante una incidencia, el encargado puede
  autorizar para los servicios afectados cualquier unidad operativa con uno de sus
  conductores autorizados y una demora de 0, 10, 20 o 30 min.
- **Mínimos exactos** (`minimos.py`, PuLP y CBC): el menor Φ posible si se asigna cada
  servicio pendiente (`phi_min`), el menor número de servicios que hay que dejar sin
  asignar para que el resto sea válido, y `phi_min` sin límite de conducción (8.3).

## Resultados

| | v1: alternativas del modelo | v2: regla de contingencia |
|---|---|---|
| Servicios pendientes sin ninguna alternativa admisible | 9 (uno en cada uno de 9 escenarios) | 0 |
| Escenarios en que todos los servicios con alternativa pueden reasignarse sin cruces ni excesos (`phi_min` = 0) | 5 de 27; en los 5 queda además un servicio sin alternativa | 7 de 27 |
| Escenarios en que hay que dejar sin asignar 1 o 2 servicios que sí tienen alternativa | 22 (16 con 1; 6 con 2) | 20 (todos con 1) |
| Sin límite de conducción (exploratorio, 8.3): escenarios con `phi_min` = 0 | 12 de 27 | 20 de 27 |
| **AG**: ejecuciones válidas | 50 de 270 (18.5 %): **las 50 de los 5 escenarios posibles** | 70 de 270 (25.9 %): **las 70 de los 7 escenarios posibles** |
| **AG**: Φ igual al mínimo exacto | 270 de 270 | 257 de 270 |
| **AG**: cambios adicionales y retraso (media por ejecución) | 0.96 servicios; 13.4 min | 0.64 servicios; 17.5 min |
| **AG**: tiempo medio y máximo | 0.40 s; 1.12 s | 1.34 s; 6.72 s |
| **Regla voraz**: ejecuciones válidas | 3 de 27 (11.1 %) | 0 de 27 |
| **Regla voraz**: Φ igual al mínimo exacto | 8 de 27 | 1 de 27 |
| **Regla voraz**: cambios adicionales y retraso (media) | 5.22 servicios; 27.8 min | 5.07 servicios; 21.5 min |
| Sin reasignar: ejecuciones válidas | 0 de 27 | 0 de 27 |

Detalle por tamaño y por incidencia en `resumen.json` y `resumen_v2.json`; por escenario,
en `escenarios*.csv`, `resultados_crudos*.csv` y `minimos*.csv`; salida de cada
ejecución, en los `.log`.

**Qué muestran.** Cuando existe una reasignación válida, el AG la encontró con las 10
semillas, en v1 y en v2. En esas ejecuciones válidas cambió en promedio 0.2 servicios no
afectados en v1 y 0.14 en v2, con un retraso medio de 4.0 y 12.4 min, y su tiempo máximo
fue de 6.72 s, muy por debajo de los 300 s de RNF-02. La regla voraz lo logró en 3 de 5
escenarios en v1, cambiando en promedio 2.33 servicios no afectados, y en ninguno en v2.
Pero con las alternativas del modelo (v1) **ningún escenario permite cubrir todos los
servicios pendientes**: siempre queda al menos uno sin asignar,
porque no tiene alternativa o porque las que tiene chocan o exceden un límite de
conducción. Con la regla de contingencia (v2), 7 de 27 lo permiten. El límite lo pone la
instancia, no el método: sin el límite de conducción, los escenarios con `phi_min` = 0
pasan de 5 a 12 en v1 y de 7 a 20 en v2 (sección 8.3), y en los demás lo que corresponde
es dejar el servicio sin asignar como incidencia o que el encargado autorice una
excepción.

**Límites.** Turnos sintéticos, una incidencia por escenario y un solo momento del turno.
v2 y los análisis de la sección 8 se definieron después de observar v1 y se informan como
tales; la regla de contingencia de v2 es un supuesto que la empresa debe validar (E-01 y
O-01). La prueba no compara el sistema con el despacho manual ni mide una mejora
organizacional.

## Reproducción

```sh
pip install --require-hashes --no-deps -r requirements.lock   # desde la raíz del repositorio
cd experimentos/incidencias
python reasignacion.py ejecutar v1 && python reasignacion.py analizar v1   # ~2 min
python reasignacion.py ejecutar v2 && python reasignacion.py analizar v2   # ~6 min
python minimos.py v1 && python minimos.py v2                               # segundos
```

`ejecutar`, `analizar` y `minimos.py` **reescriben** los resultados registrados de esta
carpeta: para verificarlos, ejecútelos en una copia y compare.

**Verificación del 24/11/2026.** Se repitieron las cuatro ejecuciones en una copia, con el
entorno fijado en `requirements.lock` (CPython 3.11.18, NumPy 2.4.4, PyGAD 3.7.0 y PuLP
2.9.0 con CBC); el autor había usado CPython 3.13.18 y NumPy 2.5.3 (`resumen.json`).
Resultado: escenarios y mínimos exactos de v1 y v2 idénticos byte a byte; resúmenes
idénticos salvo el entorno y los tiempos; resultados crudos iguales campo por campo
—validez, Φ, validador, cambios y retraso— salvo el tiempo de cómputo y el último dígito
de F en 1 de 324 filas de v1 y 15 de 324 de v2 (diferencia máxima de 5.6 × 10⁻¹⁷, por
redondeo). Tiempos: v1, 1 min 47 s; v2, 5 min 22 s; mínimos, 4 s y 29 s. La comparación
la hace `herramientas/verificar_incidencias.py comparar <registrado> <nuevo>`, que también
ejecuta la integración continua.

## Relación con el prototipo

La prueba usa el núcleo de referencia en Python, no el prototipo Dart. El prototipo
registra incidencias (CU-10), permite ajustar la programación con una alternativa
admisible y su motivo (CU-12) y deja como incidencia un servicio sin alternativas, pero
no tiene todavía una función de reasignación a mitad del turno; esta prueba muestra cómo
se comportaría el método si se incorpora.
