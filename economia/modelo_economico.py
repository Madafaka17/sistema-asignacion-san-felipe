"""Modelo económico del capítulo VI (flujo de caja, VAN, TIR, periodo de recuperación, ROI, B/C).

Todos los insumos están declarados en FUENTES y SUPUESTOS con su origen. Los montos están en soles
(S/) corrientes; los precios en dólares se convierten con el tipo de cambio SBS de venta.
Uso:  python modelo_economico.py salida.json
"""
from __future__ import annotations

import json
import sys
from copy import deepcopy

# ---------------------------------------------------------------------------
# Precios comerciales verificados el 03/11/2026; parámetros financieros con la fecha de cada dato
# (URL y evidencias E-xx en el informe técnico-económico y en el Anexo J de la tesis)
# ---------------------------------------------------------------------------
FUENTES = {
    "sueldo_desarrollador": 2511.00,     # Indeed Perú, desarrollador/a de software, 574 sueldos, act. 28/10/2026 (EV-08)
    "sueldo_data_scientist": 3490.00,    # Indeed Perú, data scientist, 11 sueldos, act. 27/10/2026 (EV-09)
    "sueldo_glassdoor": 4000.00,         # Glassdoor, Software Developer Perú, mediana de pago total (PEN 4K/mes)
    "sueldo_mtpe": 4710.00,              # MTPE vía La República (08/03/2026), Ing. de Sistemas y Cómputo
    "rmv": 1230.00,                      # D. S. 015-2026-TR, vigente desde 01/10/2026
    "tc_venta": 3.431,                   # BCRP, TC sistema bancario SBS venta, 16/10/2026
    "rf": 0.0509,                        # FRED DGS10, 16/10/2026
    "erp": 0.0420,                       # Damodaran, ERP implícita EE. UU., 01/10/2026
    "beta_transporte": 0.96,             # Damodaran, Transportation (Global), enero 2026, beta apalancada
    "beta_software": 1.35,               # Damodaran, Software (System & Application) (Global), enero 2026
    "riesgo_pais": 0.0107,               # BCRP, EMBIG Perú, setiembre 2026 (107 pb)
    "inflacion_12m": 0.0455,             # INEI/BCRP, Lima Metropolitana, set. 2026
    "inflacion_esperada_pe": 0.0309,     # BCRP, serie PD12912AM, expectativa de inflación a 12 meses, set. 2026
    "inflacion_esperada_us": 0.0235,     # FRED, T10YIEM, inflación implícita a 10 años de EE. UU., set. 2026
    "tsd": 0.08,                         # MEF, Anexo 11 de la Directiva N.° 001-2019-EF/63.01
    "igv": 0.18,                         # SUNAT
    "lightsail_2gb_usd_mes": 12.0,       # AWS Lightsail, 2 GB/2 vCPU/60 GB, IPv4
    "lightsail_4gb_usd_mes": 24.0,       # AWS Lightsail, 4 GB/2 vCPU/80 GB, IPv4
    "lightsail_snapshot_usd_gb_mes": 0.05,
    "b2_usd_tb_mes": 6.95,               # Backblaze B2
    "dominio_pe_anual": 110.00,          # PUNTO.pe, .pe o .com.pe, 1 año, incluye impuestos
    "mini_pc": 2781.50,                  # Memory Kings, GIGABYTE BRIX GB-BXIP-N250-512-16 (16 GB/500 GB), incluye IGV
    "ups": 471.00,                       # Memory Kings, APC BX1200MI-MS 1200 VA, precio único (sin oferta), incluye IGV
    "disco_respaldo": 359.00,            # Coolbox, Toshiba Canvio Basics 1 TB
}

