class_name CouplingFactors
extends RefCounted
## Fatores de acoplamento fisiologia → motor (L1, dados puros). DATA_STRUCTURES §1.
## Calculados pelo PhysiologyCoupling na F2. Na F1 o PlayerRoot usa `neutral()`.

var stamina_regen_multiplier: float = 1.0
var max_sprint_multiplier: float = 1.0
var sprint_allowed: bool = true
## 0..1 (1 = mãos firmes)
var steadiness: float = 1.0
## 0..1 (a apresentação escala pela acessibilidade)
var tremor_amplitude: float = 0.0


## Fatores sem efeito (multiplicadores 1, sprint permitido, mãos firmes, sem tremor).
static func neutral() -> CouplingFactors:
	return CouplingFactors.new()
