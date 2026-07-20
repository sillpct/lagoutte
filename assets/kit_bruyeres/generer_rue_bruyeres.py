"""
Rue de Bruyeres assemblee avec le kit -> scene Godot .tscn + rendu de controle.

Remplace le greybox CSG. Meme longueur (50 m), meme canyon (4 m au centre),
meme ouverture en bout de rue (8 m, cale sur le module).

Sortie :
  Bruyeres_Rue_Kit.tscn        scene Godot prete a ouvrir
  rue_bruyeres_apercu.png      rendu de controle
"""

import os
import math
import numpy as np
import trimesh
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "kit_bruyeres")

# Chemin du kit une fois copie dans le projet Godot.
# Si l'arborescence change, c'est la SEULE ligne a modifier.
RES = "res://assets/kit_bruyeres/"

BAY, FLOOR, DEPTH = 2.0, 3.0, 6.0
NBAYS = 25                      # 25 x 2 m = 50 m de rue

# ------------------------------------------------------------------ LA RUE
# x = plan de facade. Retrait en bout de rue : la rue passe de 4 m a 8 m.
BATIMENTS = [
    dict(nom="L1", row="L", x=-2.0, bay0=0,  bays=5, floors=3, rythme=2, phase=0,
         porte=2, arcades=[], cintree=False, balcons=[]),
    dict(nom="L2", row="L", x=-2.0, bay0=5,  bays=6, floors=4, rythme=2, phase=1,
         porte=0, arcades=[2, 3], cintree=True, balcons=[1]),
    dict(nom="L3", row="L", x=-2.0, bay0=11, bays=5, floors=3, rythme=2, phase=0,
         porte=4, arcades=[], cintree=False, balcons=[]),
    dict(nom="L4", row="L", x=-2.0, bay0=16, bays=3, floors=2, rythme=3, phase=2,
         porte=0, arcades=[], cintree=False, balcons=[]),
    dict(nom="L5", row="L", x=-4.0, bay0=19, bays=6, floors=3, rythme=2, phase=1,
         porte=1, arcades=[4], cintree=False, balcons=[3]),

    dict(nom="R1", row="R", x=2.0, bay0=0,  bays=6, floors=3, rythme=2, phase=1,
         porte=3, arcades=[], cintree=True, balcons=[]),
    dict(nom="R2", row="R", x=2.0, bay0=6,  bays=6, floors=2, rythme=3, phase=0,
         porte=1, arcades=[], cintree=False, balcons=[]),
    dict(nom="R3", row="R", x=2.0, bay0=12, bays=8, floors=4, rythme=2, phase=0,
         porte=6, arcades=[2, 3], cintree=False, balcons=[1, 5]),
    dict(nom="R4", row="R", x=4.0, bay0=20, bays=5, floors=3, rythme=2, phase=0,
         porte=2, arcades=[], cintree=False, balcons=[]),
]

# retours de mur au droit des retraits
RETOURS = [dict(nom="retour_gauche", x=-2.0, z=38.0, floors=2),
           dict(nom="retour_droit",  x=4.0,  z=40.0, floors=2)]


def piece_for(b, i, floor):
    """Choix de la piece pour la travee i, etage floor. Applique les 5 regles."""
    top = (floor == b["floors"] - 1)
    ouverte = (i % b["rythme"]) == b["phase"]
    if floor == 0:
        if i == b["porte"]:
            return "FAC_porte_cintree" if b["cintree"] else "FAC_porte"
        if i in b["arcades"]:
            return "FAC_arcade"
        return "FAC_mur_plein"
    if not ouverte:
        return "FAC_mur_plein"
    if top:
        return "FAC_fenetre_haute"
    if floor == 1 and i in b["balcons"]:
        return "FAC_fenetre_balcon"
    if b["bays"] >= 6 and i % 4 == b["phase"]:
        return "FAC_fenetre_jumelle"
    return "FAC_fenetre"


def basis(theta):
    c, s = math.cos(theta), math.sin(theta)
    return [c, 0, s, 0, 1, 0, -s, 0, c]


def xform(theta, p):
    b = basis(theta)
    vals = b + [p[0], p[1], p[2]]
    return "Transform3D(" + ", ".join(f"{v:.6g}" for v in vals) + ")"


T_L, T_R, T_RET = -math.pi / 2, math.pi / 2, math.pi

placements = []   # (piece, theta, position)

