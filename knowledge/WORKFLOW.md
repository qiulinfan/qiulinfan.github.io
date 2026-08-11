# Knowledge instance workflow

The independent [`kgdistiller`](https://github.com/qiulinfan/kgdistiller)
checkout owns the engine, knowledge/paper Skills, prebuilt agents, workflows,
tests, and local Codex linker. qlblog owns only this personal instance and an
adopted static export.

## Daily site work

The normal path consumes committed data only:

```sh
make knowledge-check
make blog-check
make blog-build
```

These commands do not invoke kgdistiller and do not require its repository.

## Explicit authoring refresh

When personal notes or reviewed graph decisions must change, first select and
install the intended kgdistiller product revision. Its development checkout may
remain linked directly into Codex for live Skill iteration. From qlblog, use the
public CLI with this repository as the explicit instance root:

```sh
kgdistiller --repo-root . sync
kgdistiller --repo-root . check
```

Scoped `sync --subject`, `sync --course`, and `sync --file` commands remain
available through the root Makefile. Candidate/query/ingest work follows the
product repository's canonical Skills and review gates. Do not hand-edit graph
JSONL, guess identity from similarity, or publish a failed/partial ingest.

## Adopt a product revision

Adopt only a clean, committed product revision that has passed its product
tests. The instance side is deliberately a two-commit adoption: first commit
all source, registry, alignment, policy, and private-graph changes as commit A
and require the qlblog worktree (including untracked files) to be clean. Then
create the static bundle from that clean checkout, whose manifest records
commit A as `source.revision` and the selected product commit as
`producer.commit`:

```sh
kgdistiller --repo-root . export site \
  --output knowledge/export/site \
  --product-commit <full-kgdistiller-commit> \
  --source-repository https://github.com/qiulinfan/qiulinfan.github.io \
  --replace
python3 knowledge/export/site/verify_export.py knowledge/export/site
make knowledge-check
```

`--replace` accepts only a valid existing kgdistiller bundle and stages and
verifies the replacement before an atomic directory swap; a failed export
leaves the adopted bundle unchanged. Review the private graph diff, public
bundle diff, producer provenance, privacy filter, counts, and hashes together.
Commit the qlblog bundle as commit B only when that review succeeds. The
exporter refuses a dirty instance or a product commit that does not identify
the clean product checkout executing it; do not bypass those provenance gates.
This export receipt replaces the old submodule-pointer model: pulling or
editing kgdistiller never moves qlblog automatically.

## Deployment

GitHub Pages verifies `knowledge/export/site`, builds notes and Astro, and
deploys the result. It never checks out, installs, or executes kgdistiller. The
knowledge endpoint returns the committed public `graph.json`, and the Typst
toolchain consumes the committed public registry.