# Costos de la empresa tomados de las Tablas 4 y 5 del capítulo I (pendientes de validación con RD-01)
COSTOS_ACTUALES_MES = {
    "B1": ("Horas administrativas por programación manual", 104 * 12.00),
    "B2": ("Verificación y ajuste manual de la programación", 20 * 25.00),
    "B3": ("Servicios reprogramados", 21 * 80.00),
    "B4": ("Servicios con retraso", 16 * 70.00),
    "B5": ("Uso ineficiente de vehículos, rutas y conductores", 1900.00),
}
HORA_ADMINISTRATIVA = 12.00                # Tabla 5 (costo unitario de la hora administrativa de la empresa)
# B3 y B4 son gastos (pagos) por servicio reprogramado o con retraso: su reducción es un ahorro de dinero.
# B1 y B2 son horas del personal: liberarlas no reduce pagos mientras la empresa no reduzca horas pagadas, por lo que
# se valoran como beneficio no financiero (tiempo liberado) y solo entran al flujo en un escenario de sensibilidad.
MONETARIOS = ("B3", "B4")
TIEMPO = ("B1", "B2")

# ---------------------------------------------------------------------------
# Supuestos declarados (se someten a sensibilidad)
# ---------------------------------------------------------------------------
SUPUESTOS = {
    "horas_mes_jornada": 160,
    "semanas_cronograma": 16, "horas_semana": 40,          # Tabla 27: 8 sprints de 2 semanas, dedicación completa
    "horas_datos": 120,                                     # S1 completo (80 h) + mitad de S2 (40 h)
    "horas_po": 8 * (1.0 + 0.75),                           # planificación (1 h) y revisión (45 min) por sprint, 3.7.2
    "horas_datos_rd01": 8,                                  # apoyo del personal para extraer registros (RD-01)
    "horas_capacitacion_personal": 3 * 4,                   # 3 roles (administrador, despacho, operaciones) × 4 h
    "horas_capacitacion_instructor": 4,
    "meses_entorno_pruebas": 2,                             # S4 a S7 en la nube (Lightsail 2 GB)
    "contingencia_capex": 0.10,
    "mantenimiento_pct": 0.20,                              # 15 %–30 % del costo de desarrollo (Boehm; Sommerville)
    "horas_soporte_mes": 2,                                 # revisión de respaldos, usuarios y bitácora
    "respaldo_gb": 10,
    "potencia_w": 20, "tarifa_kwh": 1.00,                   # energía: valor conservador, confirmar con recibo
    "escalamiento_opex": 0.05,                              # inflación 12 m 4.55 % redondeada; rango 3 %–10 %
    "contingencia_opex": 0.10,                              # imprevistos 10 %–20 %: tarifa eléctrica, soporte, tipo de cambio
    "realizacion": {"B1": 0.50, "B2": 0.50, "B3": 0.25, "B4": 0.25, "B5": 0.0},
    "horizonte": 5,
    "vida_util_equipos": 4,                                 # 25 % anual: equipos de procesamiento de datos
    "beta": "transporte",
    "tarifa_soft": None,                                    # None = sueldo_desarrollador / 160
    "tarifa_datos": None,
    "despliegue": "local",                                  # local (Figura 38 de la tesis) | nube
    "monetizar_tiempo": False,                              # True: B1 y B2 reducen pagos (solo sensibilidad)
    "valor_residual": False,                                # True: valor contable de los equipos renovados en el año 5
    "horas_pruebas_previas": 80,                            # sprint S7: aceptación, usabilidad y medición (Tabla 27)
}

ESCENARIOS = {
    "pesimista": {"B1": 0.25, "B2": 0.25, "B3": 0.10, "B4": 0.10, "B5": 0.0},
    "base": {"B1": 0.50, "B2": 0.50, "B3": 0.25, "B4": 0.25, "B5": 0.0},
    "optimista": {"B1": 0.75, "B2": 0.75, "B3": 0.50, "B4": 0.50, "B5": 0.0},
}


def cok_usd(beta_nombre="transporte"):
    beta = FUENTES["beta_transporte"] if beta_nombre == "transporte" else FUENTES["beta_software"]
    return FUENTES["rf"] + beta * FUENTES["erp"] + FUENTES["riesgo_pais"]


