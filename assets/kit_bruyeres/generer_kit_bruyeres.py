"""
Kit modulaire de Bruyeres - generateur parametrique.

Convention (identique dans tout le kit) :
  X = largeur, le long du mur      0 -> 2.00 m  (une travee)
  Y = hauteur                      0 -> 3.00 m  (un etage)
  Z = epaisseur                    0 = face rue (exterieur), 0.30 = interieur
  Origine = coin bas / gauche / face rue

Pavage : +2.00 en X pour la piece suivante, +3.00 en Y pour l'etage suivant.
Toutes les pieces partagent un seul materiau "PierreBruyeres" : re-tinter la
ville entiere = changer une seule valeur dans Godot.
"""

import math
import os
import json
import numpy as np
import trimesh
from shapely.geometry import Polygon

W, H, T = 2.0, 3.0, 0.30

PIERRE_HEX = "#D2CEC3"
PIERRE_LINEAR = [0.645, 0.618, 0.546, 1.0]

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit_bruyeres")
os.makedirs(OUT, exist_ok=True)


def box(x0, y0, z0, x1, y1, z1):
    m = trimesh.creation.box(extents=[x1 - x0, y1 - y0, z1 - z0])
    m.apply_translation([(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2])
    return m


def prism(plan_pts, y0, y1):
    """Prisme vertical a partir d'un contour en plan (x, z)."""
    n = len(plan_pts)
    verts = [[x, y0, z] for (x, z) in plan_pts] + [[x, y1, z] for (x, z) in plan_pts]
    faces = []
    for i in range(1, n - 1):
        faces.append([0, i + 1, i])
        faces.append([n, n + i, n + i + 1])
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j])
        faces.append([i, n + j, n + i])
    m = trimesh.Trimesh(vertices=np.array(verts), faces=np.array(faces))
    m.fix_normals()
    return m


def panel(holes=None):
    """Panneau de facade 2 x 3 x 0.30 avec zero ou plusieurs ouvertures."""
    outer = [(0, 0), (W, 0), (W, H), (0, H)]
    poly = Polygon(outer, holes or [])
    return trimesh.creation.extrude_polygon(poly, T)