for b in BATIMENTS:
    for i in range(b["bays"]):
        bay = b["bay0"] + i
        for f in range(b["floors"]):
            nom = piece_for(b, i, f)
            if b["row"] == "L":
                placements.append((nom, T_L, (b["x"], f * FLOOR, bay * BAY)))
            else:
                placements.append((nom, T_R, (b["x"], f * FLOOR, (bay + 1) * BAY)))
        # corniche de couronnement
        y = b["floors"] * FLOOR
        if b["row"] == "L":
            placements.append(("TOI_corniche", T_L, (b["x"], y, bay * BAY)))
        else:
            placements.append(("TOI_corniche", T_R, (b["x"], y, (bay + 1) * BAY)))

for r in RETOURS:
    for f in range(r["floors"]):
        placements.append(("FAC_mur_plein", T_RET, (r["x"], f * FLOOR, r["z"])))
    placements.append(("TOI_corniche", T_RET, (r["x"], r["floors"] * FLOOR, r["z"])))

# ------------------------------------------------------------------ TOITS
# Toits plats : sans eux, la camera tactique plonge dans des boites ouvertes.
# La corniche monte de 0.25 au-dessus de la dalle et fait office d'acrotere.
for b in BATIMENTS:
    y = b["floors"] * FLOOR
    if b["row"] == "L":
        xs = [b["x"] - 2, b["x"] - 4, b["x"] - 6]
    else:
        xs = [b["x"], b["x"] + 2, b["x"] + 4]
    for i in range(b["bays"]):
        z = (b["bay0"] + i) * BAY
        for x in xs:
            placements.append(("TOI_terrasse", 0.0, (x, y, z)))

# --------------------------------------------------------- BOUTS DE RUE
# Murs aveugles fermant les deux extremites, pour que la scene se tienne
# seule pendant les tests. A retirer quand la rue sera raccordee a ses voisines.
for b in BATIMENTS:
    for bout, theta, zc in ((0, 0.0, 0.0), (NBAYS, T_RET, NBAYS * BAY)):
        if b["bay0"] != 0 and bout == 0:
            continue
        if b["bay0"] + b["bays"] != NBAYS and bout == NBAYS:
            continue
        if b["row"] == "L":
            xs = [b["x"] - 6, b["x"] - 4, b["x"] - 2] if theta == 0.0 else \
                 [b["x"], b["x"] - 2, b["x"] - 4]
        else:
            xs = [b["x"], b["x"] + 2, b["x"] + 4] if theta == 0.0 else \
                 [b["x"] + 6, b["x"] + 4, b["x"] + 2]
        for f in range(b["floors"]):
            for x in xs:
                placements.append(("FAC_mur_plein", theta, (x, f * FLOOR, zc)))

# ------------------------------------------------------------------- SOLS
# Rigole centrale legerement decalee, cale sur le module : elle occupe la
# bande x = 0..2, son caniveau court sur x = 1. Tout converge vers la Place.
for bay in range(NBAYS):
    z = bay * BAY
    large = z >= 40.0
    moyen = 38.0 <= z < 40.0
    placements.append(("SOL_dalle_rigole", T_L, (2.0, 0.0, z)))
    placements.append(("SOL_dalle", 0.0, (-2.0, 0.0, z)))
    if large or moyen:
        placements.append(("SOL_dalle", 0.0, (-4.0, 0.0, z)))
    if large:
        placements.append(("SOL_dalle", 0.0, (2.0, 0.0, z)))
    if bay % 5 == 4:
        placements.append(("SOL_caniveau", 0.0, (0.70, 0.0, z + 0.70)))

# -------------------------------------------------------------- COLLISIONS
collisions = []   # (nom, centre, demi-dimensions)
for b in BATIMENTS:
    z0, z1 = b["bay0"] * BAY, (b["bay0"] + b["bays"]) * BAY
    xa = b["x"] - DEPTH if b["row"] == "L" else b["x"] + DEPTH
    x0, x1 = min(b["x"], xa), max(b["x"], xa)
    h = b["floors"] * FLOOR
    collisions.append((f"col_{b['nom']}",
                       ((x0 + x1) / 2, h / 2, (z0 + z1) / 2),
                       ((x1 - x0) / 2, h / 2, (z1 - z0) / 2)))

