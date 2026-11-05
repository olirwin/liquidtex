#!/usr/bin/env python3
"""Behavioral integration tests; all generated files stay in a temporary tree."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Integration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="liquidtex-tests-")
        cls.base = Path(cls.temp.name)
        cls.source = cls.base / "package"
        cls.source.mkdir()
        shutil.copy2(ROOT / "liquidtex.dtx", cls.source)
        shutil.copytree(ROOT / "utils", cls.source / "utils", ignore=shutil.ignore_patterns("auto"))
        shutil.copytree(ROOT / "scripts", cls.source / "scripts", ignore=shutil.ignore_patterns("__pycache__", "*.sh"))
        subprocess.run(["tex", "-interaction=nonstopmode", "liquidtex.dtx"], cwd=cls.source,
                       stdout=subprocess.DEVNULL, check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.work = self.base / self.id().split(".")[-1]
        self.work.mkdir()
        self.env = os.environ.copy()
        self.env["TEXINPUTS"] = str(self.source) + "//:" + self.env.get("TEXINPUTS", "")
        self.write("person.json", '{"name":"Alice","active":true,"items":["One","Two"]}')
        self.write("hello.liquid", "Hello {{ name }}.\n")

    def write(self, name, content):
        target = self.work / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        return target

    def document(self, body, options="engine=lua,data=person.json", preamble=""):
        return self.write("case.tex", "\\documentclass{article}\n\\usepackage[" + options + "]{liquidtex}\n"
                          + preamble + "\n\\begin{document}\n" + body + "\n\\end{document}\n")

    def compile(self, engine="lualatex", shell=False, success=True, extra=()):
        args = [engine, "-shell-escape" if shell else "-no-shell-escape", "-halt-on-error",
                "-interaction=nonstopmode", *extra, "case.tex"]
        result = subprocess.run(args, cwd=self.work, env=self.env, capture_output=True, text=True, timeout=45)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout[-7000:] + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout + result.stderr

    def pdf(self, name="case.pdf"):
        return subprocess.check_output(["pdftotext", "-layout", name, "-"], cwd=self.work, text=True)

    def cli(self, *args, success=True):
        result = subprocess.run(["texlua", str(self.source / "scripts/liquidtex.lua"), *args],
                                cwd=self.work, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_repository_examples(self):
        shutil.copytree(ROOT / "data", self.work / "data")
        shutil.copytree(ROOT / "templates", self.work / "templates")
        for name, shell in [("test.tex", True), ("test-lua.tex", False)]:
            with self.subTest(example=name):
                self.write("case.tex", (ROOT / name).read_text())
                self.compile(shell=shell)
                self.assertTrue((self.work / "case.pdf").stat().st_size > 0)

    def test_native_cache_and_invalidation(self):
        self.document(r"\inputliquid{hello.liquid}\inputliquid{hello.liquid}",
                      "engine=lua,data=person.json,diagnostics")
        first = self.compile()
        self.assertIn("cache-hits=1", first)
        self.assertEqual(self.pdf().count("Hello Alice."), 2)
        warm = self.compile()
        self.assertIn("cache-hits=2", warm)
        self.assertNotIn("Liquid output changed", warm)
        previous = (self.work / "person.json").stat()
        self.write("person.json", '{"name":"Bobby"}')
        os.utime(self.work / "person.json", ns=(previous.st_atime_ns, previous.st_mtime_ns))
        changed = self.compile()
        self.assertIn("cache-hits=1", changed)
        self.assertIn("Liquid output changed", changed)
        self.assertEqual(self.pdf().count("Hello Bobby."), 2)

    def test_no_cache_both_backends(self):
        for backend in ("lua", "external"):
            with self.subTest(backend=backend):
                self.document(r"\inputliquid{hello.liquid}\inputliquid{hello.liquid}",
                              f"engine={backend},data=person.json,no-cache,diagnostics")
                result = self.compile(shell=backend == "external")
                self.assertIn("cache-hits=0", result)
                self.assertEqual(self.pdf().count("Hello Alice."), 2)

    def test_external_pdftex_and_lua_parity(self):
        self.write("loop.liquid", "{{ name | upcase }}\n{% if active %}Enabled{% endif %}\n"
                   "{% for item in items %}{{ item | append: '!' }} {% endfor %}")
        self.document(r"\inputliquid{loop.liquid}", "engine=lua,data=person.json")
        self.compile()
        native = self.pdf()
        self.document(r"\inputliquid{loop.liquid}", "engine=external,data=person.json")
        self.compile(engine="pdflatex", shell=True)
        external = self.pdf()
        for token in ("ALICE", "Enabled", "One!", "Two!"):
            self.assertIn(token, native)
            self.assertIn(token, external)

    def test_verbatim_inline_and_default_alias(self):
        self.document(r"""
