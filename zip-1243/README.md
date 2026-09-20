# zip-1243: text lost LZ77 at the default Deflate level

f4 issue #1243: a 120 KB text packs to ~87 KB (72%) with "Add to archive".
Cause: `compressFile` in `unxed/zip` (archiver.go) switches to `flate.HuffmanOnly`
for any block with <=136 distinct byte values, at every level.

`patches/0001` adds the reproducing test, `patches/0002` restricts the shortcut to
`WithArchiverLevel(1)` (the BestSpeed case it was written for). The workflow
`zip-1243.yml` runs the test on unxed/zip v0.1.139 before and after 0002.
Nothing is built locally; this only runs in GitHub Actions.
