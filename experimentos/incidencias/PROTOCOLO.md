# Protocolo de la prueba de reasignación ante incidencias de despacho

Fijado el 24/11/2026, **antes** de ejecutar la prueba. Su huella SHA-256 y la del
script quedan en `registro_protocolo.txt`. Ningún parámetro, tamaño, semilla, peso,
regla ni configuración se ajusta después de observar resultados; cualquier
desviación se informa como tal.

## 1. Propósito

Comprobar si el núcleo de optimización recomienda una reasignación válida de
unidades y conductores cuando ocurre una incidencia de despacho a mitad del turno,
y medir cuántos servicios cambia, cuánto retraso agrega y cuánto tarda.

La prueba usa sin cambios el generador del caso
(`experimentos/sanfelipe/generador_sanfelipe.py`), el algoritmo genético con la
configuración oficial v1 de la Tabla 18 y la regla voraz de referencia
(`experimentos/poc_cap3/metodos.py`), la función de evaluación (`core/fitness.py`)
y el validador independiente (`experimentos/poc_cap3/validador.py`).

Las instancias **no son datos de la empresa**: son turnos sintéticos con la
estructura declarada de la operación (PROTOCOLO.md de `experimentos/sanfelipe`).

## 2. Turnos y programación aprobada

- Tamaños: n = 28, 56 y 112 servicios por turno; semillas de instancia 101, 102 y
  103 (9 turnos).
- Programación aprobada: la programación oculta del generador, sin cruces ni
  exceso de conducción por construcción.
- Momento de la incidencia: minuto 300 del turno de 600 min (11:00 con inicio a
  las 06:00).
- Servicios iniciados: los de salida aprobada anterior al minuto 300. Se mantienen
  como se aprobaron, ocupan su unidad y su conductor hasta su fin (más t_mín = 10
  min) y su duración cuenta como conducción previa H_c0 de su conductor.
- Servicios pendientes S′: los de salida aprobada desde el minuto 300; son los
  únicos que pueden reasignarse.

## 3. Incidencias

Una incidencia por escenario; el recurso afectado se elige con una regla fija:

| Incidencia | Recurso afectado | Efecto |
|---|---|---|
| I1 Avería de unidad | La unidad con más servicios pendientes en la programación aprobada (empate: menor código) | Queda fuera de servicio para todos los servicios pendientes |
| I2 Ausencia de conductor | El conductor con más servicios pendientes (empate: menor código) | No puede conducir ningún servicio pendiente |
| I3 Demora en ruta | La unidad con más servicios pendientes entre las que tienen un viaje en curso en el minuto 300 (empate: menor código) | Su viaje en curso termina 60 min más tarde: la unidad y su conductor quedan ocupados 60 min más y esos 60 min se suman a la conducción previa del conductor. Si ninguna unidad con viaje en curso tiene servicios pendientes, se toma la unidad de I1 y queda detenida 60 min desde el minuto 300, sin afectar a su conductor |

9 turnos × 3 incidencias = 27 escenarios.

## 4. Instancia de reasignación

Para cada servicio pendiente, las alternativas admisibles son las del turno
original que (a) no usan la unidad averiada ni el conductor ausente; (b) no
chocan, con t_mín, con los servicios iniciados ni con la demora, y (c) no usan a
un conductor cuya conducción previa ya alcanzó su límite, como hace el constructor
de instancias del prototipo. La alternativa
aprobada es la alternativa comprometida b(s) del servicio si sigue siendo
admisible; si no, el servicio está **afectado** y debe cambiar. Un servicio sin
alternativas admisibles queda **sin cobertura** (u_s = 1) y se informa aparte.

Función de evaluación F(X) con los pesos y referencias del experimento del
capítulo 3: w_j = 0.25; b_Ret = 60 min; b_R = número de servicios pendientes con
alternativa comprometida (mínimo 1); b_Tm = 60·|V| min; b_D = 60 min. Límite de
conducción de cada conductor: el del turno original.

## 5. Métodos

- **Sin reasignar:** se mantiene la programación aprobada; los servicios afectados
  no pueden salir como estaban.
- **Regla voraz de referencia** (determinista): reprograma todos los servicios
  pendientes por hora de salida, sin considerar la programación aprobada.
- **AG**, configuración oficial v1 (población 50, 100 generaciones, p_c = 0.80,
  p_m = 0.10, torneo de 3, elitismo de 10 %, mutación por cromosoma, reparación
  dirigida y población inicial reparada), semillas 1 a 10.

## 6. Medidas por ejecución

- **Válida:** Φ = 0 según F(X) y 0 incumplimientos según el validador
  independiente; todo servicio pendiente con alternativa queda cubierto.
- Servicios pendientes, afectados y sin alternativa.
- Servicios cambiados respecto de la programación aprobada (unidad, conductor u
  hora de salida), separados en afectados (cambio obligado) y no afectados
  (cambio adicional).
- Retraso total respecto de la salida aprobada, en minutos, de los servicios
  pendientes cubiertos.
- Tiempo de cómputo, en segundos (presupuesto de RNF-02: 300 s).

## 7. Informe

Por tamaño y por incidencia: porcentaje de ejecuciones válidas, media de
servicios afectados, de cambios adicionales y de retraso, y tiempo medio y máximo.
Total: 27 ejecuciones de la regla voraz y 270 del AG.

## 8. Análisis adicionales, definidos después de observar los resultados de v1

Se fijaron el 24/11/2026, después de ejecutar v1 (secciones 1 a 7) y antes de
ejecutar lo que describen. No cambian v1, que se informa tal como se definió.

**8.1 Mínimos exactos (`minimos.py`).** Para cada escenario, con programación
lineal entera (PuLP y CBC): (a) el menor Φ posible cuando se asigna una alternativa
a cada servicio pendiente que la tiene, como exige la ecuación 3; y (b) el menor
número de servicios pendientes que hay que dejar sin asignar para que el resto
quede sin cruces ni excesos. Sirve para saber si existe una reasignación válida de
todos los servicios con las alternativas admisibles y si el AG alcanzó el mínimo.

**8.2 Variante v2: regla de contingencia.** Supuesto declarado, por validar con la
empresa: ante una incidencia, el encargado puede autorizar para cada servicio
afectado cualquier unidad activa que no esté averiada, con uno de sus conductores
autorizados (habitual o reemplazo) que no esté ausente ni en su límite, y con salida
a la hora aprobada o con 10, 20 o 30 min de demora, siempre que el viaje termine
dentro del turno y no choque, con t_mín, con los servicios iniciados ni con la
demora. Solo se amplían las alternativas de los servicios afectados; las de los
demás servicios, los métodos, las semillas y las medidas son los de v1. Se calculan
también los mínimos exactos de 8.1 para v2.

**8.3 Análisis exploratorio del límite de conducción.** Definido después de un
diagnóstico de v1 y v2. Repite el cálculo de phi_min de 8.1 sin el límite de
conducción (límite de 10^6 min para todos los conductores), para medir cuánto de
la imposibilidad de reasignar se debe a los límites ajustados del generador
(carga de la programación oculta + 20 a 120 min). Es exploratorio y no cambia v1 ni v2.
