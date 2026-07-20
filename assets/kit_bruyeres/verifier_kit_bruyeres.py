"""
Verification du kit : on assemble reellement un bout de rue a partir des pieces,
on controle que tout se cale sur la grille, et on rend des images pour voir.
"""

import os
import json
import numpy as np
import trimesh
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "kit_bruyeres")
W, H = 2.0, 3.0

# direction exprimee dans l'espace du rendu (x = largeur, y = profondeur, z = hauteur)
LIGHT = np.array([-0.35, -0.55, 0.76])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
PIERRE = np.array([0.91, 0.90, 0.86])


def load(name):
    m = trimesh.load(os.path.join(KIT, name + ".glb"), force="mesh")
    return m


def shade(mesh):
    n = mesh.face_normals
    lit = np.clip(n @ LIGHT, 0, 1)
    inten = 0.55 + 0.45 * lit
    return np.clip(PIERRE[None, :] * inten[:, None], 0, 1)


def draw(ax, mesh, elev=22, azim=-58, cube=True):
    tris = mesh.vertices[mesh.faces]
    pc = Poly3DCollection(tris, facecolors=shade(mesh), edgecolors=(0.45, 0.45, 0.43, 0.35),
                          linewidths=0.2)
    ax.add_collection3d(pc)
    b = mesh.bounds
    ext = b[1] - b[0]
    if cube:
        c, r = (b[0] + b[1]) / 2, max(ext) / 2 * 1.08
        ax.set_xlim(c[0] - r, c[0] + r)
        ax.set_ylim(c[1] - r, c[1] + r)
        ax.set_zlim(c[2] - r, c[2] + r)
        ax.set_box_aspect((1, 1, 1))
    else:
        dy = max(ext[1], 1.0)
        ax.set_xlim(b[0][0] - 0.4, b[1][0] + 0.4)
        ax.set_ylim(b[0][1] - dy * 0.4, b[1][1] + dy * 0.4)
        ax.set_zlim(b[0][2] - 0.4, b[1][2] + 0.4)
        ax.set_box_aspect((ext[0], dy * 1.8, ext[2]))
    ax.view_init(elev=elev, azim=azim)
    ax.set_axis_off()


def to_plot(mesh):
    """Godot Y-up -> matplotlib Z-up."""
    m = mesh.copy()
    v = m.vertices.copy()
    m.vertices = np.column_stack([v[:, 0], v[:, 2], v[:, 1]])
    m.fix_normals()
    return m


manifest = json.load(open(os.path.join(KIT, "manifeste.json")))
noms = [p["nom"] for p in manifest["pieces"]]

# ------------------------------------------------- planche de contact
fig = plt.figure(figsize=(15, 15), facecolor="white")
for i, nom in enumerate(noms):
    ax = fig.add_subplot(5, 5, i + 1, projection="3d")
    draw(ax, to_plot(load(nom)))
    ax.set_title(nom, fontsize=9, pad=0, y=0.94)
fig.subplots_adjust(left=0.01, right=0.99, top=0.98, bottom=0.01, wspace=0.0, hspace=0.0)
fig.savefig(os.path.join(HERE, "kit_bruyeres_planche.png"), dpi=110,
            bbox_inches="tight", facecolor="white")
plt.close(fig)

