extends RefCounted

func unsafe(n: Node) -> void:
	var o: Object = n
	o.queue_free()
	print(o.name)
