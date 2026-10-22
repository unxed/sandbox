import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audit"))
import tokens as T  # noqa: E402


def pas(text):
    return [(c, t) for c, t, _l in T.tokenize_pascal(text)]


def cpp(text):
    return [(c, t) for c, t, _l in T.tokenize_c(text)]


def plain(text):
    return [(c, t) for c, t, _l in T.tokenize_plain(text)]


class LanguageTests(unittest.TestCase):
    def test_extensions_in_any_case(self):
        for name in ("a.pas", "A.PP", "b.Inc", "c.lpr", "d.DPR"):
            self.assertEqual(T.language(name), "pascal", name)
        for name in ("a.c", "a.CC", "a.cpp", "a.cxx", "a.h", "a.HH", "a.hpp"):
            self.assertEqual(T.language(name), "c", name)
        for name in ("a.md", "a.py", "a.json", "Makefile"):
            self.assertEqual(T.language(name), "plain", name)


class PascalTests(unittest.TestCase):
    def test_comments_and_layout(self):
        got = pas("{ c } x := $1F; // y\n(* z *) 'a'")
        self.assertEqual(got, [("i", "x"), ("p", ":="), ("l", "n31"), ("p", ";"), ("l", "n97")])

    def test_keywords_without_case(self):
        self.assertEqual(pas("BEGIN End Foo"), [("w", "begin"), ("w", "end"), ("i", "foo")])

    def test_numbers_by_value(self):
        self.assertEqual(pas("255 $FF %11111111 &377"), [("l", "n255")] * 4)

    def test_char_and_string_of_one_character(self):
        self.assertEqual(pas("#65 'A' #$41"), [("l", "n65")] * 3)

    def test_strings(self):
        self.assertEqual(pas("'it''s'"), [("l", "sit's")])
        self.assertEqual(pas("'ab'#13'c'"), [("l", "sab\rc")])
        self.assertEqual(pas("'ab' 'c'"), [("l", "sab"), ("l", "n99")])

    def test_real_numbers(self):
        self.assertEqual(pas("1.5e3"), [("l", "f1.5e3")])
        self.assertEqual(pas("1..5"), [("l", "n1"), ("p", ".."), ("l", "n5")])

    def test_operators(self):
        self.assertEqual([t for _c, t in pas("a := b <> c")], ["a", ":=", "b", "<>", "c"])

    def test_heading_is_one_token(self):
        got = pas("procedure Foo(a: Integer; b: Word); virtual; x := 1;")
        self.assertEqual(got[0], ("h", ""))
        self.assertEqual(got[1:], [("i", "x"), ("p", ":="), ("l", "n1"), ("p", ";")])

    def test_heading_with_result_and_directives(self):
        got = pas("function Bar: Integer; override; cdecl; begin")
        self.assertEqual(got, [("h", ""), ("w", "begin")])

    def test_heading_stops_at_the_semicolon(self):
        got = pas("constructor Create; begin end;")
        self.assertEqual(got[0], ("h", ""))
        self.assertEqual(got[1], ("w", "begin"))

    def test_lines(self):
        toks = T.tokenize_pascal("a\n{ x\n y }\nb")
        self.assertEqual([t[2] for t in toks], [1, 4])


class CTests(unittest.TestCase):
    def test_comments(self):
        self.assertEqual(cpp("a /* b */ c // d\n e"), [("i", "a"), ("i", "c"), ("i", "e")])

    def test_numbers_by_value(self):
        self.assertEqual(cpp("32 0x20 040 32u 0b100000 32UL"), [("l", "n32")] * 6)

    def test_floats(self):
        self.assertEqual(cpp("1.5f"), [("l", "f1.5")])

    def test_characters_and_strings(self):
        self.assertEqual(cpp("'a' L'a' \"a\""), [("l", "n97")] * 3)
        self.assertEqual(cpp('"ab\\n"'), [("l", "sab\n")])
        self.assertEqual(cpp("'\\n'"), [("l", "n10")])

    def test_operators_and_keywords(self):
        self.assertEqual(cpp("a::b->c"), [("i", "a"), ("p", "::"), ("i", "b"), ("p", "->"), ("i", "c")])
        self.assertEqual(cpp("while (x)")[0], ("w", "while"))

    def test_raw_string(self):
        self.assertEqual(cpp('R"x(ab"c)x"'), [("l", 'sab"c')])

    def test_same_value_as_pascal(self):
        self.assertEqual(cpp("0x20"), pas("$20"))
        self.assertEqual(cpp('"abc"'), pas("'abc'"))


class PlainTests(unittest.TestCase):
    def test_words_numbers_strings(self):
        got = plain('Hello, "two words" 42 0x10 \'q\' don\'t')
        self.assertEqual(got[0], ("i", "hello"))
        self.assertIn(("l", "stwo words"), got)
        self.assertIn(("l", "n42"), got)
        self.assertIn(("l", "n16"), got)
        self.assertIn(("l", "n113"), got)
        self.assertIn(("i", "don"), got)


class StreamTests(unittest.TestCase):
    def test_raw_and_ren_keys(self):
        toks = T.tokenize_pascal("a := b + 1")
        self.assertEqual(T.raw_keys(toks), ["ia", "p:=", "ib", "p+", "ln1"])
        self.assertEqual(T.ren_keys(toks), ["@i", "p:=", "@i", "p+", "@l"])

    def test_keywords_are_kept_by_ren(self):
        self.assertEqual(T.ren_keys(T.tokenize_pascal("if a then")), ["wif", "@i", "wthen"])

    def test_heading_breaks_streams(self):
        toks = T.tokenize_pascal("a procedure P; b")
        self.assertEqual(T.raw_keys(toks), ["ia", None, "ib"])
        keys, index = T.lit_stream(T.tokenize_pascal("1 2 procedure P; 3"))
        self.assertEqual(keys, ["ln1", "ln2", None, "ln3"])
        self.assertEqual(index, [0, 1, 2, 3])

    def test_window_hashes(self):
        keys = ["a", "b", "c", "d", "a", "b", "c"]
        got = T.window_hashes(keys, 3)
        self.assertEqual([s for s, _h in got], [0, 1, 2, 3, 4])
        h = dict(got)
        self.assertEqual(h[0], h[4])
        self.assertNotEqual(h[0], h[1])
        self.assertEqual(T.window_hashes(["a", "b"], 3), [])

    def test_window_hashes_break_at_none(self):
        keys = ["a", "b", None, "a", "b", "c"]
        got = T.window_hashes(keys, 2)
        self.assertEqual([s for s, _h in got], [0, 3, 4])

    def test_window_hash_of_a_slice_equals_the_hash_in_a_stream(self):
        keys = ["x", "a", "b", "c", "y"]
        inner = dict(T.window_hashes(keys, 3))[1]
        alone = T.window_hashes(["a", "b", "c"], 3)[0][1]
        self.assertEqual(inner, alone)

    def test_significant(self):
        self.assertTrue(T.significant("n32"))
        self.assertFalse(T.significant("n31"))
        self.assertTrue(T.significant("sab"))
        self.assertFalse(T.significant("f1.5"))

    def test_count(self):
        self.assertTrue(T.is_count(["n1", "n2", "n3", "n4"]))
        self.assertFalse(T.is_count(["n10", "n50", "n90", "n130"]))
        self.assertFalse(T.is_count(["n1"]))


if __name__ == "__main__":
    unittest.main()
