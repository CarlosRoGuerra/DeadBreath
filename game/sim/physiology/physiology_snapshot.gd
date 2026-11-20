class_name PhysiologySnapshot
extends RefCounted
## PhysiologySnapshot (L1, DATA_STRUCTURES §1): leitura da fisiologia depois de um tick. Só leitura para quem consome.
## to_dict() permite comparar dois snapshots campo a campo (PHY-08, PER-07).

var stamina: float = 100.0
var stress: float = 0.0
var stress_band: Enums.StressBand = Enums.StressBand.CALM
var symptom_severity: float = 0.0
var breathing_rate: float = 14.0
var wheezing_intensity: float = 0.0
## Risco por segundo (hazard) de tosse involuntária.
var cough_probability: float = 0.0
var recovery_progress: float = 1.0
var respiratory_state: Enums.RespiratoryState = Enums.RespiratoryState.NORMAL
## Fonte de verdade: o inventário (F2-005). O PlayerRoot informa o valor pelo PhysiologyComponent.
var medication_charges: int = 0
## Segundos restantes do alívio da bombinha.
var medication_relief_remaining: float = 0.0


func to_dict() -> Dictionary:
	return {
		"stamina": stamina,
		"stress": stress,
		"stress_band": int(stress_band),
		"symptom_severity": symptom_severity,
		"breathing_rate": breathing_rate,
		"wheezing_intensity": wheezing_intensity,
		"cough_probability": cough_probability,
		"recovery_progress": recovery_progress,
		"respiratory_state": int(respiratory_state),
		"medication_charges": medication_charges,
		"medication_relief_remaining": medication_relief_remaining,
	}
