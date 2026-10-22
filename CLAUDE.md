# Rules of the repository

These rules hold for every file of the tree and every commit of the history, and they win over any other
document of the repository.

1. Outside sources. The outside sources are:
   - magiblot/tvision at b4831e2 (commit b4831e2ca16652db327fb7cc964f1c8c2d512524);
   - magiblot/tvterm at 210eb23 (commit 210eb23564da06c358d2623388939bb02f7f3419), its own `include/` and
     `source/`, not the libraries it builds on such as libvterm;
   - VTExts.md (branch extsdocs of unxed/far2l, the specification of the far2l terminal extensions);
   - the documents of standards in `tools/audit/facts/`.

   A file follows an outside source only when its provenance record names it.
2. No code of another implementation of Turbo Vision, of Free Vision or another package of Free Pascal, of the Free
   Pascal IDE, of DOS Navigator or of far2l, in any form, in the tree or in the history. The far2l extensions
   follow VTExts.md only.
3. No statement about the origin of code in code, comments, documents or commit messages (for example "written from
   scratch", "not copied", "our own code", "nothing is taken from", "after X"). The only statements of origin are:
   a. the notice "Translated from magiblot/tvision @ <commit>" or "Translated from magiblot/tvterm @ <commit>" with
      the list of the C++ sources and a pointer to `COPYRIGHT.magiblot` or `COPYRIGHT.tvterm`;
   b. `provenance/`, with a record of facts for every file, checked by `tools/audit/provenance_lint.py`;
   c. `docs/CLEANROOM.md`, the protocol;
   d. `VERDICT.md`, the output of `tools/audit/verdict.py`, written by CI only.
4. Neutral text. The repository describes the code, its rules and how they are checked, as they are. It does not
   refer to the process that produced a change, to the tools or services of that process, to discussions or to the
   reasons of past decisions. `tools/text_lint.py` checks it.
5. The audit is the one of `tools/audit/`, with its numbers. A match is accepted only when `tools/audit/prove.py`
   proves it; any other match is made again from the allowed sources.
6. The CI job `verdict` runs on every pull request and on main. A file without a complete record, or an unproved
   match, fails it.
7. `LICENSE`, `COPYRIGHT.magiblot`, `COPYRIGHT.tvterm` and the notices of files change only by a decision of the
   owner of the repository.
8. Something in violation is removed from the tree and from the history and is made again by
   `docs/CLEANROOM.md`. A loss of function is acceptable until then; a violation is not.
