import subprocess
from PIL import Image, ImageDraw, ImageFont
PANELES = {
 "a. CUN-01 Organizar y prestar viaje": {
   "act": ["Pasajero / cliente"], "trab": ["PersonalDespacho", "EncargadoOperaciones", "Conductor"],
   "ent": ["ColaDestino", "ProgramacionTurno", "Servicio", "Vehiculo (unidad)", "Manifiesto"],
   "rel": [("Pasajero / cliente", "Servicio", "solicita"), ("PersonalDespacho", "ColaDestino", "registra"),
           ("PersonalDespacho", "Servicio", "asigna y despacha"), ("EncargadoOperaciones", "ProgramacionTurno", "verifica"),
           ("Conductor", "Servicio", "conduce"), ("Conductor", "Manifiesto", "porta"),
           ("ColaDestino", "Vehiculo (unidad)", "ordena 1..*"), ("ProgramacionTurno", "Servicio", "contiene 1..*"),
           ("Servicio", "Vehiculo (unidad)", "usa 1"), ("Servicio", "Manifiesto", "se documenta en 1")]},
 "b. CUN-02 Restituir disponibilidad": {
   "act": ["Taller externo"], "trab": ["ResponsableMantenimiento", "PersonalDespacho"],
   "ent": ["OrdenMantenimiento", "Vehiculo (unidad)"],
   "rel": [("ResponsableMantenimiento", "OrdenMantenimiento", "registra y cierra"),
           ("OrdenMantenimiento", "Vehiculo (unidad)", "retira o restituye"),
           ("PersonalDespacho", "Vehiculo (unidad)", "consulta cobertura"), ("Taller externo", "OrdenMantenimiento", "repara")]},
 "c. CUN-03 Atender solicitud o reclamo": {
   "act": ["Pasajero / cliente"], "trab": ["PersonalAtencion", "PersonalDespacho", "EncargadoOperaciones"],
   "ent": ["SolicitudReclamo", "Servicio"],
   "rel": [("Pasajero / cliente", "SolicitudReclamo", "presenta"), ("PersonalAtencion", "SolicitudReclamo", "clasifica y responde"),
           ("SolicitudReclamo", "Servicio", "se refiere a"), ("PersonalDespacho", "Servicio", "verifica documentos"),
           ("EncargadoOperaciones", "Servicio", "revisa condición")]},
 "d. CUN-04 Liquidar vuelta": {
   "act": ["Entidad financiera"], "trab": ["PersonalAdministracion", "Conductor"],
   "ent": ["LiquidacionVuelta", "Manifiesto", "Servicio"],
   "rel": [("PersonalAdministracion", "LiquidacionVuelta", "elabora"), ("LiquidacionVuelta", "Manifiesto", "se sustenta en"),
           ("LiquidacionVuelta", "Servicio", "corresponde a"), ("Conductor", "Manifiesto", "entrega"),
           ("Entidad financiera", "LiquidacionVuelta", "emite constancia")]},
}
def nid(x):
    return "n" + "".join(c for c in x if c.isalnum())


def dot_panel(i, p):
    """Panel de un CUN: actor del negocio fuera de la frontera; trabajadores y entidades dentro."""
    tb = i == 0   # CUN-01 tiene más entidades: se dibuja de arriba hacia abajo para que sea legible
    L = ['digraph G {',
         f' graph [rankdir={"TB" if tb else "LR"}, fontname="DejaVu Sans", nodesep={0.3 if tb else 0.25}, '
         f'ranksep={0.55 if tb else 0.9}, pad=0.1, dpi=220];',
         ' node [fontname="DejaVu Sans", fontsize=14, margin="0.1,0.05"];',
         ' edge [fontname="DejaVu Sans", fontsize=13, arrowhead=none];']
    for a in p["act"]:
        L.append(f' {nid(a)} [shape=box, style=bold, label="«actor del negocio»\\n{a}"];')
    L.append(' subgraph cluster_f { label="Frontera del negocio"; labeljust="l"; style=dashed; '
             'fontname="DejaVu Sans"; fontsize=11;')
    L.append('  subgraph cluster_t { label=""; style=invis;')
    for t in p["trab"]:
        L.append(f'   {nid(t)} [shape=box, style=rounded, label="«trabajador»\\n{t}"];')
    L.append('  }')
    L.append('  subgraph cluster_e { label=""; style=invis;')
    for e in p["ent"]:
        L.append(f'   {nid(e)} [shape=box, label="«entidad de negocio»\\n{e}"];')
    L.append('  }')
    L.append(' }')
    ent = set(p["ent"])
    for a, b, l in p["rel"]:
        extra = ", constraint=false" if (a in ent and b in ent and not tb) else ""
        L.append(f' {nid(a)} -> {nid(b)} [label="{l}"{extra}];')
    if tb:
        L.append(' {rank=min; ' + "; ".join(nid(a) for a in p["act"]) + '}')
    L.append('}')
    return "\n".join(L)


archivos = []
for i, (titulo, p) in enumerate(PANELES.items()):
    f = f"obj_{i}.dot"
    open(f, "w", encoding="utf8").write(dot_panel(i, p))
    subprocess.run(["dot", "-Tpng", f, "-o", f"obj_{i}.png"], check=True)
    archivos.append((titulo, f"obj_{i}.png"))
fuente = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 46)


def componer(idx, salida):
    ims = [(archivos[k][0], Image.open(archivos[k][1])) for k in idx]
    W = max(im.size[0] for _, im in ims)
    pan = []
    for t, im in ims:
        c = Image.new("RGB", (W, im.size[1] + 85), "white")
        ImageDraw.Draw(c).text((10, 12), t, fill="black", font=fuente)
        c.paste(im, (0, 85))
        pan.append(c)
    H = sum(q.size[1] for q in pan) + 50 * (len(pan) - 1)
    lz = Image.new("RGB", (W, H), "white")
    y = 0
    for q in pan:
        lz.paste(q, (0, y))
        y += q.size[1] + 50
    lz.save(salida)
    print(salida, lz.size)


componer([0, 1], "objetos_a.png")
componer([2, 3], "objetos_b.png")