\inputliquid{hello.liquid}
\inputliquid[extra]{hello.liquid}
\begin{liquiddata}{local}
name: Inline
items: [First, Second]
\end{liquiddata}
\begin{liquid}[local]
{% if name %}\textbf{ {{- name -}} }{% endif %}
{% for item in items %}{{ item }} {% endfor %}
\end{liquid}
Inside text: \liquidinline[local]{ {{ name | upcase }} }.
\begin{liquiddata}
name: DefaultInline
\end{liquiddata}
\inputliquid{hello.liquid}
\begin{liquid}
{{ name }}
\end{liquid}
""", preamble=r"\liquidsetup{data-sources={extra=extra.json}}")
        self.write("extra.json", '{"name":"Extra"}')
        self.compile()
        output = self.pdf()
        for token in ("Alice", "Extra", "Inline", "First", "Second", "INLINE", "DefaultInline"):
            self.assertIn(token, output)

    def test_template_paths_namespaces_and_merge(self):
        self.write("first/shared.liquid", "FIRST {{ profile.city }} {{ profile.name }} {{ pub.title }} {{ selected }}")
        self.write("second/shared.liquid", "WRONG")
        self.write("base.json", '{"profile":{"name":"Base","city":"Paris"},"selected":"base"}')
        self.write("overlay.yml", "profile:\n  name: Overlay\n")
        self.write("pub.json", '{"title":"Paper"}')
        self.write("person.json", '{"selected":"local"}')
        self.document(r"\inputliquid{shared.liquid}",
                      "engine=lua,data=person.json,data-files={base.json,overlay.yml},data.pub=pub.json,"
                      "template-path={first/,second/}")
        self.compile()
        self.assertIn("FIRST Paris Overlay Paper local", self.pdf())

    def test_distinct_paths_and_debug_star(self):
        self.write("a/shared.liquid", "AAA {{ name }}")
        self.write("b/shared.liquid", "BBB {{ name }}")
        self.document(r"\inputliquid{a/shared.liquid}\inputliquid{b/shared.liquid}"
                      r"\inputliquid*{hello.liquid}",
                      "engine=lua,data=person.json,debug-dir=debug")
        log = self.compile()
        self.assertIn("liquidtex: Hello Alice.", log)
        self.assertNotIn("Hello Alice.", self.pdf())
        self.assertIn("AAA Alice", self.pdf())
        self.assertIn("BBB Alice", self.pdf())
        self.assertEqual(len(list((self.work / "debug").glob("*.data.json"))), 3)

    def test_validation_and_lua_errors(self):
        self.document(r"\liquidvalidate{hello.liquid}Validated.")
        self.compile()
        self.assertNotIn("Hello", self.pdf())
        for template, message in (("Line one\n{% if active %}", "unclosed block"),
                                  ("Line one\n{{ name | nonexistent }}", "unknown filter")):
            with self.subTest(message=message):
                self.write("bad.liquid", template)
                self.document(r"\inputliquid{bad.liquid}")
                log = self.compile(success=False)
                self.assertIn(message, log)
                self.assertIn("bad.liquid", log)
                self.assertIn("line", log)
                self.assertIn("stack traceback", log)

    def test_custom_filter_and_lists(self):
        self.write("rows.json", '[{"name":"One"},{"name":"Two"}]')
        self.write("row.liquid", r"\item {{ item.name | shout }}" + "\n")
        self.document(r"\begin{itemize}\liquidlist{rows.json}{row.liquid}\end{itemize}",
                      preamble=r'\liquidfilter{shout}{function(value) return string.upper(value) .. "!" end}')
        self.compile()
        self.assertIn("ONE!", self.pdf())
        self.assertIn("TWO!", self.pdf())
        self.document(r"\liquidlist{person.json}{row.liquid}")
        self.assertIn("expected an array", self.compile(success=False))
        self.write("rows.json", "[]")
        self.document(r"Empty rows: \liquidlist{rows.json}{row.liquid}")
        self.compile()
        self.write("rows.json", "{}")
        self.assertIn("expected an array", self.compile(success=False))

    def test_custom_renderer_quoting_indices_and_failures(self):
        script = self.write("renderer's directory/renderer.py", """import json, pathlib, sys
args=sys.argv[1:]
if args[0].startswith('--'):
    values=dict(arg[2:].split('=',1) for arg in args)
    template,data,output=values['template'],values['data'],values['output']
else:
    data,output,template=args
