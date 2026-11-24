"""Diagrama entidad-relación del esquema del núcleo. Uso: python3 er.py bd/esquema.sql"""
import re
import sys
sql = open(sys.argv[1] if len(sys.argv) > 1 else 'bd/esquema.sql', encoding='utf8').read()
sql = re.sub(r'\n\s+REFERENCES', ' REFERENCES', sql)
tablas = {}
for m in re.finditer(r'CREATE TABLE (\w+) \((.*?)\) ENGINE', sql, re.S):
    nombre, cuerpo = m.group(1), m.group(2)
    cols, pk, fks = [], set(), {}
    for linea in cuerpo.split('\n'):
        l = linea.strip().rstrip(',')
        if l.startswith('PRIMARY KEY'):
            pk = set(x.strip() for x in re.search(r'\((.*?)\)', l).group(1).split(','))
        elif l.startswith('CONSTRAINT') and 'FOREIGN KEY' in l:
            src = [x.strip() for x in re.search(r'FOREIGN KEY \((.*?)\)', l).group(1).split(',')]
            dst = re.search(r'REFERENCES (\w+)', l).group(1)
            for x in src: fks[x] = dst
        else:
            mm = re.match(r'(\w+)\s+([A-Z]+(?:\([^)]*\))?(?:\s+UNSIGNED)?)', l)
            if mm and mm.group(1) not in ('UNIQUE', 'CONSTRAINT', 'PRIMARY'):
                cols.append((mm.group(1), mm.group(2).replace(' UNSIGNED', ' UNSIGNED')))
    tablas[nombre] = (cols, pk, fks)
lin = ['digraph ER {', ' graph [rankdir=TB, fontname="DejaVu Sans", nodesep=0.2, ranksep=0.35, pad=0.1, dpi=220];',
       ' node [shape=plaintext, fontname="DejaVu Sans", fontsize=12];',
       ' edge [fontname="DejaVu Sans", fontsize=11, arrowhead=crow, arrowtail=tee, dir=both];']
for t, (cols, pk, fks) in tablas.items():
    clave = [(c, ty) for c, ty in cols if c in pk or c in fks]
    resto = len(cols) - len(clave)
    filas = ''.join(f'<TR><TD ALIGN="LEFT">{"PK " if c in pk else ""}{"FK " if c in fks else ""}{c}</TD></TR>'
                    for c, ty in clave)
    if resto:
        filas += f'<TR><TD ALIGN="LEFT"><I>+ {resto} {"atributo" if resto == 1 else "atributos"}</I></TD></TR>'
    lin.append(f' {t} [label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3"><TR><TD '
               f'BGCOLOR="gray85"><B>{t}</B></TD></TR>{filas}</TABLE>>];')
rel = [('turno','conductor','1 : N'),('turno','unidad','1 : N'),('conductor','unidad','0..1 : N (habitual)'),
       ('unidad','autorizacion','1 : N'),('conductor','autorizacion','1 : N'),('turno','servicio','1 : N'),
       ('ruta','servicio','1 : N'),('unidad','servicio','1 : N (en cola)'),('servicio','alternativa','1 : N'),
       ('autorizacion','alternativa','1 : N'),('turno','corrida','1 : N'),('corrida','programacion','1 : N'),
       ('alternativa','programacion','1 : N')]
for a, b, l in rel:
    lin.append(f' {a} -> {b} [label="{l}"];')
lin += [' {rank=same; turno; ruta}', ' {rank=same; conductor; corrida}', ' {rank=same; unidad; servicio}',
        ' {rank=same; autorizacion; alternativa; programacion}', '}']
open('er_nucleo.dot', 'w').write('\n'.join(lin))
import subprocess
subprocess.run(['dot', '-Tpng', 'er_nucleo.dot', '-o', 'er_nucleo.png'], check=True)
print({t: len(v[0]) for t, v in tablas.items()})
