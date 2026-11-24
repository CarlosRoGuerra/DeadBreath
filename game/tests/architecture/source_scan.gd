class_name SourceScan
extends RefCounted
## Varredura de texto dos scripts para os testes de arquitetura (F1-005).
## Só lê arquivos (FileAccess/DirAccess); não depende de cena nem de autoload.


## Listas já feitas neste processo, por raiz (Director, F4: listar o projeto custava ~0,44 s por varredura, e várias
## varreduras rodam na mesma execução). Os scripts do jogo não mudam durante uma execução de testes.
static var _list_cache: Dictionary = {}


## Todos os .gd sob root, em ordem. Ignora pastas ocultas (ex.: .godot).
static func list_gd_files(root: String) -> PackedStringArray:
	if _list_cache.has(root):
		return _list_cache[root]
	var out: PackedStringArray = PackedStringArray()
	_collect(root, out)
	out.sort()
	_list_cache[root] = out
	return out


## Texto do script; "" se o arquivo não existir.
static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Nomes dos autoloads registrados em project.godot (seção [autoload]).
static func autoload_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for prop: Dictionary in ProjectSettings.get_property_list():
		var prop_name: String = str(prop.get("name", ""))
		if prop_name.begins_with("autoload/"):
			names.append(prop_name.trim_prefix("autoload/"))
	return names


## Código sem comentários. Com blank_strings = true, o conteúdo das strings vira espaços,
## para que identificadores e caminhos dentro de strings não contem como código.
## Quebras de linha são preservadas, então o número da linha continua válido.
static func code_of(src: String, blank_strings: bool) -> String:
	var out: String = ""
	var i: int = 0
	var n: int = src.length()
	while i < n:
		var c: String = src[i]
		if c == "#":
			while i < n and src[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			var delim: String = c
			if src.substr(i, 3) == c + c + c:
				delim = c + c + c
			out += delim
			i += delim.length()
			while i < n and src.substr(i, delim.length()) != delim:
				var piece: String = src[i]
				if piece == "\\" and i + 1 < n:
					piece += src[i + 1]
				i += piece.length()
				out += _blank(piece) if blank_strings else piece
			if i < n:
				out += delim
				i += delim.length()
			continue
		out += c
		i += 1
	return out


## Ocorrências de pattern (regex) em text, como "linha N: trecho".
static func find_all(text: String, pattern: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		found.append("regex invalida: " + pattern)
		return found
	for match_item: RegExMatch in regex.search_all(text):
		var line: int = text.substr(0, match_item.get_start()).count("\n") + 1
		found.append("linha %d: %s" % [line, match_item.get_string().strip_edges()])
	return found


## Nomes declarados com "class_name" (linha iniciando por class_name), a partir do código sem comentários.
static func class_names_declared(code: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	regex.compile("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for match_item: RegExMatch in regex.search_all(code):
		names.append(match_item.get_string(1))
	return names


static func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var entries: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for item: String in entries:
		if item.begins_with("."):
			continue
		var child: String = dir_path.path_join(item)
		if DirAccess.dir_exists_absolute(child):
			_collect(child, out)
		elif item.ends_with(".gd"):
			out.append(child)


static func _blank(piece: String) -> String:
	var out: String = ""
	for k: int in piece.length():
		out += "\n" if piece[k] == "\n" else " "
	return out
