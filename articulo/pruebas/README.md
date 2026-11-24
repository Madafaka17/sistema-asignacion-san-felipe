# Pruebas del código del artículo (`02_codigo/pruebas`)

Suite de pruebas unitarias, de propiedades, de datos y de reproducción para el código del artículo
*Asignación de vehículo, conductor y salida en operadores interprovinciales pequeños*: modelo y función objetivo,
reparación, algoritmo genético, regla voraz, PLE con objetivo sustituto, método exacto con cortes tangentes,
búsqueda local, búsqueda tabú, validador, generadores sintético y GTFS, análisis estadístico y datos publicables.
Los oráculos de `utilidades.py` se escribieron de nuevo, por fuerza bruta, y solo importan las clases de datos de
`modelo.py`. El libro de datos no publicables no se usa.

## Qué cubre

| Módulo | Archivo | Componente | Técnicas |
|---|---|---|---|
| A01 | `test_a01_modelo.py` | Alternativas, pares en conflicto e índice (`modelo.py`) | Partición; valor límite; oráculo; propiedad |
| A02 | `test_a02_evaluacion.py` | J y aptitud F = −(M·Φ + E + J) | Precalculado a mano; oráculo; propiedad |
| A03 | `test_a03_reparacion.py` | Reglas de la reparación (`reparacion.py`) | Regla de negocio; valor límite; propiedad; procesos |
| A04 | `test_a04_genetico.py` | AG sobre PyGAD (`genetico.py`) | Doble de prueba; estadística (3σ); valor límite; reproducibilidad |
| A05 | `test_a05_voraz.py` | Regla voraz de primer ajuste | Regla de negocio; valor límite; propiedad |
| A06 | `test_a06_ple_exacto.py` | PLE sustituto y método exacto | Enumeración completa; valor límite; partición |
| A07 | `test_a07_busqueda.py` | Búsqueda local, búsqueda tabú y envoltorio del AG | Propiedad; vecindario completo; valor límite |
| A08 | `test_a08_validador.py` | Validador independiente | Revisión estática; oráculo cruzado |
| A09 | `test_a09_generador_sintetico.py` | Generador del caso de Soritor | Regla de negocio; estadística; reproducibilidad |
| A10 | `test_a10_generador_gtfs.py` | Generador con horarios GTFS | GTFS mínimo construido; emparejamiento exhaustivo; datos reales |
| A11 | `test_a11_analisis.py` | A12, Holm, percentil 95, brecha y protocolo | Valores a mano; valores límite; reproducción de resúmenes |
| A12 | `test_a12_datos.py` | `datos/manifiestos_publicables.csv` | Estructura; consistencia; faltantes; privacidad |
| A13 | `test_a13_reproduccion.py` | Corridas publicadas (`experimento.py`) | Reproducción con las mismas semillas |

`reproduccion.py` repite además 684 corridas publicadas (sintético n = 7 a 112, variante con la plantilla de la
empresa y tres agencias de Łódź) y calcula la media y la desviación estándar de AG_v1, AG_v2 y Tabu_v1 entre semillas.

## Ejecución (desde la carpeta 02_codigo)

Use Python 3.12 o posterior: las corridas publicadas se reproducen bit a bit con Python 3.13.16, la versión de la
ejecución registrada; con Python 3.11 cambian en el último bit (anomalía B-07).

```bash
pip install -r requirements.txt pytest==9.1.1
bash pruebas/ejecutar_pruebas.sh                    # entorno, pruebas y reproducción (unos 10 min)
SIN_REPRODUCCION=1 bash pruebas/ejecutar_pruebas.sh # solo entorno y pruebas (unos 90 s)
COBERTURA_LIB=/ruta/a/coverage bash pruebas/medir_cobertura.sh
```

Las evidencias quedan en `pruebas/salidas/`: `entorno.json` (con la comparación de huellas contra `SHA256SUMS`),
`pytest.log`, `junit.xml`, `casos.jsonl`, `reproduccion.csv`, `resumen_reproduccion.json`, `cobertura.txt` y
`cobertura.json`.

## Anomalías

| Id. | Resumen | Estado |
|---|---|---|
| B-01 | `metodos.exacto()` lanza `TypeError` si no obtiene ninguna solución entera (instancia infactible o límite de tiempo agotado antes de la primera solución), porque devuelve `mejor[0]` con `mejor = None` | Abierta en el código del artículo; documentada con la prueba A06-06 (`xfail` estricto). No afectó a las corridas publicadas: todas las instancias son factibles por construcción y el exacto encontró solución en todas |
| B-02 | La primera versión de A06-04 exigía cota ≤ J + 10⁻⁹; la cota de CBC superó a J en 1.8 × 10⁻⁹ | Resuelta en la prueba: se usa la tolerancia del método (10⁻⁷ relativa) |
| B-03 | La primera versión de A06-05 esperaba un modelo infactible con horizonte menor que el último fin; el modelo excluye en silencio las alternativas que terminan después del horizonte | Resuelta en la prueba; precondición documentada (horizonte ≥ fin de toda alternativa), que el experimento cumple |
| B-04 | La primera versión de A06-03 esperaba `None` con un modelo infactible; con CBC, `ple_sustituto` devuelve los valores del solucionador y el estado `Infeasible` | Resuelta en la prueba: el contrato verificado es estado `Infeasible` y ninguna programación válida. `experimento.correr` ignora el estado; el validador registra la infactibilidad |
| B-05 | Siete casos de A09 no registraban latencia | Resuelta: el generador se mide con `caso.cronometrar` |
| B-06 | Aviso de SciPy (división inválida) con diferencias empatadas en los datos construidos de A11-04 | Resuelta: el aviso se filtra solo en esa prueba; no aparece con los resultados publicados |
| B-07 | Con Python 3.11.17 (el README del código admite «3.11 o superior»), 87 de las 684 corridas repetidas difieren en el último bit de J y una (Tabu_v1, Łódź PHUOLA, instancia 102, semilla 4) sigue otra trayectoria: J = 1.7300 frente a 1.7498 publicado. Con Python 3.13.16 las 684 coinciden bit a bit | Resuelta en la ejecución registrada (Python 3.13.16). Causa: desde Python 3.12, `sum()` de números reales usa suma compensada. Se propone declarar en el README del código la versión de Python de las corridas publicadas o exigir 3.12 o posterior. Evidencia en `salidas/comparacion_python311/` |

Propuesta para B-01, en `metodos.exacto`, antes del `return` final:

```python
if mejor is None:
    return None, {"iteraciones": it, "cota": cota, "J": None, "certificado": False,
                  "tiempo_s": time.perf_counter() - t0}
```

y, en `experimento.correr`, registrar la corrida del exacto sin programación en lugar de evaluarla.
