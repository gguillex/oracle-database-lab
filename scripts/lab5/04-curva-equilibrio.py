# scripts/lab5/04-curva-equilibrio.py — reto de la Parte E: dibuja la curva del punto de equilibrio (SVG, escala logarítmica)
# a partir de la sección 3 de la evidencia 04. Solo biblioteca estándar de Python.
# Uso: python3 scripts/lab5/04-curva-equilibrio.py <evidencia 04 .script.log> <salida.svg>
import math, re, sys

log_path, out_path = sys.argv[1], sys.argv[2]
rows = []
for line in open(log_path, encoding="utf-8", errors="replace"):
    m = re.match(r"^\s*([.\d]+) %\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S.*?)\s*(<-.*)?$", line)
    if m:
        k = float(m.group(1))
        rows.append((k, int(m.group(3)), int(m.group(4)), int(m.group(5)), "completo" in m.group(6)))

W, H = 900, 560
L, R, T, B = 90, 210, 70, 80
pw, ph = W - L - R, H - T - B
xmin, xmax = math.log10(0.01), math.log10(100)
ymin, ymax = 0, math.log10(2e6)
X = lambda k: L + (math.log10(k) - xmin) / (xmax - xmin) * pw
Y = lambda v: T + ph - (math.log10(max(v, 1)) - ymin) / (ymax - ymin) * ph

INK, MUTED, GRID = "#1f1f1e", "#6b6a63", "#e4e3dd"
series = [("Índice CF bueno (IX_PED_FECHA)", 1, "#2a78d6"),
          ("Índice CF malo (IX_PED_CLIENTE)", 2, "#eb6834"),
          ("Tabla entera (FULL)", 3, "#1baf7a")]

s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">',
     f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
     f'<text x="{L}" y="30" font-size="18" font-weight="bold" fill="{INK}">Punto de equilibrio en PEDIDO: lecturas lógicas para sumar el importe del k % de las filas</text>',
     f'<text x="{L}" y="52" font-size="13" fill="{MUTED}">Escalas logarítmicas · datos de la evidencia 04 (lab_tools, 2.ª ejecución en caliente)</text>']
for e in range(0, 7):
    y = Y(10 ** e)
    s.append(f'<line x1="{L}" x2="{L+pw}" y1="{y:.1f}" y2="{y:.1f}" stroke="{GRID}"/>')
    s.append(f'<text x="{L-8}" y="{y+4:.1f}" font-size="12" text-anchor="end" fill="{MUTED}">{10**e:,}</text>'.replace(",", "."))
for k in (0.01, 0.1, 1, 10, 100):
    x = X(k)
    s.append(f'<line x1="{x:.1f}" x2="{x:.1f}" y1="{T}" y2="{T+ph}" stroke="{GRID}"/>')
    s.append(f'<text x="{x:.1f}" y="{T+ph+20}" font-size="12" text-anchor="middle" fill="{MUTED}">{str(k).replace(".", ",")} %</text>')
s.append(f'<line x1="{L}" x2="{L+pw}" y1="{T+ph}" y2="{T+ph}" stroke="{MUTED}"/>')
s.append(f'<text x="{L+pw/2}" y="{H-25}" font-size="13" text-anchor="middle" fill="{INK}">k = porcentaje de pedidos leídos</text>')
s.append(f'<text x="22" y="{T+ph/2}" font-size="13" text-anchor="middle" fill="{INK}" transform="rotate(-90 22 {T+ph/2})">lecturas lógicas</text>')

# Cambio del optimizador: entre la última k con índice y la primera con recorrido completo
sw = next(i for i, r in enumerate(rows) if r[4])
xs = math.sqrt(rows[sw - 1][0] * rows[sw][0])
s.append(f'<line x1="{X(xs):.1f}" x2="{X(xs):.1f}" y1="{T}" y2="{T+ph}" stroke="{MUTED}" stroke-dasharray="5 4"/>')
s.append(f'<text x="{X(xs)+6:.1f}" y="{T+14}" font-size="12" fill="{INK}">el optimizador pasa a FULL</text>')
s.append(f'<text x="{X(xs)+6:.1f}" y="{T+29}" font-size="12" fill="{MUTED}">(entre {str(rows[sw-1][0]).replace(".", ",")} y {str(rows[sw][0]).replace(".", ",")} %)</text>')

cruces = []
def cruce(i):
    for a, b in zip(rows, rows[1:]):
        if a[i] <= a[3] and b[i] > b[3]:
            # interpolación log-log entre a y b
            fa, fb = math.log10(a[i] / a[3]), math.log10(b[i] / b[3])
            t = fa / (fa - fb)
            return 10 ** (math.log10(a[0]) + t * (math.log10(b[0]) - math.log10(a[0]))), a[3]
for i, nombre in ((2, "CF malo"), (1, "CF bueno")):
    c = cruce(i)
    if c:
        k, v = c
        cruces.append((k, v, nombre))

for nombre, i, color in series:
    pts = " ".join(f"{X(r[0]):.1f},{Y(r[i]):.1f}" for r in rows)
    s.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2"/>')
    for r in rows:
        s.append(f'<circle cx="{X(r[0]):.1f}" cy="{Y(r[i]):.1f}" r="4" fill="{color}" stroke="#ffffff" stroke-width="2"/>')
    last = rows[-1]
    dy = {1: -6, 3: 12}.get(i, 4)
    s.append(f'<text x="{L+pw+10}" y="{Y(last[i])+dy:.1f}" font-size="12" fill="{INK}">{nombre}</text>')
for k, v, nombre in cruces:
    etiqueta = f'{k:.2g}'.replace('.', ',')
    s.append(f'<circle cx="{X(k):.1f}" cy="{Y(v):.1f}" r="7" fill="none" stroke="{INK}" stroke-width="2"/>')
    if nombre == "CF malo":
        s.append(f'<text x="{X(k)+12:.1f}" y="{Y(v)+26:.1f}" font-size="12" text-anchor="start" fill="{INK}">{nombre} cruza la tabla en ≈ {etiqueta} %</text>')
    else:
        s.append(f'<text x="{X(k)-12:.1f}" y="{Y(v)-14:.1f}" font-size="12" text-anchor="end" fill="{INK}">{nombre} cruza la tabla en ≈ {etiqueta} %</text>')
s.append("</svg>")
open(out_path, "w", encoding="utf-8").write("\n".join(s))
print(len(rows), "puntos ->", out_path)