def cok(beta_nombre="transporte"):
    """COK nominal en soles: CAPM con riesgo país en dólares convertido con el diferencial de inflación esperada
    (paridad de Fisher), porque el flujo está en soles corrientes."""
    return (1 + cok_usd(beta_nombre)) * (1 + FUENTES["inflacion_esperada_pe"]) / \
        (1 + FUENTES["inflacion_esperada_us"]) - 1


def tarifas(s):
    soft = s["tarifa_soft"] or FUENTES["sueldo_desarrollador"] / s["horas_mes_jornada"]
    datos = s["tarifa_datos"] or FUENTES["sueldo_data_scientist"] / s["horas_mes_jornada"]
    return soft, datos


def capex(s):
    soft, datos = tarifas(s)
    horas_total = s["semanas_cronograma"] * s["horas_semana"]
    h_soft = horas_total - s["horas_datos"]
    usd_pruebas = FUENTES["lightsail_2gb_usd_mes"] * s["meses_entorno_pruebas"]
    h_pruebas = s["horas_pruebas_previas"]
    items = [
        ("Ingeniería y desarrollo de software (H_soft)", f"{h_soft - h_pruebas:g} h × S/ {soft:.2f}",
         (h_soft - h_pruebas) * soft, "humano"),
        ("Ciencia de datos y calibración (H_datos)", f"{s['horas_datos']:g} h × S/ {datos:.2f}", s["horas_datos"] * datos,
         "humano"),
        ("Participación del Product Owner", f"{s['horas_po']:g} h × S/ {HORA_ADMINISTRATIVA:.2f}",
         s["horas_po"] * HORA_ADMINISTRATIVA, "humano"),
        ("Preparación de datos históricos (RD-01)", f"{s['horas_datos_rd01']:g} h × S/ {HORA_ADMINISTRATIVA:.2f}",
         s["horas_datos_rd01"] * HORA_ADMINISTRATIVA, "datos"),
        ("Capacitación inicial", f"{s['horas_capacitacion_personal']:g} h personal × S/ {HORA_ADMINISTRATIVA:.2f} + "
         f"{s['horas_capacitacion_instructor']:g} h instructor × S/ {soft:.2f}",
         s["horas_capacitacion_personal"] * HORA_ADMINISTRATIVA + s["horas_capacitacion_instructor"] * soft, "humano"),
        ("Pruebas previas a la operación (sprint S7)", f"{h_pruebas:g} h × S/ {soft:.2f}", h_pruebas * soft,
         "pruebas"),
        ("Entorno de pruebas en la nube", f"Lightsail 2 GB × {s['meses_entorno_pruebas']} meses × US$ 12 × "
         f"{FUENTES['tc_venta']} × 1.18", usd_pruebas * FUENTES["tc_venta"] * (1 + FUENTES["igv"]), "pruebas"),
        ("Licencias del software base", "Licencias abiertas; instalación incluida en las horas de ingeniería", 0.0,
         "licencias"),
    ]
    if s["despliegue"] == "local":
        items += [
            ("Servidor local (mini PC)", "GIGABYTE BRIX GB-BXIP-N250-512-16; 16 GB; SSD 500 GB", FUENTES["mini_pc"], "infra"),
            ("Sistema de alimentación ininterrumpida", "APC BX1200MI-MS, 1200 VA", FUENTES["ups"], "infra"),
            ("Disco externo para respaldo local", "Toshiba Canvio Basics 1 TB", FUENTES["disco_respaldo"], "infra"),
        ]
    subtotal = sum(i[2] for i in items)
    items.append(("Contingencia", f"{s['contingencia_capex']:.0%} del subtotal", subtotal * s["contingencia_capex"],
                  "contingencia"))
    return items


def costo_desarrollo(s):
    """Costo de las horas de ingeniería de software (incluidas las pruebas previas) y de ciencia de datos."""
    return sum(v for n, _, v, _ in capex(s) if n.startswith(("Ingeniería", "Ciencia", "Pruebas previas")))