pathlib.Path(output).write_text('EXTERNAL '+json.loads(pathlib.Path(data).read_text())['name'])
if pathlib.Path('fail-engine').exists():
    print('deliberate external failure',file=sys.stderr)
    sys.exit(7)
""")
        for named in (False, True):
            with self.subTest(named=named):
                conf = ("named" if named else "data-index=1,output-index=2,template-index=3")
                self.document(r"\inputliquid{hello.liquid}", "engine=external,data=person.json,"
                              f"engine-conf={{path={shutil.which('python3')},arguments={{{script}}},{conf}}}")
                self.compile(engine="pdflatex", shell=True)
                self.assertIn("EXTERNAL Alice", self.pdf())
        # Existing successful cache plus forced rebuild writing output then failing.
        self.write("fail-engine", "yes")
        self.document(r"\inputliquid{hello.liquid}", "engine=external,data=person.json,no-cache,"
                      f"engine-conf={{path={shutil.which('python3')},arguments={{{script}}},named}}")
        failure = self.compile(engine="pdflatex", shell=True, success=False)
        self.assertIn("deliberate external failure", failure)
        self.assertIn("exit 7", failure)

    def test_auxiliary_output_directory(self):
        (self.work / "aux").mkdir()
        self.document(r"\inputliquid{hello.liquid}")
        self.compile(extra=("-output-directory=aux",))
        self.assertTrue((self.work / "aux/liquidtex-cache").is_dir())
        self.assertFalse((self.work / "liquidtex-cache").exists())
        self.assertIn("Hello Alice.", self.pdf("aux/case.pdf"))

    def test_latexmk_tracks_data_dependencies(self):
        self.document(r"\inputliquid{hello.liquid}")
        args = ["latexmk", "-lualatex", "-latexoption=-no-shell-escape", "-halt-on-error", "-interaction=nonstopmode", "case.tex"]
        first = subprocess.run(args, cwd=self.work, env=self.env, capture_output=True, text=True, timeout=45)
        self.assertEqual(first.returncode, 0, first.stdout[-6000:] + first.stderr)
        self.assertIn("person.json", (self.work / "case.fls").read_text())
        self.write("person.json", '{"name":"DataOnlyChanged"}')
        second = subprocess.run(args, cwd=self.work, env=self.env, capture_output=True, text=True, timeout=45)
        self.assertEqual(second.returncode, 0, second.stdout[-6000:] + second.stderr)
        self.assertIn("DataOnlyChanged", self.pdf())

    def test_templated_section_and_toc(self):
        self.write("section.liquid", "Long {{ name }}\nBody for {{ name }}.\n")
        self.document(r"\tableofcontents\sectionliquid[Short title]{section.liquid}")
        self.compile()
        self.compile()
        self.assertIn("Long Alice", self.pdf())
        self.assertIn("Body for Alice.", self.pdf())
        self.assertIn("Short title", (self.work / "case.toc").read_text())

    def test_filter_syntax_and_whitespace(self):
        self.write("syntax.liquid", 'Hello {{- name -}}! {{ name | replace_first: "A", "E" }}')
        self.assertIn("HelloAlice!Elice", self.cli("render", "--template", "syntax.liquid", "--data", "person.json").replace(" ", ""))
        for value in ('{{ name | }}', '{{ name | replace: }}', '{% if name == %}x{% endif %}'):
            self.write("invalid.liquid", value)
            self.cli("validate", "--template", "invalid.liquid", success=False)

    def test_cli_and_pipeline_dependencies(self):
        rendered = self.cli("render", "--template", "hello.liquid", "--data", "person.json")
        self.assertIn("Hello Alice.", rendered)
        self.assertIn("Valid:", self.cli("validate", "--template", "hello.liquid"))
        self.write("bad.liquid", "{% if active %}")
        self.assertIn("unclosed block", self.cli("validate", "--template", "bad.liquid", success=False))
        self.assertEqual(json.loads(self.cli("inspect", "--data", "person.json"))["name"], "Alice")
        self.write("other.json", '{"name":"Other"}')
        self.write("pipeline.json", json.dumps({"outputs": [
            {"template": "hello.liquid", "data": "person.json", "output": "out/a.tex"},
            {"template": "hello.liquid", "data": "other.json", "output": "out/b.tex"}]}))
        self.assertEqual(self.cli("pipeline", "pipeline.json").count(": rendered"), 2)
        self.assertEqual(self.cli("pipeline", "pipeline.json").count(": cached"), 2)
        self.write("person.json", '{"name":"Changed"}')
        rerun = self.cli("pipeline", "pipeline.json")
        self.assertIn("out/a.tex: rendered", rerun)
        self.assertIn("out/b.tex: cached", rerun)
        self.assertIn("Changed", (self.work / "out/a.tex").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
