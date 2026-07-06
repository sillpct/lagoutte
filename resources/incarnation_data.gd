class_name IncarnationData
extends Resource

# Identité — descriptif, aucune mécanique pour l'instant
@export var display_name: String = ""
@export var origine: String = ""
@export var profession: String = ""

# Statistiques d'incarnation
@export var vitalite: int = 100
@export var force: int = 20
@export var esprit: int = 20
@export var lucidite: int = 35

# Ressources de combat — valeurs de base/max ; les valeurs "courantes" viendront avec le combat
@export var pv_max: int = 150
@export var lucidite_max: int = 100
@export var points_action: int = 3
@export var agilite: int = 4
