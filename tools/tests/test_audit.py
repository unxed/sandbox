import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audit"))
import audit  # noqa: E402

# A Pascal fragment of more than 60 tokens, half of them identifiers.
STATEMENTS = "".join("  v%d := w%d + x%d * y%d - z%d;\n" % (i, i, i, i, i) for i in range(10))
PASCAL = "begin\n" + STATEMENTS + "end.\n"
# A C fragment of 16 literals with many different significant values.
CPP = "int table[] = {" + ", ".join(str(100 + 37 * i) for i in range(16)) + "};\n"
COUNT = "int count[] = {" + ", ".join(str(1000 + i) for i in range(16)) + "};\n"


class Env:
    """A temporary repository and a temporary directory of corpora."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.join(self.tmp.name, "repo")
        self.corpora = os.path.join(self.tmp.name, "corpora")
        os.makedirs(self.repo)
        os.makedirs(self.corpora)
        self.git("init", "-q")
        self.refs = []
        self.allowed = []

    def close(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@example.com"] + list(args),
                       check=True, stdout=subprocess.PIPE)

    def commit(self, name, text, message="m"):
        full = os.path.join(self.repo, name)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)
        self.git("add", name)
        self.git("commit", "-q", "-m", message)

    def reference(self, rel, text):
        full = os.path.join(self.corpora, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)
        self.refs.append(rel)

    def allow(self, logical, rel, text):
        full = os.path.join(self.corpora, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)
        self.allowed.append((logical, rel))

    def run(self, extra=()):
        with open(os.path.join(self.corpora, "references.txt"), "w") as fh:
            fh.write("".join(r + "\n" for r in self.refs))
        with open(os.path.join(self.corpora, "allowed.txt"), "w") as fh:
            fh.write("".join("%s\t%s\n" % a for a in self.allowed))
        out = os.path.join(self.tmp.name, "audit.json")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = audit.main(["--corpora", self.corpora, "--repo", self.repo, "--out", out, "--workers", "2"]
                              + list(extra))
        with open(out) as fh:
            return code, json.load(fh), buf.getvalue()


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.env = Env()

    def tearDown(self):
        self.env.close()

    def kinds(self, report):
        return sorted(m["comparison"] for m in report["matches"])

    def test_clean_repository_passes(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("a.md", "Some unrelated text about views and windows.\n")
        code, report, out = self.env.run()
        self.assertEqual(code, 0)
        self.assertEqual(report["matches"], [])
        self.assertTrue(report["pass"])
        self.assertIn("AUDIT PASS", out)
        self.assertEqual(report["scope"], "history")
        self.assertEqual(report["corpora"], ["fake"])

    def test_no_references_fails(self):
        self.env.commit("a.md", "text\n")
        code, report, out = self.env.run()
        self.assertEqual(code, 1)
        self.assertIn("AUDIT FAIL", out)

    def test_raw_and_ren_matches(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", PASCAL)
        code, report, out = self.env.run()
        self.assertEqual(code, 1)
        self.assertEqual(self.kinds(report), ["raw", "ren"])
        for m in report["matches"]:
            self.assertEqual(m["path"], "u.pas")
            self.assertEqual(m["reference"], "fake/ref.pas")
            self.assertFalse(m["proved"])
        self.assertIn("AUDIT FAIL", out)

    def test_letter_case_and_layout_do_not_matter(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", "{ comment }\n" + PASCAL.upper().replace("\n", "\n\n"))
        code, report, _out = self.env.run()
        self.assertEqual(code, 1)
        self.assertIn("raw", self.kinds(report))

    def test_renamed_identifiers_match_only_in_ren(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", PASCAL.replace("v", "p").replace("w", "q").replace("x", "r"))
        _code, report, _out = self.env.run()
        self.assertEqual(self.kinds(report), ["ren"])

    def test_old_versions_are_audited(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", PASCAL)
        self.env.commit("u.pas", "begin end.\n")
        code, report, _out = self.env.run()
        self.assertEqual(code, 1)
        self.assertEqual(report["versions"], 2)

    def test_allowed_windows_do_not_count(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.allow("magiblot/tvision:source/x.pas", "allowed/x.pas", PASCAL)
        self.env.commit("u.pas", PASCAL)
        code, report, _out = self.env.run()
        self.assertEqual(code, 0)
        self.assertEqual(report["matches"], [])

    def test_literal_comparison(self):
        self.env.reference("fake/ref.cpp", CPP)
        self.env.commit("t.c", CPP.replace("table", "other"))
        code, report, _out = self.env.run()
        self.assertEqual(code, 1)
        self.assertEqual(self.kinds(report), ["lit"])
        self.assertEqual(report["matches"][0]["ntokens"], 16)

    def test_a_count_is_not_a_match(self):
        self.env.reference("fake/ref.cpp", COUNT)
        self.env.commit("t.c", COUNT)
        code, report, _out = self.env.run()
        self.assertEqual(code, 0)
        self.assertEqual(report["matches"], [])

    def test_short_chain_is_not_a_match(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", "begin\n  v1 := w1 + x1 * y1 - z1;\nend.\n")
        code, report, _out = self.env.run()
        self.assertEqual(code, 0)

    def test_repeated_heading_makes_no_chain(self):
        heading = "procedure Draw(var B: TBuf); virtual;\n"
        self.env.reference("fake/ref.pas", heading * 12)
        self.env.commit("u.pas", heading * 12)
        code, report, _out = self.env.run()
        self.assertEqual(code, 0)

    def test_proofs(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("u.pas", PASCAL)
        _code, report, _out = self.env.run()
        names = set()
        lines = []
        for m in report["matches"]:
            lines.append("\t".join([m["comparison"], m["id"], m["path"], "api"]))
            names.update(t[1] for t in m["tokens"] if t[0] == "i")
        # the names are not listed: the proofs do not hold
        proofs = os.path.join(self.env.repo, "tools/audit/proofs.txt")
        os.makedirs(os.path.dirname(proofs))
        with open(proofs, "w") as fh:
            fh.write("\n".join(lines) + "\n")
        code, report, out = self.env.run()
        self.assertEqual(code, 1)
        self.assertEqual(len(report["invalid_proofs"]), 2)
        # list the names and the proofs hold
        api = os.path.join(self.env.repo, "docs/API-NAMES.md")
        os.makedirs(os.path.dirname(api))
        with open(api, "w") as fh:
            fh.write(" ".join("`%s`" % n for n in sorted(names)) + "\n")
        code, report, out = self.env.run()
        self.assertEqual(code, 0, out)
        self.assertTrue(all(m["proved"] for m in report["matches"]))
        self.assertEqual(report["invalid_proofs"], [])

    def test_a_proof_without_a_match_is_invalid(self):
        self.env.reference("fake/ref.pas", PASCAL)
        self.env.commit("a.md", "text\n")
        proofs = os.path.join(self.env.repo, "tools/audit/proofs.txt")
        os.makedirs(os.path.dirname(proofs))
        with open(proofs, "w") as fh:
            fh.write("raw\t%s\ta.md\tapi\n" % ("0" * 64))
        code, report, _out = self.env.run()
        self.assertEqual(code, 1)
        self.assertEqual(len(report["invalid_proofs"]), 1)


class HelperTests(unittest.TestCase):
    def test_groups(self):
        self.assertEqual(audit.groups([1, 2, 3, 7, 9, 10]), [[1, 3], [7, 7], [9, 10]])
        self.assertEqual(audit.groups([]), [])


if __name__ == "__main__":
    unittest.main()