def rect_hole(x0, x1, y0, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def arch_hole(x0, x1, y0, y_spring, y_top, segs=6):
    """Ouverture a linteau cintre, arc facette (low poly assume)."""
    cx, r = (x0 + x1) / 2, (x1 - x0) / 2
    rise = y_top - y_spring
    pts = [(x0, y0), (x1, y0), (x1, y_spring)]
    for i in range(1, segs):
        a = math.pi * i / segs
        pts.append((cx + r * math.cos(a), y_spring + rise * math.sin(a)))
    pts.append((x0, y_spring))
    return pts


def join(*meshes):
    return trimesh.util.concatenate(list(meshes))


PIECES = {}


def add(name, mesh, famille, note):
    PIECES[name] = {"mesh": mesh, "famille": famille, "note": note}


# ---------------------------------------------------------------- FACADES
add("FAC_mur_plein", panel(), "facade", "remplissage par defaut, mur aveugle")
add("FAC_fenetre", panel([rect_hole(0.45, 1.55, 0.90, 2.10)]), "facade",
    "fenetre 1.10 x 1.20, allege a 0.90")
add("FAC_fenetre_haute", panel([rect_hole(0.60, 1.40, 1.50, 2.30)]), "facade",
    "fenetre 0.80 x 0.80, dernier etage")
add("FAC_fenetre_jumelle", panel([rect_hole(0.30, 0.90, 0.90, 2.10),
                                  rect_hole(1.10, 1.70, 0.90, 2.10)]), "facade",
    "deux fenetres etroites, rythme serre")
# Largeurs de passage calees sur la navigation : l'agent fait 0.90 m de diametre et
# le navmesh erode 0.45 m de chaque bord. Une ouverture de 1.00 m ne laissait que
# 0.10 m navigable, soit aucun chemin. 1.40 m laisse 0.50 m, soit deux cellules de
# navmesh a 0.25 m -> robuste quel que soit le calage de la grille.
add("FAC_porte", panel([rect_hole(0.30, 1.70, 0.0, 2.10)]), "facade",
    "porte 1.40 x 2.10, une seule par maison, passage navmesh 0.50 m")
add("FAC_porte_cintree", panel([arch_hole(0.30, 1.70, 0.0, 1.55, 2.25)]), "facade",
    "porte cintree 1.40, passage navmesh 0.50 m")
add("FAC_arcade", panel([arch_hole(0.20, 1.80, 0.0, 1.60, 2.40)]), "facade",
    "arcade 1.60, passage navmesh 0.70 m")

_balcon = join(
    panel([rect_hole(0.45, 1.55, 0.90, 2.10)]),
    box(0.30, 0.85, -0.70, 1.70, 0.93, 0.0),
    box(0.30, 0.93, -0.72, 1.70, 1.35, -0.64),
    box(0.30, 0.93, -0.72, 0.38, 1.35, 0.0),
    box(1.62, 0.93, -0.72, 1.70, 1.35, 0.0),
)
add("FAC_fenetre_balcon", _balcon, "facade", "fenetre + balcon saillant de 0.70")

# ----------------------------------------------------------------- ANGLES
add("ANG_exterieur", box(0, 0, 0, 0.30, H, 0.30), "angle",
    "poteau d'angle sortant a 90 deg")
add("ANG_biseau_15", prism([(0, 0), (0.50, 0), (0.50 - 0.30 * math.tan(math.radians(15)), 0.30), (0, 0.30)], 0, H),
    "angle", "cale de mur, mange 15 deg au carrefour")
add("ANG_biseau_30", prism([(0, 0), (0.50, 0), (0.50 - 0.30 * math.tan(math.radians(30)), 0.30), (0, 0.30)], 0, H),
    "angle", "cale de mur, mange 30 deg au carrefour")

# ------------------------------------------------------------------ TOITS
add("TOI_corniche", box(0, 0, -0.15, W, 0.25, 0.30), "toit",
    "corniche saillante de 0.15, couronnement d'etage")
add("TOI_parapet", box(0, 0, 0, W, 0.70, 0.25), "toit", "parapet de terrasse")
add("TOI_angle_parapet", join(box(0, 0, 0, 0.25, 0.70, 2.0),
                              box(0.25, 0, 0, W, 0.70, 0.25)), "toit",
    "parapet en retour d'angle")
add("TOI_terrasse", box(0, -0.20, 0, W, 0.0, 2.0), "toit",
    "dalle de toit plat 2 x 2")

# ------------------------------------------------------------------- SOLS
add("SOL_dalle", box(0, -0.20, 0, W, 0.0, 2.0), "sol", "dalle de rue 2 x 2")
add("SOL_dalle_rigole", join(
    box(0, -0.20, 0, W, -0.10, 2.0),
    box(0, -0.10, 0, W, 0.0, 0.85),
    box(0, -0.10, 1.15, W, 0.0, 2.0)), "sol",
    "dalle avec rigole droite, largeur 0.30")
add("SOL_rigole_jonction", join(
    box(0, -0.20, 0, W, -0.10, 2.0),
    box(0, -0.10, 0, 0.85, 0.0, 0.85),
    box(1.15, -0.10, 0, W, 0.0, 0.85),
    box(0, -0.10, 1.15, W, 0.0, 2.0)), "sol",
    "jonction de rigoles en T")
add("SOL_caniveau", join(
    box(0, -0.20, 0, 0.60, -0.08, 0.60),
    box(0, -0.08, 0, 0.60, 0.0, 0.08),
    box(0, -0.08, 0.26, 0.60, 0.0, 0.34),
    box(0, -0.08, 0.52, 0.60, 0.0, 0.60)), "sol",
    "grille d'avaloir, ou l'eau descend")
add("SOL_marche", box(0, 0, 0, W, 0.17, 0.35), "sol", "marche, hauteur 0.17")
add("SOL_biseau_15", prism([(0, 0), (W, 0), (W, 2 * math.tan(math.radians(15)))], -0.20, 0.0),
    "sol", "dalle en coin, mange 15 deg au carrefour")

# -------------------------------------------------------- ARCHES ET APPUIS
_arc_pts = [(0, 0)]
for i in range(1, 9):
    _arc_pts.append((4.0 * i / 8.0, 0.50 * math.sin(math.pi * i / 8.0)))
_arc_pts += [(4.0, 0), (4.0, 1.0), (0, 1.0)]
add("ARC_rue", trimesh.creation.extrude_polygon(Polygon(_arc_pts), 1.20), "arche",
    "arc enjambant une rue de 4 m, pose a 3 m de haut")
add("ARC_contrefort", trimesh.creation.extrude_polygon(
    Polygon([(0, 0), (0.60, 0), (0.25, H), (0, H)]), 0.40), "arche",
    "contrefort entre deux facades")

# -------------------------------------------------------------- HABILLAGE
add("HAB_muret", box(0, 0, 0, W, 0.90, 0.30), "habillage", "muret bas 2 m")
add("HAB_seuil", box(0, 0, -0.45, 1.40, 0.12, 0.05), "habillage",
    "seuil de porte debordant sur la rue")

# ------------------------------------------------------------------ EXPORT
material = trimesh.visual.material.PBRMaterial(
    name="PierreBruyeres",
    baseColorFactor=PIERRE_LINEAR,
    metallicFactor=0.0,
    roughnessFactor=0.85,
)

# --------------------------------------------------------------- COLLISIONS
# Regle : la collision n'est pas le maillage visible. On garde des boites simples.
# Les fenetres sont bouchees (personne ne traverse une fenetre), seuls les vrais
# passages - portes et arcades - sont evides. Une boite au lieu d'un trimesh perce,
# c'est bien moins cher et bien plus robuste.
PASSAGES = {
    "FAC_porte": (0.30, 1.70, 0.0, 2.10),
    "FAC_porte_cintree": (0.30, 1.70, 0.0, 2.25),
    "FAC_arcade": (0.20, 1.80, 0.0, 2.40),
}

COL = os.path.join(OUT, "collisions")
os.makedirs(COL, exist_ok=True)


def collision_for(name, mesh):
    if name in PASSAGES:
        x0, x1, y0, y1 = PASSAGES[name]
        return join(box(0, 0, 0, x0, H, T),
                    box(x1, 0, 0, W, H, T),
                    box(x0, y1, 0, x1, H, T)), 3
    b = mesh.bounds
    return box(b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2]), 1


