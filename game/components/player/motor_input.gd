class_name MotorInput
extends RefCounted
## Comandos de um tick do PlayerMotor (COMPONENT_CONTRACTS §2, Complemento v1.0, congelado na F1-006).
## O motor amostra os dispositivos em step(). Testes e bots injetam este objeto com set_scripted_input().
## As bordas (crouch_pressed, crawl_pressed) são responsabilidade de quem injeta: verdadeiro só no tick do aperto.

## x = direita, y = frente; comprimento até 1 (o motor limita).
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var slow_walk: bool = false
## Borda: verdadeiro só no tick em que o comando foi acionado.
var crouch_pressed: bool = false
## Borda: verdadeiro só no tick em que o comando foi acionado.
var crawl_pressed: bool = false
## Pixels de mouse acumulados no tick.
var look_delta: Vector2 = Vector2.ZERO
