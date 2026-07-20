# Kit modulaire de Bruyères — mode d'emploi

**25 pièces, 664 triangles au total.** Format `.glb`, prêt pour Godot 4.6.
Toutes les pièces partagent un seul matériau nommé `PierreBruyeres`.

---

## 1. La convention, à ne jamais casser

| Axe | Sens | Étendue d'une pièce de façade |
|---|---|---|
| **X** | largeur, le long du mur | 0 → 2,00 m (une travée) |
| **Y** | hauteur | 0 → 3,00 m (un étage) |
| **Z** | épaisseur | 0 = **face rue**, 0,30 = intérieur |

**Origine de chaque pièce : coin bas / gauche / face rue.**
Pavage : `+2,00` en X pour la travée suivante, `+3,00` en Y pour l'étage suivant.
Les dalles de sol vont de `Y = −0,20` à `Y = 0` : le niveau de la rue est donc **Y = 0**,
et les façades s'y posent directement.

Vérifié : les 25 pièces sont calées à l'origine, aucune n'est hors grille.
Un assemblage de contrôle de 20 m de rue (47 pièces, 3 bâtiments) a été monté sans une
seule erreur d'alignement — voir `ASSEMBLAGE_controle.glb`.

---

## 2. Les 25 pièces

**Façades (8)** — toutes 2 × 3 × 0,30
`FAC_mur_plein` · `FAC_fenetre` · `FAC_fenetre_haute` · `FAC_fenetre_jumelle` ·
`FAC_fenetre_balcon` · `FAC_porte` · `FAC_porte_cintree` · `FAC_arcade`

**Angles (3)**
`ANG_exterieur` (90°) · `ANG_biseau_15` · `ANG_biseau_30` — les deux biseaux sont les
pièces qui mangent l'angle aux carrefours du plan radial.

**Toits (4)**
`TOI_corniche` · `TOI_parapet` · `TOI_angle_parapet` · `TOI_terrasse`

**Sols (6)**
`SOL_dalle` · `SOL_dalle_rigole` · `SOL_rigole_jonction` · `SOL_caniveau` ·
`SOL_marche` · `SOL_biseau_15`

**Arches (2)**
`ARC_rue` (enjambe une rue de 4 m) · `ARC_contrefort`

**Habillage (2)**
`HAB_muret` · `HAB_seuil`

---

## 3. Les patrons de façade

Le réel ne vient pas du désordre. Une façade dont les fenêtres sont placées au hasard se
repère immédiatement comme fausse. Cinq règles, appliquées **par bâtiment**, jamais par pièce :

1. Les ouvertures **s'empilent à la verticale** : les mêmes travées sont percées à tous les étages.
2. Le **rez-de-chaussée casse le rythme** : arcades, porte, trous plus grands.
3. **Une seule porte par maison**, pas une par travée.
4. Les **fenêtres du dernier étage sont plus petites** (`FAC_fenetre_haute`).
5. Les **murs aveugles existent** et sont gratuits — ce sont eux qui font respirer les autres.

L'irrégularité vient de la **largeur et de la hauteur des bâtiments** (3 travées, puis 4,
puis 3 sur deux étages), jamais du chaos des ouvertures.

---

## 4. Passages et navigation

Les largeurs d'ouverture sont calées sur l'agent de navigation, pas sur l'esthétique.
L'agent fait 0,90 m de diamètre et le navmesh érode 0,45 m sur chaque bord.

| Pièce | Ouverture | Navigable après érosion |
|---|---|---|
| `FAC_porte` | 1,40 m | **0,50 m** |
| `FAC_porte_cintree` | 1,40 m | **0,50 m** |
| `FAC_arcade` | 1,60 m | **0,70 m** |

0,50 m représente deux cellules de navmesh à 0,25 m : le passage survit quel que soit le
calage de la grille. À 1,20 m d'ouverture on ne serait qu'à 0,30 m, soit une seule cellule —
le passage disparaîtrait ou non selon l'alignement. D'où le choix de 1,40 m.

**Ne jamais descendre une ouverture de passage sous 1,40 m** sans revérifier ce calcul.

---

## 5. Collisions

Le dossier `kit_bruyeres/collisions/` contient un `COL_<piece>.glb` pour chaque pièce.

**Principe : la collision n'est pas le maillage visible.** Ce sont des boîtes simples —
372 triangles pour tout le kit, contre 664 pour le visuel.

- Les **fenêtres sont bouchées** dans la collision : personne ne traverse une fenêtre, et
  une boîte pleine coûte bien moins cher qu'un maillage percé.
- Seuls les **vrais passages** (porte, porte cintrée, arcade) sont évidés, en 3 boîtes :
  piédroit gauche, piédroit droit, linteau.
- Tout le reste est sa boîte englobante.

Ne pas générer de collision *trimesh* à partir des maillages visibles : c'est plus lourd,
plus fragile, et ça n'apporte rien sur une architecture faite de boîtes.

---

## 6. Import dans Godot

1. Glisser le dossier `kit_bruyeres/` dans le projet.
2. Godot importe les `.glb` automatiquement. L'échelle est déjà bonne : **1 unité = 1 mètre**,
   ne pas toucher au facteur d'échelle à l'import.
3. Pour re-tinter la ville entière : le matériau `PierreBruyeres` est partagé par toutes les
   pièces. **Changer sa couleur une fois change toute la ville.** Cible actuelle : `#D2CEC3`.

### GridMap

Le module de 2 m correspond à une cellule GridMap de `Vector3(2, 3, 2)`. C'est la bonne
piste, avec deux pièges à connaître.

