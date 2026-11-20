class_name MedicationProfile
extends Resource
## MedicationProfile (L1, DATA_STRUCTURES §1.7): efeito da bombinha. Padrões = proposta inicial da §1.7.
## Não tem efeito em stamina (PHY-INV-2). As cargas são do inventário (F2-005), não daqui.
## Valor de produção: content/data/physiology/medication_inhaler.tres.

@export var immediate_reduction: float = 0.35   ## redução ABSOLUTA da severidade, aplicada ao longo de reduction_time_s
@export var reduction_time_s: float = 3.0
@export var relief_strength: float = 0.7        ## alívio inicial; decai linearmente
@export var relief_duration_s: float = 90.0
@export var cooldown_s: float = 10.0
@export var noise_db: float = 38.0              ## ruído da bombinha (usado pela F2-005/F2-006b)
