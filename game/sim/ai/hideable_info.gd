class_name HideableInfo
extends RefCounted
## HideableInfo (L1, DATA_STRUCTURES §3; F4-003): um esconderijo visto pelo cérebro via BrainWorldQuery.hideables_near.
## Só identificação e posição do esconderijo. Não diz se o jogador está nele.

var persist_id: StringName = &""
var position: Vector3 = Vector3.ZERO


static func create(id: StringName, at: Vector3) -> HideableInfo:
	var info: HideableInfo = HideableInfo.new()
	info.persist_id = id
	info.position = at
	return info