def opex_anual(s, t):
    """OPEX del año t (t ≥ 1) en soles corrientes."""
    soft, _ = tarifas(s)
    esc = (1 + s["escalamiento_opex"]) ** (t - 1)
    items = [
        ("Mantenimiento correctivo, adaptativo y evolutivo", s["mantenimiento_pct"] * costo_desarrollo(s)),
        ("Soporte y monitoreo interno", s["horas_soporte_mes"] * 12 * HORA_ADMINISTRATIVA),
        ("Respaldo externo cifrado (Backblaze B2)",
         s["respaldo_gb"] / 1000 * FUENTES["b2_usd_tb_mes"] * 12 * FUENTES["tc_venta"] * (1 + FUENTES["igv"])),
        ("Dominio .pe (PUNTO.pe)", FUENTES["dominio_pe_anual"]),
    ]
    if s["despliegue"] == "local":
        items.append(("Energía eléctrica del servidor y la UPS",
                      s["potencia_w"] * 8760 / 1000 * s["tarifa_kwh"]))
    else:
        nube = (FUENTES["lightsail_4gb_usd_mes"] + 80 * FUENTES["lightsail_snapshot_usd_gb_mes"]) * 12
        items.append(("Servidor en la nube (Lightsail 4 GB + instantáneas de 80 GB)",
                      nube * FUENTES["tc_venta"] * (1 + FUENTES["igv"])))
    items.append((f"Imprevistos ({s['contingencia_opex']:.0%} del OPEX)", s["contingencia_opex"] * sum(v for _, v in items)))
    return [(n, v * esc) for n, v in items]


def renovacion(s, t):
    if s["despliegue"] != "local":
        return 0.0
    vida = s["vida_util_equipos"]
    return (FUENTES["mini_pc"] + FUENTES["ups"] + FUENTES["disco_respaldo"]) if (t % vida == 0 and t < s["horizonte"] + 1) \
        else 0.0


def beneficio_mensual(realizacion, monetizar_tiempo=False):
    """Beneficio monetario mensual: solo los componentes que reducen pagos (B3 y B4), salvo en el escenario de
    sensibilidad en que la empresa reduce horas pagadas (monetizar_tiempo=True)."""
    claves = MONETARIOS + (TIEMPO if monetizar_tiempo else ())
    return sum(COSTOS_ACTUALES_MES[k][1] * realizacion[k] for k in claves)


def tiempo_liberado_mes(realizacion):
    """Horas administrativas y verificaciones liberadas por mes (beneficio no financiero)."""
    return {"horas": 104 * realizacion["B1"], "verificaciones": 20 * realizacion["B2"],
            "equivalente_soles": sum(COSTOS_ACTUALES_MES[k][1] * realizacion[k] for k in TIEMPO)}


def flujo(s):
    n = s["horizonte"]
    c0 = sum(i[2] for i in capex(s))
    b = 12 * beneficio_mensual(s["realizacion"], s.get("monetizar_tiempo", False))
    filas = []
    for t in range(n + 1):
        if t == 0:
            filas.append({"t": 0, "beneficios": 0.0, "capex": c0, "renovacion": 0.0, "opex": 0.0, "F": -c0})
        else:
            o = sum(v for _, v in opex_anual(s, t))
            r = renovacion(s, t)
            vr = 0.0
            if s.get("valor_residual") and s["despliegue"] == "local" and t == n:
                vr = (FUENTES["mini_pc"] + FUENTES["ups"] + FUENTES["disco_respaldo"]) * \
                    (1 - (n - s["vida_util_equipos"]) / s["vida_util_equipos"])
            filas.append({"t": t, "beneficios": b, "capex": 0.0, "renovacion": r, "opex": o, "F": b - o - r + vr,
                          "valor_residual": vr})
    return filas


def van(filas, r):
    return sum(f["F"] / (1 + r) ** f["t"] for f in filas)