manifest, total_faces, total_col = [], 0, 0
for name in sorted(PIECES):
    m = PIECES[name]["mesh"]
    m.merge_vertices()

    col, nboxes = collision_for(name, m)
    col.export(os.path.join(COL, "COL_" + name + ".glb"))
    total_col += len(col.faces)

    try:
        m.visual = trimesh.visual.TextureVisuals(material=material)
    except Exception:
        pass
    m.export(os.path.join(OUT, name + ".glb"))
    b = m.bounds
    total_faces += len(m.faces)
    manifest.append({
        "nom": name,
        "famille": PIECES[name]["famille"],
        "note": PIECES[name]["note"],
        "min": [round(float(v), 3) for v in b[0]],
        "max": [round(float(v), 3) for v in b[1]],
        "dimensions": [round(float(v), 3) for v in (b[1] - b[0])],
        "triangles": int(len(m.faces)),
        "etanche": bool(m.is_watertight),
        "collision_boites": nboxes,
        "passage_navmesh_m": round(PASSAGES[name][1] - PASSAGES[name][0] - 0.90, 2)
                             if name in PASSAGES else None,
    })

with open(os.path.join(OUT, "manifeste.json"), "w") as f:
    json.dump({"module": {"largeur": W, "hauteur": H, "epaisseur": T},
               "materiau": {"nom": "PierreBruyeres", "hex_cible": PIERRE_HEX},
               "pieces": manifest}, f, indent=2, ensure_ascii=False)

print(f"{len(manifest)} pieces exportees")
print(f"  visuel    : {total_faces} triangles")
print(f"  collision : {total_col} triangles ({total_col / total_faces * 100:.0f} % du visuel)")
print()
print(f"{'piece':<22}{'famille':<11}{'dimensions (m)':<24}{'tris':>5}{'passage nav':>13}")
for p in manifest:
    d = " x ".join(f"{v:.2f}" for v in p["dimensions"])
    nav = f"{p['passage_navmesh_m']:.2f} m" if p["passage_navmesh_m"] else "-"
    print(f"{p['nom']:<22}{p['famille']:<11}{d:<24}{p['triangles']:>5}{nav:>13}")