# ------------------------------------------------- assemblage de controle
PLAN = {
    # (piece, bay, etage)  bay = index de travee, etage = index d'etage
    "A": {"x0": 0.0, "cells": [
        ("FAC_mur_plein", 0, 0), ("FAC_porte", 1, 0), ("FAC_mur_plein", 2, 0),
        ("FAC_fenetre", 0, 1), ("FAC_mur_plein", 1, 1), ("FAC_fenetre", 2, 1),
        ("FAC_fenetre", 0, 2), ("FAC_mur_plein", 1, 2), ("FAC_fenetre", 2, 2),
    ], "bays": 3, "floors": 3},
    "B": {"x0": 6.0, "cells": [
        ("FAC_arcade", 0, 0), ("FAC_arcade", 1, 0), ("FAC_porte_cintree", 2, 0),
        ("FAC_mur_plein", 3, 0),
        ("FAC_fenetre_balcon", 0, 1), ("FAC_fenetre", 1, 1),
        ("FAC_fenetre", 2, 1), ("FAC_fenetre", 3, 1),
        ("FAC_fenetre_haute", 0, 2), ("FAC_fenetre_haute", 1, 2),
        ("FAC_mur_plein", 2, 2), ("FAC_fenetre_haute", 3, 2),
    ], "bays": 4, "floors": 3},
    # batiment volontairement presque aveugle, et plus bas : c'est lui qui fait
    # respirer les deux autres
    "C": {"x0": 14.0, "cells": [
        ("FAC_porte", 0, 0), ("FAC_mur_plein", 1, 0), ("FAC_mur_plein", 2, 0),
        ("FAC_mur_plein", 0, 1), ("FAC_mur_plein", 1, 1), ("FAC_fenetre", 2, 1),
    ], "bays": 3, "floors": 2},
}

parts, occupied = [], set()
for nom_b, b in PLAN.items():
    for piece, bay, floor in b["cells"]:
        m = load(piece)
        m.apply_translation([b["x0"] + bay * W, floor * H, 0.0])
        parts.append(m)
        key = (round(b["x0"] + bay * W, 3), floor)
        assert key not in occupied, f"collision en {key}"
        occupied.add(key)
    # corniche de couronnement sur toute la largeur
    for bay in range(b["bays"]):
        m = load("TOI_corniche")
        m.apply_translation([b["x0"] + bay * W, b["floors"] * H, 0.0])
        parts.append(m)
    # sol devant le batiment
    for bay in range(b["bays"]):
        m = load("SOL_dalle_rigole" if bay % 2 else "SOL_dalle")
        m.apply_translation([b["x0"] + bay * W, 0.0, -2.0])
        parts.append(m)

assemblage = trimesh.util.concatenate(parts)
assemblage.export(os.path.join(KIT, "ASSEMBLAGE_controle.glb"))

# repere humain de 1,80 m, uniquement pour le rendu de controle
repere = trimesh.creation.box(extents=[0.50, 1.80, 0.35])
repere.apply_translation([9.0, 0.90, -1.10])
rendu = trimesh.util.concatenate([assemblage, repere])

b = assemblage.bounds
print("ASSEMBLAGE DE CONTROLE")
print(f"  pieces posees        : {len(parts)}")
print(f"  triangles            : {len(assemblage.faces)}")
print(f"  emprise X            : {b[0][0]:.2f} -> {b[1][0]:.2f} m")
print(f"  hauteur Y            : {b[0][1]:.2f} -> {b[1][1]:.2f} m")
print(f"  profondeur Z         : {b[0][2]:.2f} -> {b[1][2]:.2f} m")

# controles de grille
erreurs = []
for x, f in sorted(occupied):
    if abs(x % W) > 1e-6:
        erreurs.append(f"travee hors grille en x={x}")
for nom_b, bdef in PLAN.items():
    largeur = bdef["bays"] * W
    if abs(largeur % W) > 1e-6:
        erreurs.append(f"batiment {nom_b} non multiple de 2 m")
print(f"  travees occupees     : {len(occupied)}")
print(f"  erreurs de grille    : {erreurs if erreurs else 'aucune'}")

fig = plt.figure(figsize=(15, 10), facecolor="white")
ax = fig.add_subplot(2, 1, 1, projection="3d")
draw(ax, to_plot(rendu), elev=4, azim=-90, cube=False)
ax.set_title("elevation de rue - assemblee uniquement avec les pieces du kit "
             "(repere humain 1,80 m)", fontsize=11, y=0.97)
ax = fig.add_subplot(2, 1, 2, projection="3d")
draw(ax, to_plot(rendu), elev=20, azim=-62, cube=False)
ax.set_title("vue trois quarts", fontsize=11, y=0.97)
fig.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01, hspace=0.02)
fig.savefig(os.path.join(HERE, "kit_bruyeres_assemblage.png"), dpi=120,
            bbox_inches="tight", facecolor="white")
plt.close(fig)
print("\nimages ecrites : kit_bruyeres_planche.png, kit_bruyeres_assemblage.png")