collisions.append(("col_sol_serre", (0.0, -0.10, 19.0), (2.0, 0.10, 19.0)))
collisions.append(("col_sol_transition", (-1.0, -0.10, 39.0), (3.0, 0.10, 1.0)))
collisions.append(("col_sol_ouvert", (0.0, -0.10, 45.0), (4.0, 0.10, 5.0)))

# ------------------------------------------------------------ ECRITURE TSCN
used = sorted({p[0] for p in placements})
ext_id = {nom: f"kit_{i}" for i, nom in enumerate(used)}

L = []
nsteps = len(used) + 4
L.append(f'[gd_scene load_steps={nsteps + len(collisions) + 1} format=3 '
         f'uid="uid://bruyeres_rue_kit"]\n')
for nom in used:
    L.append(f'[ext_resource type="PackedScene" uid="uid://kit_{nom}" '
             f'path="{RES}{nom}.glb" id="{ext_id[nom]}"]')
L.append("")

L.append('[sub_resource type="ProceduralSkyMaterial" id="SkyMat"]')
L.append("sky_top_color = Color(0.86, 0.88, 0.92, 1)")
L.append("sky_horizon_color = Color(0.94, 0.94, 0.95, 1)")
L.append("sky_curve = 0.25")
L.append("ground_bottom_color = Color(0.85, 0.85, 0.86, 1)")
L.append("ground_horizon_color = Color(0.94, 0.94, 0.95, 1)")
L.append("energy_multiplier = 1.3\n")
L.append('[sub_resource type="Sky" id="Sky"]')
L.append('sky_material = SubResource("SkyMat")\n')
L.append('[sub_resource type="Environment" id="Env"]')
L.append("background_mode = 2")
L.append('sky = SubResource("Sky")')
L.append("ambient_light_source = 3")
L.append("ambient_light_sky_contribution = 1.0")
L.append("ambient_light_energy = 1.1")
L.append("tonemap_mode = 2")
L.append("tonemap_white = 1.2")
L.append("glow_enabled = true")
L.append("glow_intensity = 0.5")
L.append("glow_bloom = 0.1")
L.append("fog_enabled = true")
L.append("fog_light_color = Color(0.9, 0.91, 0.93, 1)")
L.append("fog_density = 0.012")
L.append("fog_sky_affect = 0.4\n")

for nom, c, e in collisions:
    L.append(f'[sub_resource type="BoxShape3D" id="{nom}"]')
    L.append(f"size = Vector3({e[0]*2:.4g}, {e[1]*2:.4g}, {e[2]*2:.4g})\n")

L.append('[node name="BruyeresRueKit" type="Node3D"]\n')
L.append('[node name="Environnement" type="WorldEnvironment" parent="."]')
L.append('environment = SubResource("Env")\n')
L.append('[node name="SoleilVoile" type="DirectionalLight3D" parent="."]')
L.append("transform = Transform3D(0.798, -0.4515, 0.4, 0, 0.6637, 0.75, "
         "-0.602, -0.5985, 0.53, 0, 20, 20)")
L.append("light_color = Color(1, 0.97, 0.92, 1)")
L.append("light_energy = 0.9")
L.append("light_angular_distance = 2.0")
L.append("shadow_enabled = true\n")

groupes = {"SOL": "Sols", "FAC": "Facades", "TOI": "Couronnements",
           "ANG": "Angles", "ARC": "Arches", "HAB": "Habillage"}
for g in dict.fromkeys(groupes.values()):
    L.append(f'[node name="{g}" type="Node3D" parent="."]\n')

compteur = {}
for nom, th, p in placements:
    g = groupes[nom[:3]]
    compteur[nom] = compteur.get(nom, 0) + 1
    node = f"{nom}_{compteur[nom]:03d}"
    L.append(f'[node name="{node}" parent="{g}" instance=ExtResource("{ext_id[nom]}")]')
    L.append(f"transform = {xform(th, p)}\n")

L.append('[node name="Collisions" type="StaticBody3D" parent="."]\n')
for nom, c, e in collisions:
    L.append(f'[node name="{nom}" type="CollisionShape3D" parent="Collisions"]')
    L.append(f"transform = {xform(0.0, c)}")
    L.append(f'shape = SubResource("{nom}")\n')

L.append('[node name="CamTactique" type="Camera3D" parent="."]')
L.append("transform = Transform3D(-0.832, -0.1976, 0.518, 0, 0.934, 0.356, "
         "-0.555, 0.2962, -0.777, 16, 14, 0)")
