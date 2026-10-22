# tv3

tv3 is a class-based Free Pascal library for text user interfaces. Its units translate
[magiblot/tvision](https://github.com/magiblot/tvision) and [magiblot/tvterm](https://github.com/magiblot/tvterm).

The library is in development. The units come in one at a time, bottom up by their uses; each one arrives in its own
pull request together with its test program and its provenance record.

## Where to look

- [`VERDICT.md`](VERDICT.md): the state of the repository, the output of `tools/audit/verdict.py`, written by CI.
- [`provenance/INDEX.md`](provenance/INDEX.md): the dossier, one line per file with its kind, sources and versions.
- [`docs/CLEANROOM.md`](docs/CLEANROOM.md): the protocol by which a file is made.
- [`CLAUDE.md`](CLAUDE.md): the rules of the repository.
- [`docs/ASYNC.md`](docs/ASYNC.md) and [`docs/API-NAMES.md`](docs/API-NAMES.md): the asynchronous contract with the
  porting rule, and the naming rules.
- [CI runs](https://github.com/unxed/tv3-new/actions/workflows/ci.yml).

## Checks

Run from the root of the repository, with a full clone:

- `python3 -m unittest discover -s tools/tests -p 'test_*.py'`: the tests of the tools.
- `python3 tools/text_lint.py`: the text rules of the files (`--commits RANGE` adds the messages of commits).
- `python3 tools/audit/provenance_lint.py --history`: the provenance records, with every version of every file of
  the history.
- `tools/audit/run.sh`: fetches the corpora into `$CORPORA` (default `~/.cache/tv3-corpora`) and audits the whole
  history.
- `tools/test.sh`: builds the units of `src/` with Free Pascal 3.2 and runs `tests/t_*.pas`.

## License

- A unit whose header says `Translated from magiblot/tvision @ <commit>` is a derivative work of magiblot/tvision,
  and so of the Turbo Vision 2.0 release published by Borland: the Borland disclaimer and the MIT license of
  magiblot apply ([`COPYRIGHT.magiblot`](COPYRIGHT.magiblot)). Its header names the magiblot files it was
  translated from.
- A unit whose header says `Translated from magiblot/tvterm @ <commit>` is a derivative work of magiblot/tvterm: its
  MIT license applies ([`COPYRIGHT.tvterm`](COPYRIGHT.tvterm)). Its header names the tvterm files it was translated
  from.
- Every other file (the units without such a notice, the tools, the tests, the demos) is under the MIT license
  ([`LICENSE`](LICENSE)).
