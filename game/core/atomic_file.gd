class_name AtomicFile
extends RefCounted
## Escrita atômica de texto (L0), usada por SaveService e Settings.
##
## Escrita: grava `<path>.tmp`, relê e confere os bytes, move o arquivo atual para
## `<path>.bak` e renomeia o `.tmp` para `<path>`. Uma queda em qualquer ponto deixa
## pelo menos uma versão completa em disco.
## Leitura: usa o principal se for válido; senão o `.tmp` (escrita completa cuja troca
## não terminou); senão o `.bak` (versão anterior).

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

## Gancho de teste, válido só em build de debug: se >= 0, a próxima escrita grava apenas
## esse número de bytes no `.tmp` e falha, como uma queda no meio da gravação.
## Volta sozinho para -1 depois de usado.
static var simulate_failure_after_bytes: int = -1


class ReadResult:
	extends RefCounted
	var ok: bool = false
	var text: String = ""
	## "main", "tmp", "bak" ou "" se nada válido foi encontrado.
	var source: String = ""


static func write_text(path: String, text: String) -> Error:
	var base_dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		var mk: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if mk != OK:
			return mk
	var tmp_path: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if simulate_failure_after_bytes >= 0 and OS.is_debug_build():
		var cut: int = mini(simulate_failure_after_bytes, bytes.size())
		simulate_failure_after_bytes = -1
		f.store_buffer(bytes.slice(0, cut))
		f.close()
		return ERR_FILE_CANT_WRITE
	f.store_buffer(bytes)
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		return write_err
	if FileAccess.get_file_as_bytes(tmp_path) != bytes:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var bak_path: String = path + BAK_SUFFIX
		if FileAccess.file_exists(bak_path):
			var rm: Error = DirAccess.remove_absolute(bak_path)
			if rm != OK:
				return rm
		var mv: Error = DirAccess.rename_absolute(path, bak_path)
		if mv != OK:
			return mv
	return DirAccess.rename_absolute(tmp_path, path)


## `validator` recebe o texto e devolve bool. Sem validador, aceita qualquer texto não vazio.
static func read_text(path: String, validator: Callable = Callable()) -> ReadResult:
	var result: ReadResult = ReadResult.new()
	for candidate: Array in [[path, "main"], [path + TMP_SUFFIX, "tmp"], [path + BAK_SUFFIX, "bak"]]:
		var candidate_path: String = candidate[0]
		if not FileAccess.file_exists(candidate_path):
			continue
		var text: String = FileAccess.get_file_as_string(candidate_path)
		var valid: bool = not text.is_empty()
		if valid and validator.is_valid():
			valid = bool(validator.call(text))
		if valid:
			result.ok = true
			result.text = text
			result.source = candidate[1]
			return result
	return result


## Apaga o arquivo e as cópias `.tmp`/`.bak`. Útil para testes e para "novo jogo".
static func remove_all(path: String) -> void:
	for p: String in [path, path + TMP_SUFFIX, path + BAK_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
