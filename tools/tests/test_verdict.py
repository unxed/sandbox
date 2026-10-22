import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audit"))
import verdict  # noqa: E402

HEAD = "a" * 40


def audit(**kw):
    r = {"head": HEAD, "scope": "history", "profile": dict(verdict.PROFILE), "corpora": list(verdict.CORPORA),
         "references": 10, "matches": [], "invalid_proofs": [], "commits": 3, "pass": True}
    r.update(kw)
    return r


def prov(**kw):
    r = {"head": HEAD, "history": True, "commits": 3, "errors": [], "missing_versions": [],
         "pending_versions": []}
    r.update(kw)
    return r


def text(**kw):
    r = {"head": HEAD, "commits": 3, "findings": [], "pass": True}
    r.update(kw)
    return r


class JudgeTests(unittest.TestCase):
    def test_everything_holds(self):
        self.assertEqual(verdict.judge(audit(), prov(), text()), [])

    def test_unproved_match(self):
        m = {"comparison": "raw", "path": "u.pas", "id": "x", "lines": [3, 9], "proved": False}
        items = verdict.judge(audit(matches=[m], **{"pass": False}), prov(), text())
        self.assertEqual(len(items), 1)
        self.assertIn("u.pas", items[0])

    def test_proved_match_is_fine(self):
        m = {"comparison": "raw", "path": "u.pas", "id": "x", "lines": [3, 9], "proved": True}
        self.assertEqual(verdict.judge(audit(matches=[m]), prov(), text()), [])

    def test_invalid_proof(self):
        items = verdict.judge(audit(invalid_proofs=[{"line": "p:1", "reason": "r"}], **{"pass": False}), prov(), text())
        self.assertTrue(any("invalid proof" in i for i in items))

    def test_missing_corpus_and_profile(self):
        items = verdict.judge(audit(corpora=["far2l"], profile={"raw": 8}), prov(), text())
        self.assertTrue(any("profile" in i for i in items))
        self.assertTrue(any("corpus fpc322" in i for i in items))

    def test_scope(self):
        self.assertTrue(verdict.judge(audit(scope="head"), prov(), text()))

    def test_provenance_items(self):
        items = verdict.judge(audit(), prov(errors=["e1"], missing_versions=["m1"], pending_versions=["p1"]), text())
        self.assertEqual(len(items), 3)

    def test_provenance_without_history(self):
        self.assertTrue(verdict.judge(audit(), prov(history=False), text()))

    def test_text_findings(self):
        f = {"where": "a.md", "rule": "neutral", "detail": "w"}
        items = verdict.judge(audit(), prov(), text(findings=[f], **{"pass": False}))
        self.assertEqual(len(items), 1)

    def test_text_without_commits(self):
        self.assertTrue(verdict.judge(audit(), prov(), text(commits=0)))

    def test_different_heads(self):
        self.assertTrue(verdict.judge(audit(head="b" * 40), prov(), text()))

    def test_different_numbers_of_commits(self):
        self.assertTrue(verdict.judge(audit(commits=2), prov(), text()))


class MainTests(unittest.TestCase):
    def run_main(self, reports):
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for name, rep in zip(("a", "p", "t"), reports):
                p = os.path.join(d, name + ".json")
                if rep is not None:
                    with open(p, "w") as fh:
                        json.dump(rep, fh)
                paths.append(p)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = verdict.main(["--audit", paths[0], "--provenance", paths[1], "--text", paths[2],
                                     "--dossier", "https://example.org/INDEX.md"])
            return code, out.getvalue()

    def test_solved_prints_one_line(self):
        code, out = self.run_main([audit(), prov(), text()])
        self.assertEqual(code, 0)
        self.assertEqual(out, verdict.SOLVED % "https://example.org/INDEX.md" + "\n")
        self.assertTrue(out.startswith("TASK SOLVED: the code of unxed/tv3 is clean:"))
        self.assertTrue(out.endswith("dossier: https://example.org/INDEX.md.\n"))

    def test_not_ready(self):
        code, out = self.run_main([audit(), prov(pending_versions=["a.md abc"]), text()])
        self.assertEqual(code, 1)
        lines = out.splitlines()
        self.assertEqual(lines[0], "NOT READY:")
        self.assertEqual(len(lines), 2)

    def test_missing_report(self):
        code, out = self.run_main([audit(), None, text()])
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("NOT READY:"))


if __name__ == "__main__":
    unittest.main()