**Piège 1 — GridMap ne tourne que par quarts de tour.** Les 24 orientations orthogonales
seulement. Les pièces `ANG_biseau_15` et `ANG_biseau_30`, et plus largement l'angle des rues
radiales, sont impossibles à exprimer dans la grille.
*Solution :* **une GridMap par îlot, et on fait tourner le nœud GridMap entier** à son angle
radial. À l'intérieur, alignement parfait garanti ; entre les îlots, les biseaux sont posés
comme des nœuds ordinaires. C'est propre et ça préserve les deux avantages.

**Piège 2 — GridMap centre les objets sur la cellule.** Les pièces du kit ont leur origine
au coin, pas au centre. Il faut absorber le décalage dans la transformation de l'item de la
MeshLibrary, ou repartir d'une variante recentrée du kit (générable à la demande).

**Bénéfice :** chaque item de MeshLibrary porte sa propre forme de collision — les fichiers
`COL_*` de la section 5 s'y branchent directement, et la question des collisions se règle
d'elle-même.

**Réserve honnête :** tous les exemplaires d'un même item partagent le même matériau. Or la
variation de valeur de la pierre **d'un bâtiment à l'autre** est le principal moyen
anti-répétition du kit. Contournement peu coûteux : trois variantes teintées de
`FAC_mur_plein` et `FAC_fenetre`, soit six items de plus dans la bibliothèque.

---

## 7. Consignes pour l'usure et les détails

À transmettre tel quel.

**La règle qui prime sur tout : ne jamais déplacer les points d'accroche.** Les bords à
X = 0 et X = 2,00, et la ligne de plancher à Y = 3,00, définissent l'emboîtement. S'ils
bougent de deux centimètres, plus rien ne se cale et toute la ville se décale.
Les détails restent **à l'intérieur du volume de la pièce**, sauf saillies volontaires
(corniche, seuil, balcon) qui sont déjà prévues et ne doivent pas être élargies.

**Travailler sur des copies.** Les fichiers d'origine restent intacts, on garde toujours la
version nue en secours.

**Par ordre de rendement**, l'usure la plus utile :

1. **La ligne d'humidité au pied des murs** — trace d'éclaboussure plus sombre, à 40–60 cm
   du sol, sur toutes les façades. À Bruyères il pleut sans arrêt : c'est ce détail qui dira
   « il pleut ici depuis toujours » sans qu'une goutte soit affichée. C'est le plus rentable
   de tous, très loin devant.
2. **Angles épannelés** — les arêtes verticales usées par le passage, jamais parfaitement vives.
3. **Seuils creusés** sous les portes et les arcades.
4. **Le vert dans les joints bas** — la végétation qui s'installe au ras du sol.

**Ce qu'il ne faut pas faire :** de l'écaillure aléatoire répartie uniformément. L'usure suit
l'usage — l'eau, les mains, les pieds. Là où personne ne passe, la pierre reste nette.

---

## 8. Ce qui n'est volontairement pas dans le kit

Ruines, végétation, props d'habillage (charrettes, étals, auvents, lanternes, jardinières,
cordes à linge) et personnages : **ça vient de packs**, pas du custom. Principe :
*acheter ce qui est cher et générique, fabriquer ce qui est bon marché et identitaire.*
Les façades portent l'identité et coûtent trois fois rien à produire — d'où ce kit.
Une jardinière coûte cher à modéliser et personne ne reconnaîtra sa provenance.

---

## 9. La rue assemblée

`Bruyeres_Rue_Kit.tscn` remplace le greybox CSG. Mêmes dimensions validées :
**50 m de long, 4 m de large au centre, 8 m en bout de rue** (le retrait est calé sur le
module, d'où 8 m et non 7).

| | |
|---|---|
| Bâtiments | 9, contigus, de 6 / 9 / 12 m (2, 3 et 4 étages) |
| Pièces posées | 463, en 13 types |
| Triangles | 8 052 pour 50 m de rue |
| Collisions | **12 `BoxShape3D`**, une par bâtiment plus trois pour le sol |
| Sol | continu, rigole sur toute la longueur, avaloir tous les 10 m |

Les hauteurs sont des multiples de 3 m — c'est l'étage qui commande. 6 / 9 / 12 encadre les
7–11 m validés sur le greybox.

**Les portes sont bouchées côté collision** tant qu'il n'y a pas d'intérieurs : un navmesh
qui s'engouffre dans une porte donnant sur du plein crée un cul-de-sac inutile. Quand
l'appartement du prologue existera, il suffira de retirer la boîte du bâtiment concerné.

Les bouts de rue sont fermés par des murs aveugles pour que la scène tienne seule pendant
les tests — à retirer au raccordement avec les zones voisines.

---

## 10. Fichiers

| Fichier | Rôle |
|---|---|
| `kit_bruyeres/*.glb` | les 25 pièces |
| `kit_bruyeres/collisions/COL_*.glb` | les 25 volumes de collision simplifiés |
| `kit_bruyeres/manifeste.json` | dimensions, familles, triangles, passages navmesh |
| `kit_bruyeres/ASSEMBLAGE_controle.glb` | 20 m de rue montés, preuve d'emboîtement |
| `Bruyeres_Rue_Kit.tscn` | **la rue jouable de 50 m**, à ouvrir dans Godot |
| `generer_kit_bruyeres.py` | générateur du kit — pour modifier une cote, on régénère |
| `verifier_kit_bruyeres.py` | contrôle de grille + rendus du kit |
| `generer_rue_bruyeres.py` | générateur de la rue — le tracé se modifie ici |

Le chemin du kit dans la scène est `res://assets/kit_bruyeres/`. S'il change, c'est la
constante `RES` en haut de `generer_rue_bruyeres.py` qu'il faut modifier, puis relancer.

Le kit est **paramétrique** : si le module devait changer, on ne remodélise rien, on change
deux constantes en haut du générateur et on relance.
