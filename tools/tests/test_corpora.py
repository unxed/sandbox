import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audit"))
import corpora  # noqa: E402


def touch(root, rel, text="x"):
    full = os.path.join(root, rel)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as fh:
        fh.write(text)
    return full


class CorporaTests(unittest.TestCase):
    def test_pins_are_complete(self):
        names = [g[0] for g in corpora.GIT_REFERENCES] + [a[0] for a in corpora.ARCHIVES]
        self.assertEqual(sorted(names), ["bp7tv", "dn151", "dn214", "far2l", "fpc322", "fpcmain", "fpide", "jserv",
                                         "rhtv", "sigala", "tv20", "tvdelphi"])
        for g in corpora.GIT_REFERENCES:
            self.assertEqual(len(g[2]), 40)
        for a in corpora.ARCHIVES:
            self.assertEqual(len(a[2]), 64)
        self.assertEqual([m[2] for m in corpora.MAGIBLOT],
                         ["b4831e2ca16652db327fb7cc964f1c8c2d512524", "210eb23564da06c358d2623388939bb02f7f3419"])
        self.assertIn("8030902caf42498e1612e5a393ab7fc489048f51", corpora.VTEXTS_URL)

    def test_prune_keeps_code_files_only(self):
        with tempfile.TemporaryDirectory() as d:
            touch(d, "a/x.PAS")
            touch(d, "a/y.png")
            touch(d, "b/z.hpp")
            touch(d, ".git/config")
            touch(d, "c/readme.md")
            corpora.prune_to_code(d)
            left = sorted(os.path.relpath(os.path.join(b, n), d) for b, _ds, ns in os.walk(d) for n in ns)
            self.assertEqual(left, ["a/x.PAS", "b/z.hpp"])
            self.assertFalse(os.path.exists(os.path.join(d, "c")))

    def test_marker(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertFalse(corpora.marker_ok(d, "sig\n"))
            corpora.write_marker(d, "sig\n")
            self.assertTrue(corpora.marker_ok(d, "sig\n"))
            self.assertFalse(corpora.marker_ok(d, "other\n"))

    def test_find_inner_in_any_letter_case(self):
        with tempfile.TemporaryDirectory() as d:
            full = touch(d, "Root/bpascal.700/d11/TvSrc.zip")
            self.assertEqual(corpora.find_inner(d, "BPASCAL.700/D11/TVSRC.ZIP"), full)
            self.assertIsNone(corpora.find_inner(d, "BPASCAL.700/D11/OTHER.ZIP"))

    def test_walk_files(self):
        with tempfile.TemporaryDirectory() as d:
            touch(d, "c/a.pas")
            touch(d, "c/b.txt")
            touch(d, "c/.done")
            self.assertEqual(corpora.walk_files(d, "c", corpora.CODE_EXT), ["c/a.pas"])
            self.assertEqual(corpora.walk_files(d, "c"), ["c/a.pas", "c/b.txt"])

    def test_retry_tries_again_and_gives_up(self):
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) < 3:
                raise OSError("network")
            return "ok"

        with mock.patch.object(corpora.time, "sleep"):
            self.assertEqual(corpora.retry("x", flaky), "ok")
            self.assertEqual(len(calls), 3)

            def broken():
                raise OSError("down")

            with self.assertRaises(RuntimeError):
                corpora.retry("y", broken)

    def test_sha256_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = touch(d, "f", "abc")
            self.assertEqual(corpora.sha256_file(p),
                             "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")


if __name__ == "__main__":
    unittest.main()
