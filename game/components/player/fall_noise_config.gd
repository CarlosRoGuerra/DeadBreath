class_name FallNoiseConfig
extends Resource
## FallNoiseConfig (L2, F3-004): velocidade mínima de aterrissagem que faz ruído de queda (FALL, fall_body, 80 dB).
## Escada e degrau ficam abaixo disto (aterrissagem suave); queda de mezanino passa. Valor em m/s (velocidade de impacto).

@export var min_fall_speed_mps: float = 2.5