def tir(filas, lo=-0.99, hi=10.0):
    f_lo, f_hi = van(filas, lo), van(filas, hi)
    if f_lo * f_hi > 0:
        return None
    for _ in range(200):
        mid = (lo + hi) / 2
        f_mid = van(filas, mid)
        if f_lo * f_mid <= 0:
            hi, f_hi = mid, f_mid
        else:
            lo, f_lo = mid, f_mid
    return (lo + hi) / 2


def payback(filas, r=None):
    acumulado = 0.0
    for f in filas:
        valor = f["F"] / (1 + r) ** f["t"] if r is not None else f["F"]
        anterior = acumulado
        acumulado += valor
        if f["t"] > 0 and acumulado >= 0 > anterior:
            return f["t"] - 1 + (-anterior) / valor
    return None


def indicadores(s):
    filas = flujo(s)
    r = cok(s["beta"])
    capex0 = filas[0]["capex"]
    suma_f = sum(f["F"] for f in filas[1:])
    vp_beneficios = sum(f["beneficios"] / (1 + r) ** f["t"] for f in filas)
    vp_costos = capex0 + sum((f["opex"] + f["renovacion"]) / (1 + r) ** f["t"] for f in filas[1:])
    factor_anualidad = sum(1 / (1 + r) ** t for t in range(1, s["horizonte"] + 1))
    equilibrio_mes = vp_costos / (12 * factor_anualidad)
    return {
        "cok": r, "flujo": filas, "VAN": van(filas, r), "TIR": tir(filas),
        "payback_simple": payback(filas), "payback_descontado": payback(filas, r),
        "ROI": (suma_f - capex0) / capex0, "BC": vp_beneficios / vp_costos,
        "vp_beneficios": vp_beneficios, "vp_costos": vp_costos,
        "beneficio_mensual": beneficio_mensual(s["realizacion"], s.get("monetizar_tiempo", False)),
        "beneficio_equilibrio_mes": equilibrio_mes,
        "equilibrio_pct_potencial": equilibrio_mes / sum(v for _, v in COSTOS_ACTUALES_MES.values()),
        "equilibrio_pct_monetario": equilibrio_mes / sum(COSTOS_ACTUALES_MES[k][1] for k in MONETARIOS),
        "factor_descuento": [1 / (1 + r) ** t for t in range(s["horizonte"] + 1)],
    }


def con(**cambios):
    s = deepcopy(SUPUESTOS)
    s.update(cambios)
    return s


def sensibilidad():
    base = indicadores(SUPUESTOS)["VAN"]
    soft_g = FUENTES["sueldo_glassdoor"] / 160
    soft_m = FUENTES["sueldo_mtpe"] / 160
    casos = [
        ("Tarifa de desarrollo (Glassdoor, S/ 25.00/h)", con(tarifa_soft=soft_g, tarifa_datos=soft_g)),
        ("Tarifa de desarrollo (MTPE, S/ 29.44/h)", con(tarifa_soft=soft_m, tarifa_datos=soft_m)),
        ("Horas de desarrollo +30 %", con(horas_semana=52, horas_datos=156)),
        ("Mantenimiento anual 30 %", con(mantenimiento_pct=0.30)),
        ("Escalamiento del OPEX 10 % anual", con(escalamiento_opex=0.10)),
        ("Imprevistos del OPEX 20 %", con(contingencia_opex=0.20)),
        ("Beta de software (COK con β = 1.35)", con(beta="software")),
        ("Escenario pesimista de beneficios", con(realizacion=ESCENARIOS["pesimista"])),
        ("Escenario optimista de beneficios", con(realizacion=ESCENARIOS["optimista"])),
        ("Reducción de horas pagadas (B1 y B2 como ahorro)", con(monetizar_tiempo=True)),
        ("Valor residual de los equipos renovados en el año 4", con(valor_residual=True)),
        ("Horizonte de 3 años", con(horizonte=3)),
        ("Despliegue en la nube (Lightsail 4 GB)", con(despliegue="nube")),
    ]
    salida = []
    for nombre, s in casos:
        ind = indicadores(s)
        salida.append({"caso": nombre, "VAN": ind["VAN"], "TIR": ind["TIR"], "payback": ind["payback_simple"],
                       "cok": ind["cok"], "delta_VAN": ind["VAN"] - base,
                       "capex": ind["flujo"][0]["capex"]})
    # Tasas de descuento de estrés sobre el caso base
    filas = flujo(SUPUESTOS)
    for r in (0.08, cok_usd(), 0.15, 0.20):
        nombre = (f"Tasa de descuento {100 * r:.3f} % (COK en dólares, sin convertir)" if abs(r - cok_usd()) < 1e-12
                  else f"Tasa de descuento {r:.0%}")
        salida.append({"caso": nombre, "VAN": van(filas, r), "TIR": tir(filas),
                       "payback": payback(filas), "cok": r, "delta_VAN": van(filas, r) - base,
                       "capex": filas[0]["capex"]})
    return salida


