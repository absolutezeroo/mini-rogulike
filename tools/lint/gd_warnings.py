#!/usr/bin/env python3
"""Lists the GDScript warnings (and errors) the Godot editor would show, and fails if there are any.

The editor's warnings (shadowed names, integer division, unused signals, redundant awaits...) only
show up in the editor's Output/Debugger panels, never in the headless tests. This tool starts a
headless editor with its GDScript language server, opens every script of src/, tests/ and tools/
in it, and collects what the server reports for each one: exactly the editor's diagnostics, with
the project's own warning settings (project.godot, debug/gdscript/warnings/*).

The project is kept at zero warnings (AGENTS.md "Done means"): fix a warning rather than silence
it, and when an @warning_ignore is the right answer, give the reason in a comment beside it.

Usage (from anywhere, python3, standard library only):
  python3 tools/lint/gd_warnings.py                  # prints the warnings, exit 1 if any
  python3 tools/lint/gd_warnings.py --json out.json  # also writes them as JSON
Options:
  --godot PATH  the Godot 4.7 binary (default: $GODOT, then `godot` on the PATH, then
                Godot_v4.7-stable_linux.x86_64 in the repo root, _tool/ or /tmp)
  --port N      the language server's port (default: a free one)
  --timeout S   how long to wait for the server's answers (default 180 s)

Needs an imported project (.godot/ present: `godot --headless --import` first). The editor is
started with --headless and stopped by its own process id when the tool ends; the files it may
save on its own (default_bus_layout.tres, re-saved at every start; project.godot; the roadmap
board) are put back as they were. Android's build template (android/build/, which carries its own
.gdignore) and addons/ are not ours and are not scanned.
"""

import argparse
import glob
import json
import os
import shutil
import socket
import subprocess
import sys
import time

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCANNED = ("src", "tests", "tools")
SEVERITY = {1: "ERROR", 2: "WARNING", 3: "INFO", 4: "HINT"}


def find_godot(given):
	"""The Godot binary to run: the option, $GODOT, `godot` on the PATH, or a downloaded one."""
	candidates = [given, os.environ.get("GODOT"), shutil.which("godot")]
	for folder in (ROOT, os.path.join(ROOT, "_tool"), "/tmp"):
		candidates.append(os.path.join(folder, "Godot_v4.7-stable_linux.x86_64"))
	for path in candidates:
		if path and os.path.isfile(path) and os.access(path, os.X_OK):
			return path
	sys.exit("gd_warnings: no Godot binary found (use --godot or $GODOT; docs/testing.md)")


def snapshot():
	"""The files an editor may save on its own (the bus layout it re-saves on start, project
	settings, the roadmap board its plugin holds): put back as they were afterwards."""
	paths = glob.glob(os.path.join(ROOT, "*.tres")) + [os.path.join(ROOT, "project.godot")]
	paths += glob.glob(os.path.join(ROOT, "godoban_boards", "*.json"))
	kept = {}
	for path in paths:
		with open(path, "rb") as handle:
			kept[path] = handle.read()
	return kept


def restore(kept):
	for path, data in kept.items():
		with open(path, "rb") as handle:
			now = handle.read()
		if now != data:
			with open(path, "wb") as handle:
				handle.write(data)


def free_port():
	with socket.socket() as probe:
		probe.bind(("127.0.0.1", 0))
		return probe.getsockname()[1]


