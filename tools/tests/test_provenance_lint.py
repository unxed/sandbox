import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audit"))
import provenance_lint as P  # noqa: E402

TVISION = P.PINNED["magiblot/tvision"]
SHA = "0" * 63 + "1"


class Repo:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.git("init", "-q")

    def close(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", "-C", self.dir, "-c", "user.name=t", "-c", "user.email=t@example.com"]
                              + list(args), check=True, stdout=subprocess.PIPE).stdout.decode().strip()

    def write(self, name, text):
        full = os.path.join(self.dir, name)
        os.makedirs(os.path.dirname(full) or self.dir, exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)

    def commit(self, message="m"):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def blob(self, name):
        return self.git("hash-object", name)

    def record(self, path, **kw):
        rec = {
            "path": path,
            "kind": "specification",
            "sources": [{"specification": "s"}],
            "inputs": [{"origin": "specification:s", "sha256": SHA}],
            "implementer": "implementer 1",
            "proofs": [],
            "versions": [{"blob": self.blob(path), "commit": None, "pr": None, "audit_run": None}],
        }
        rec.update(kw)
        self.write("provenance/%s.json" % path, json.dumps(rec))
        return rec

    def index(self):
        P.run(self.dir, write_index=True)


class LintTests(unittest.TestCase):
    def setUp(self):
        self.r = Repo()
        self.r.write("a.md", "text\n")
        self.r.commit()

    def tearDown(self):
        self.r.close()

    def errors(self, history=False):
        return P.run(self.r.dir, history=history)

    def test_complete_repository(self):
        self.r.record("a.md")
        self.r.index()
        self.r.commit()
        rep = self.errors(history=True)
        self.assertEqual(rep["errors"], [])
        self.assertEqual(rep["missing_versions"], [])
        self.assertEqual(len(rep["pending_versions"]), 1)
        self.assertEqual(rep["commits"], 2)

    def test_file_without_record(self):
        self.r.index()
        rep = self.errors()
        self.assertTrue(any("a.md: no provenance record" in e for e in rep["errors"]))

    def test_missing_field(self):
        self.r.record("a.md")
        path = os.path.join(self.r.dir, "provenance/a.md.json")
        with open(path) as fh:
            rec = json.load(fh)
        del rec["inputs"]
        with open(path, "w") as fh:
            json.dump(rec, fh)
        self.r.index()
        self.assertTrue(any("inputs is missing" in e for e in self.errors()["errors"]))

    def test_bad_kind_and_origin(self):
        self.r.record("a.md", kind="invented")
        self.r.index()
        self.assertTrue(any("kind" in e for e in self.errors()["errors"]))
        self.r.record("a.md", inputs=[{"origin": "https://example.org/x", "sha256": SHA}])
        self.r.index()
        self.assertTrue(any("origin not allowed" in e for e in self.errors()["errors"]))

    def test_kind_new_takes_no_outside_source(self):
        self.r.record("a.md", kind="new", sources=[],
                      inputs=[{"origin": "magiblot/tvision@%s:source/x.cpp" % TVISION, "sha256": SHA}])
        self.r.index()
        self.assertTrue(any("kind new" in e for e in self.errors()["errors"]))
        self.r.record("a.md", kind="new", sources=[], inputs=[{"origin": "repository:CLAUDE.md", "sha256": SHA}])
        self.r.index()
        self.assertEqual(self.errors()["errors"], [])

    def test_unpinned_commit(self):
        self.r.record("a.md", kind="translation",
                      sources=[{"source": "magiblot/tvision", "commit": "1" * 40, "file": "x", "lines": "1-2"}])
        self.r.index()
        self.assertTrue(any("pinned" in e for e in self.errors()["errors"]))

    def test_translated_pascal_file_needs_its_notice(self):
        self.r.write("u.pas", "unit u;\ninterface\nimplementation\nend.\n")
        self.r.commit()
        src = {"source": "magiblot/tvision", "commit": TVISION, "file": "source/x.cpp", "lines": "1-9"}
        inputs = [{"origin": "magiblot/tvision@%s:source/x.cpp" % TVISION, "sha256": SHA}]
        self.r.record("a.md")
        self.r.record("u.pas", kind="translation", sources=[src], inputs=inputs)
        self.r.index()
        self.assertTrue(any("no notice" in e for e in self.errors()["errors"]))
        self.r.write("u.pas", "{ Translated from magiblot/tvision @ b4831e2\n  see COPYRIGHT.magiblot }\nunit u;\n")
        self.r.commit()
        self.r.record("u.pas", kind="translation", sources=[src], inputs=inputs)
        self.r.index()
        self.assertEqual(self.errors()["errors"], [])

    def test_notice_in_a_file_of_another_kind(self):
        self.r.write("u.pas", "{ Translated from magiblot/tvision @ b4831e2 }\n")
        self.r.commit()
        self.r.record("a.md")
        self.r.record("u.pas")
        self.r.index()
        self.assertTrue(any("carries a translation notice" in e for e in self.errors()["errors"]))

    def test_verbatim_must_equal_the_source_blob(self):
        src = {"source": "magiblot/tvision", "commit": TVISION, "file": "COPYRIGHT", "blob": "2" * 40}
        inputs = [{"origin": "magiblot/tvision@%s:COPYRIGHT" % TVISION, "sha256": SHA}]
        self.r.record("a.md", kind="verbatim", sources=[src], inputs=inputs)
        self.r.index()
        self.assertTrue(any("source" in e for e in self.errors()["errors"]))
        src["blob"] = self.r.blob("a.md")
        self.r.record("a.md", kind="verbatim", sources=[src], inputs=inputs)
        self.r.index()
        self.assertEqual(self.errors()["errors"], [])

    def test_named_commit_holds_the_blob(self):
        head = self.r.git("rev-parse", "HEAD")
        rec = self.r.record("a.md")
        rec["versions"][0]["commit"] = head
        rec["versions"][0]["pr"] = "https://example.org/pr/1"
        rec["versions"][0]["audit_run"] = "https://example.org/run/1"
        self.r.write("provenance/a.md.json", json.dumps(rec))
        self.r.index()
        rep = self.errors()
        self.assertEqual(rep["errors"], [])
        self.assertEqual(rep["pending_versions"], [])
        rec["versions"][0]["commit"] = "3" * 40
        self.r.write("provenance/a.md.json", json.dumps(rec))
        self.assertTrue(any("does not hold" in e for e in self.errors()["errors"]))

    def test_current_version_must_be_listed(self):
        self.r.record("a.md", versions=[{"blob": "4" * 40, "commit": None, "pr": None, "audit_run": None}])
        self.r.index()
        self.assertTrue(any("current version" in e for e in self.errors()["errors"]))

    def test_history_lists_every_version(self):
        self.r.record("a.md")
        first = self.r.blob("a.md")
        self.r.index()
        self.r.write("a.md", "changed\n")
        self.r.commit()
        self.r.record("a.md", versions=[{"blob": self.r.blob("a.md"), "commit": None, "pr": None, "audit_run": None}])
        self.r.index()
        rep = self.errors(history=True)
        self.assertEqual(rep["errors"], [])
        self.assertEqual(len(rep["missing_versions"]), 1)
        self.assertIn(first, rep["missing_versions"][0])
        self.assertEqual(self.errors(history=False)["missing_versions"], [])

    def test_stale_index(self):
        self.r.record("a.md")
        self.assertTrue(any("INDEX" in e for e in self.errors()["errors"]))
        self.r.index()
        self.assertEqual(self.errors()["errors"], [])

    def test_proofs_agree_with_proofs_file(self):
        self.r.record("a.md", proofs=["5" * 64])
        self.r.index()
        self.assertTrue(any("proofs differ" in e for e in self.errors()["errors"]))
        self.r.write("tools/audit/proofs.txt", "raw\t%s\ta.md\tapi\n" % ("5" * 64))
        self.assertEqual(self.errors()["errors"], [])

    def test_index_format(self):
        self.r.record("a.md")
        self.r.index()
        with open(os.path.join(self.r.dir, "provenance/INDEX.md")) as fh:
            lines = fh.read().splitlines()
        self.assertEqual(lines[0], "# Provenance index")
        self.assertEqual(lines[4], "| `a.md` | specification | specification:s | 1 | 1 | 0 |")

    def test_exempt_files(self):
        self.assertTrue(P.exempt("provenance/INDEX.md"))
        self.assertTrue(P.exempt("VERDICT.md"))
        self.assertFalse(P.exempt("README.md"))


if __name__ == "__main__":
    unittest.main()