def tarifa_kwh_equilibrio():
    """Tarifa eléctrica (S/ por kWh) con la que el VAN del caso base es cero; el VAN es lineal en la tarifa."""
    v1 = indicadores(con(tarifa_kwh=1.0))["VAN"]
    v2 = indicadores(con(tarifa_kwh=2.0))["VAN"]
    return 1.0 + v1 / (v1 - v2)


def main(destino):
    base = indicadores(SUPUESTOS)
    datos = {
        "fuentes": FUENTES, "supuestos": SUPUESTOS, "costos_actuales_mes": COSTOS_ACTUALES_MES,
        "tarifas": dict(zip(("soft", "datos"), tarifas(SUPUESTOS))),
        "capex": capex(SUPUESTOS), "capex_total": sum(i[2] for i in capex(SUPUESTOS)),
        "opex": {t: opex_anual(SUPUESTOS, t) for t in range(1, SUPUESTOS["horizonte"] + 1)},
        "base": base,
        "cok_usd": cok_usd(), "cok_pen": cok(),
        "opex_mensual_1": [(n, v / 12) for n, v in opex_anual(SUPUESTOS, 1)],
        "tiempo_liberado": tiempo_liberado_mes(SUPUESTOS["realizacion"]),
        "monetizar_tiempo": indicadores(con(monetizar_tiempo=True)),
        "escenarios": {k: indicadores(con(realizacion=v)) for k, v in ESCENARIOS.items()},
        "sensibilidad": sensibilidad(),
        "nube": indicadores(con(despliegue="nube")),
        "horizonte_3": indicadores(con(horizonte=3)),
        "tarifa_kwh_equilibrio": tarifa_kwh_equilibrio(),
    }
    with open(destino, "w", encoding="utf8") as fh:
        json.dump(datos, fh, ensure_ascii=False, indent=2, default=str)
    b = base

    def fx(x, fmt):
        return "no existe" if x is None else format(x, fmt)

    print(f"COK = {b['cok']:.4%} (en dólares {cok_usd():.4%})  CAPEX = {datos['capex_total']:.2f}")
    for f in b["flujo"]:
        print(f)
    print(f"VAN = {b['VAN']:.2f}  TIR = {fx(b['TIR'], '.4%')}  PRI = {fx(b['payback_simple'], '.3f')}  "
          f"PRId = {fx(b['payback_descontado'], '.3f')}  ROI = {b['ROI']:.2%}  B/C = {b['BC']:.3f}  "
          f"equilibrio = {b['beneficio_equilibrio_mes']:.2f}/mes ({b['equilibrio_pct_monetario']:.2%} de B3+B4)")
    for k, v in datos["escenarios"].items():
        print(k, round(v["beneficio_mensual"], 2), round(v["VAN"], 2), v["TIR"], v["payback_simple"])
    for s_ in datos["sensibilidad"]:
        print(s_["caso"], round(s_["VAN"], 2), s_["TIR"], s_["payback"])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "modelo_economico.json")