class Lsp:
	"""A minimal JSON-RPC client over the language server's TCP socket."""

	def __init__(self, port, wait):
		self.sock = None
		end = time.time() + wait
		while time.time() < end:
			try:
				self.sock = socket.create_connection(("127.0.0.1", port))
				break
			except OSError:
				time.sleep(1)
		if self.sock is None:
			raise RuntimeError("the editor's language server never answered on port %d" % port)
		self.sock.settimeout(0.5)
		self.buf = b""

	def send(self, obj):
		data = json.dumps(obj).encode()
		self.sock.sendall(b"Content-Length: %d\r\n\r\n" % len(data) + data)

	def read(self, wait):
		"""Every message received during `wait` seconds."""
		msgs = []
		end = time.time() + wait
		while time.time() < end:
			try:
				chunk = self.sock.recv(1 << 20)
				if not chunk:
					break
				self.buf += chunk
			except socket.timeout:
				pass
			while b"\r\n\r\n" in self.buf:
				head, rest = self.buf.split(b"\r\n\r\n", 1)
				lengths = [l for l in head.split(b"\r\n") if l.lower().startswith(b"content-length")]
				size = int(lengths[0].split(b":")[1])
				if len(rest) < size:
					break
				msgs.append(json.loads(rest[:size]))
				self.buf = rest[size:]
		return msgs


def scripts():
	"""Our scripts: every .gd under src/, tests/ and tools/."""
	found = []
	for folder in SCANNED:
		found += glob.glob(os.path.join(ROOT, folder, "**", "*.gd"), recursive=True)
	return sorted(found)


def collect(port, timeout):
	"""{relative path: [diagnostic]} for every script, from the language server."""
	lsp = Lsp(port, timeout)
	uri_root = "file://" + ROOT
	lsp.send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
		"params": {"processId": None, "rootUri": uri_root, "capabilities": {}}})
	lsp.read(3)
	lsp.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
	files = scripts()
	pending = {"file://" + f for f in files}
	found = {}

	def take(msgs):
		for msg in msgs:
			if msg.get("method") == "textDocument/publishDiagnostics":
				uri = msg["params"]["uri"]
				found[uri] = msg["params"]["diagnostics"]
				pending.discard(uri)

	for i, path in enumerate(files):
		with open(path, encoding="utf-8") as handle:
			text = handle.read()
		lsp.send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
			"uri": "file://" + path, "languageId": "gdscript", "version": 1, "text": text}}})
		if i % 20 == 19:
			take(lsp.read(1.0))
	end = time.time() + timeout
	while pending and time.time() < end:
		take(lsp.read(2.0))
	take(lsp.read(2.0))
	if pending:
		print("gd_warnings: no answer for %d scripts, e.g. %s" % (len(pending), sorted(pending)[0]))
	rows = []
	for uri, diags in found.items():
		for diag in diags:
			rows.append({"file": uri.replace(uri_root + "/", ""), "line": diag["range"]["start"]["line"] + 1,
				"severity": SEVERITY.get(diag.get("severity"), "?"), "message": diag["message"]})
	rows.sort(key=lambda r: (r["file"], r["line"]))
	return rows, len(files), len(pending)


def main():
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--godot")
	parser.add_argument("--port", type=int)
	parser.add_argument("--timeout", type=float, default=180.0)
	parser.add_argument("--json")
	args = parser.parse_args()
	if not os.path.isdir(os.path.join(ROOT, ".godot")):
		sys.exit("gd_warnings: the project is not imported yet (godot --headless --import)")
	godot = find_godot(args.godot)
	port = args.port or free_port()
	kept = snapshot()
	editor = subprocess.Popen([godot, "--headless", "--editor", "--path", ROOT, "--lsp-port", str(port)],
		stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	try:
		rows, count, missing = collect(port, args.timeout)
	finally:
		editor.terminate()
		try:
			editor.wait(timeout=20)
		except subprocess.TimeoutExpired:
			editor.kill()
		restore(kept)
	for row in rows:
		print("%s:%d: %s %s" % (row["file"], row["line"], row["severity"], row["message"]))
	if args.json:
		with open(args.json, "w", encoding="utf-8") as handle:
			json.dump(rows, handle, indent=1)
	print("gd_warnings: %d scripts, %d diagnostics" % (count, len(rows)))
	return 1 if rows or missing else 0


if __name__ == "__main__":
	sys.exit(main())
