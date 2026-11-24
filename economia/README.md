# Modelo económico (tesis, capítulos VI y VII)

Archivos del paquete EP3 del autor (4 de noviembre de 2026), incorporados sin
cambios.

| Archivo | Contenido |
|---|---|
| `modelo_economico.py` | Modelo de la versión 6: beneficios monetarios B3 y B4 (el tiempo liberado B1 y B2 no se monetiza), CAPEX con las pruebas previas (sprint S7) y licencias abiertas a costo cero, OPEX O1 a O6 y COK en soles por paridad de Fisher (BCRP PD12912AM y FRED T10YIEM, septiembre de 2026); escenarios, sensibilidad, horizonte de 3 años y despliegue en la nube |
| `modelo_economico.json` | Resultados usados en la tesis: VAN de S/ 65.87, TIR de 11.16 % y COK de 10.99 %, con los precios y sueldos de las capturas del 3/11/2026 (evidencias EV-01 a EV-23 del EP3) |
| `flujo_caja.py`, `flujo_caja.png` | Figura 67: flujo neto y saldo acumulado del caso base |

## Reproducción

```bash
python3 modelo_economico.py modelo_economico.json
python3 flujo_caja.py modelo_economico.json flujo_caja.png   # requiere matplotlib
```

Con **Python 3.12 o posterior** el JSON se regenera idéntico byte a byte
(verificado con CPython 3.13.18). Con Python 3.11 los valores cambian en los
últimos dígitos (del orden de 10⁻¹³ relativo; por ejemplo, VAN 65.8695193345552
frente a 65.8695193345551), porque desde Python 3.12 `sum()` de números reales
usa suma compensada; los valores que informa la tesis no cambian.