L.append("fov = 45.0")

tscn = os.path.join(HERE, "Bruyeres_Rue_Kit.tscn")
open(tscn, "w").write("\n".join(L))

# -------------------------------------------------------------- VERIFICATION
print("RUE DE BRUYERES - assemblee avec le kit")
print(f"  longueur              : {NBAYS * BAY:.0f} m ({NBAYS} travees)")
print(f"  largeur au centre     : 4 m   |  en bout de rue : 8 m")
print(f"  batiments             : {len(BATIMENTS)}")
print(f"  pieces posees         : {len(placements)}")
print(f"  types de pieces       : {len(used)}")
print(f"  formes de collision   : {len(collisions)} BoxShape3D")

hauteurs = sorted({b["floors"] * FLOOR for b in BATIMENTS})
print(f"  hauteurs de facade    : {', '.join(f'{h:.0f} m' for h in hauteurs)}")

erreurs = []
for nom, th, p in placements:
    if abs(p[2] % 1.0) > 1e-6 and nom.startswith(("FAC", "TOI")):
        erreurs.append(f"{nom} hors grille en z={p[2]}")
    if nom.startswith("FAC") and abs(p[1] % FLOOR) > 1e-6:
        erreurs.append(f"{nom} hors etage en y={p[1]}")
print(f"  erreurs de grille     : {erreurs if erreurs else 'aucune'}")

occupe = {}
for nom, th, p in placements:
    if not nom.startswith("FAC"):
        continue
    cle = (round(p[0], 2), round(p[1], 2), round(p[2], 2), round(th, 3))
    if cle in occupe:
        erreurs.append(f"doublon en {cle}")
    occupe[cle] = nom
print(f"  travees de facade     : {len(occupe)}")
print(f"  doublons              : {'aucun' if not erreurs else erreurs}")

# ------------------------------------------------------------------- RENDU
LIGHT = np.array([-0.35, -0.55, 0.76]); LIGHT /= np.linalg.norm(LIGHT)
PIERRE = np.array([0.91, 0.90, 0.86])
cache, parts = {}, []
for nom, th, p in placements:
    if nom not in cache:
        cache[nom] = trimesh.load(os.path.join(KIT, nom + ".glb"), force="mesh")
    m = cache[nom].copy()
    m.apply_transform(trimesh.transformations.rotation_matrix(th, [0, 1, 0]))
    m.apply_translation(p)
    parts.append(m)
rue = trimesh.util.concatenate(parts)
print(f"  triangles (rue)       : {len(rue.faces)}")

v = rue.vertices.copy()
rue.vertices = np.column_stack([v[:, 2], v[:, 0], v[:, 1]])   # Z-> largeur ecran
rue.fix_normals()

fig = plt.figure(figsize=(16, 11), facecolor="white")
for k, (elev, azim, titre) in enumerate([
        (12, -78, "la rue depuis l'entree - canyon de 4 m"),
        (38, -62, "vue tactique - toits plats et acroteres"),
        (88, -90, "plan - sol continu, rigole sur toute la longueur")]):
    ax = fig.add_subplot(3, 1, k + 1, projection="3d")
    tris = rue.vertices[rue.faces]
    lit = np.clip(rue.face_normals @ LIGHT, 0, 1)
    fc = np.clip(PIERRE[None, :] * (0.55 + 0.45 * lit)[:, None], 0, 1)
    ax.add_collection3d(Poly3DCollection(tris, facecolors=fc,
                                         edgecolors=(0.45, 0.45, 0.43, 0.25),
                                         linewidths=0.15))
    b = rue.bounds
    ext = b[1] - b[0]
    ax.set_xlim(b[0][0], b[1][0]); ax.set_ylim(b[0][1] - 1, b[1][1] + 1)
    ax.set_zlim(b[0][2], b[1][2] + 1)
    ax.set_box_aspect((ext[0], ext[1] * 2.2, ext[2] * 1.6))
    ax.view_init(elev=elev, azim=azim); ax.set_axis_off()
    ax.set_title(titre, fontsize=11, y=0.94)
fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01, hspace=0.0)
fig.savefig(os.path.join(HERE, "rue_bruyeres_apercu.png"), dpi=115,
            bbox_inches="tight", facecolor="white")
print("\necrit : Bruyeres_Rue_Kit.tscn, rue_bruyeres_apercu.png")
