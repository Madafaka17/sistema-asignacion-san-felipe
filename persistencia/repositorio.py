"""Operaciones de datos sobre la base de pruebas: esquema, carga de la instancia del turno
en las estructuras del núcleo y registro de la programación devuelta por el núcleo.

En esta versión las alternativas admisibles A_s se cargan ya construidas (tabla
`alternativa`). Su construcción a partir de las reglas de la cola, del conductor
habitual y de los reemplazos autorizados corresponde a la lógica de negocio de la
Figura 4 y todavía no está implementada.
"""
from __future__ import annotations

from pathlib import Path

from core.domain import AdmissibleTriple, Instance, Service

from .config import ConfigBD, nombre_bd_valido

TABLAS_ESPERADAS = ("alternativa", "autorizacion", "conductor", "corrida", "programacion", "ruta",
                    "servicio", "turno", "unidad")


def dividir_sql(texto: str) -> list[str]:
    """Separa un script SQL en sentencias. Admite comentarios de línea con -- y
    sentencias terminadas en ';' al final de la línea (formato de bd/*.sql)."""
    sentencias, actual = [], []
    for linea in texto.splitlines():
        limpia = linea.strip()
        if not limpia or limpia.startswith("--"):
            continue
        actual.append(linea)
        if limpia.endswith(";"):
            sentencias.append("\n".join(actual).rstrip().rstrip(";"))
            actual = []
    if actual:
        raise ValueError("el script SQL termina sin ';'")
    return sentencias


def crear_bd(con, nombre: str, cfg: ConfigBD) -> None:
    nombre_bd_valido(nombre, cfg)
    with con.cursor() as cur:
        cur.execute(f"CREATE DATABASE `{nombre}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin")
    con.select_db(nombre)


def eliminar_bd(con, nombre: str, cfg: ConfigBD) -> None:
    nombre_bd_valido(nombre, cfg)
    with con.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS `{nombre}`")


def existe_bd(con, nombre: str) -> bool:
    with con.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = %s", (nombre,))
        return cur.fetchone()[0] == 1


def aplicar_sql(con, ruta: Path) -> int:
    sentencias = dividir_sql(ruta.read_text(encoding="utf8"))
    with con.cursor() as cur:
        for s in sentencias:
            cur.execute(s)
    con.commit()
    return len(sentencias)


def tablas(con) -> tuple[str, ...]:
    with con.cursor() as cur:
        cur.execute("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() "
                    "ORDER BY TABLE_NAME")
        return tuple(r[0] for r in cur.fetchall())


def conteos(con) -> dict[str, int]:
    out = {}
    with con.cursor() as cur:
        for t in TABLAS_ESPERADAS:
            cur.execute(f"SELECT COUNT(*) FROM `{t}`")
            out[t] = int(cur.fetchone()[0])
    return out


def cargar_instancia(con, id_turno: int, pesos: dict[str, float]) -> tuple[Instance, float]:
    """Construye core.domain.Instance a partir de las tablas del turno. Devuelve también
    t_min (holgura mínima entre servicios del mismo recurso)."""
    with con.cursor() as cur:
        cur.execute("SELECT t_min, b_retraso, b_reprogramacion, b_tiempo_muerto, b_desequilibrio, "
                    "origen_datos FROM turno WHERE id_turno = %s", (id_turno,))
        fila = cur.fetchone()
        if fila is None:
            raise LookupError(f"no existe el turno {id_turno}")
        t_min, b_ret, b_rep, b_tm, b_d, origen = fila
        if origen != "sintetico":
            raise ValueError("la base de pruebas solo admite datos sintéticos")

        cur.execute("SELECT id_conductor, conduccion_previa_min, limite_conduccion_min FROM conductor "
                    "WHERE id_turno = %s ORDER BY id_conductor", (id_turno,))
        conductores = cur.fetchall()

        cur.execute("SELECT id_servicio, prioridad, alternativa_comprometida FROM servicio "
                    "WHERE id_turno = %s ORDER BY orden", (id_turno,))
        servicios_bd = cur.fetchall()

        cur.execute("SELECT a.id_servicio, a.indice, a.id_unidad, a.id_conductor, a.codigo_salida, "
                    "a.inicio_min, a.duracion_min FROM alternativa a JOIN servicio s "
                    "ON s.id_servicio = a.id_servicio WHERE s.id_turno = %s "
                    "ORDER BY s.orden, a.indice", (id_turno,))
        alternativas = cur.fetchall()

    por_servicio: dict[str, list[AdmissibleTriple]] = {sid: [] for sid, _, _ in servicios_bd}
    for sid, indice, unidad, conductor, codigo, inicio, duracion in alternativas:
        lista = por_servicio[sid]
        if indice != len(lista):
            raise ValueError(f"índices de alternativas no consecutivos en {sid}")
        lista.append(AdmissibleTriple(sid, unidad, conductor, codigo, float(inicio), float(duracion)))

    servicios = []
    for sid, prioridad, comprometida in servicios_bd:
        alts = tuple(por_servicio[sid])
        if comprometida is not None and not 0 <= comprometida < len(alts):
            raise ValueError(f"alternativa comprometida fuera de rango en {sid}")
        servicios.append(Service(sid, priority=int(prioridad), admissible=alts,
                                 baseline_alt=None if comprometida is None else int(comprometida)))

    instancia = Instance(
        services=tuple(servicios),
        driving_time_prior={c: float(p) for c, p, _ in conductores},
        driving_time_limit={c: float(l) for c, _, l in conductores},
        weights=dict(pesos),
        norm_refs={"delay": float(b_ret), "reschedule": float(b_rep), "idle": float(b_tm),
                   "workload": float(b_d)},
    )
    return instancia, float(t_min)


def guardar_programacion(con, id_turno: int, semilla: int, resultado, validador: int, huella: str) -> int:
    """Registra la corrida y la programación (servicio -> alternativa elegida)."""
    b = resultado.breakdown
    with con.cursor() as cur:
        cur.execute("INSERT INTO corrida (id_turno, tipo, semilla_ag, aptitud, phi, validador, huella_salida) "
                    "VALUES (%s, 'humo', %s, %s, %s, %s, %s)",
                    (id_turno, semilla, float(b.fitness), int(b.feasibility_violations), int(validador), huella))
        id_corrida = cur.lastrowid
        cur.executemany("INSERT INTO programacion (id_corrida, id_servicio, indice_alternativa) "
                        "VALUES (%s, %s, %s)",
                        [(id_corrida, s.service_id, int(g)) for s, g in zip(resultado.services, resultado.chromosome)])
    con.commit()
    return int(id_corrida)


def leer_programacion(con, id_corrida: int) -> list[dict]:
    with con.cursor() as cur:
        cur.execute("SELECT p.id_servicio, p.indice_alternativa, a.id_unidad, a.id_conductor, a.codigo_salida, "
                    "a.inicio_min, a.duracion_min FROM programacion p "
                    "JOIN alternativa a ON a.id_servicio = p.id_servicio AND a.indice = p.indice_alternativa "
                    "JOIN servicio s ON s.id_servicio = p.id_servicio "
                    "WHERE p.id_corrida = %s ORDER BY s.orden", (id_corrida,))
        return [{"servicio": r[0], "alternativa": int(r[1]), "unidad": r[2], "conductor": r[3], "salida": r[4],
                 "inicio_min": float(r[5]), "duracion_min": float(r[6])} for r in cur.fetchall()]
