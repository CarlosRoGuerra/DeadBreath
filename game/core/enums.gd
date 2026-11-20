class_name Enums
extends RefCounted
## Enums compartilhados (L0). Fonte: DATA_STRUCTURES §0.
## VOICE depende da proposta P-03 (aprovação prevista na F3).

enum Stance { STAND, CROUCH, CRAWL }
enum Gait { IDLE, SLOW, WALK, SPRINT }
enum RespiratoryState { NORMAL, ACCELERATED, LABORED, SYMPTOMATIC, RECOVERING }
enum StressBand { CALM, TENSE, AFRAID, PANIC }
enum NoiseCategory { FOOTSTEP, RUNNING, BREATHING, WHEEZING, COUGHING, DOOR, OBJECT_IMPACT, MEDICATION, FURNITURE, FALL, VOICE }
enum EnemyState { PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, LOST_CONTACT, RETURN }
enum ObjectiveStatus { LOCKED, ACTIVE, COMPLETED, FAILED }
