# Native OSP visit: compiler defect and local fix

Observed September 19, 2026 with `/Users/marsninja/.local/bin/jac`, version
0.37.19, Darwin arm64. No compiler-source override is enabled.

## Reproduce with the unpatched binary

From the repository root:

```sh
JAC_NO_DEV_SOURCE=1 jac check repros/native_visit_list.jac
JAC_NO_DEV_SOURCE=1 jac build repros/native_visit_list.jac --native -o /tmp/qp-visit-repro
```

The first command succeeds. The second fails with E5020:

```text
Native compilation failed: LLVM IR parsing error
error: expected instruction opcode
spread.loop:
^
```

The [minimal program](../repros/native_visit_list.jac) creates two nodes and
uses `visit [nbrs[i]]` inside a walker loop. Expected: compile and traverse
the two-node graph. Actual: malformed LLVM IR, before execution. It requires
neither raylib nor game assets. A separate control program using
`visit [here -->[?:Area]]` without the indexed-list loop compiles successfully.

This is a compiler defect, not an invalid graph idiom: type checking accepts
the repro, and the engine's existing visibility traversal tests pass through
`jac test`. The pinned submodule's OSP tests and the installed compiler's
bundled testing reference also use graph queries as visit targets.

## Compiler location

Inspect the **installed 0.37.19 compiler**, not the older reference submodule:

- `jaclang/compiler/backends/native/na_ir_gen_pass.impl/osp.impl.jac`,
  `NaIRGenPass._codegen_visit`, around line 1515.
- `.../lists.impl.jac`, `_reflavor_list`, around line 154.
- `.../container_helpers.impl.jac`, `_emit_spread_copy`, around line 342.

Confirmed mechanism: `_codegen_visit`
uses `self.builder.call(... self._coerce_type(_targets, ...) ...)`. Evaluating
that coercion can invoke `_reflavor_list` / `_emit_spread_copy`, which creates
basic blocks and replaces `self._builder`. The call then uses the builder
captured before coercion changed the active block, leaving invalid IR near
`spread.loop`. Evaluating both coerced arguments before looking up `self.builder.call` fixes the ordering. A second ownership problem appears once the program compiles: `_emit_spread_copy` consumes an owned source list, but `_codegen_visit` subsequently releases that original list again. The patch releases the owned converted list instead (or the original when conversion only borrows/aliases it). The initial emission-only fix passed short smoke runs but an interactive `jac run` aborted in macOS malloc with heap corruption, which exposed this cleanup path.

## Original project validation

- `jac test -j 0`: **19 passed** (math, clock, OSP world, and PAK reader).
- `jac check main.jac tests/phase1_tests.jac tests/phase2_pak_tests.jac repros/native_visit_list.jac`: **4 passed**.
- `jac build main.jac --native -o main`: E5025 while linking the world module,
  with the same invalid IR at `spread.loop`.
- `QP_SMOKE=1 jac run main.jac`: fails on the same world-module compilation;
  no rendered screenshot was verified.

## Local fix and current validation

The fix is in [patches/jac-0.37.19-native-visit.patch](../patches/jac-0.37.19-native-visit.patch).
It changes Jac's `_codegen_visit`, not the engine's graph traversal.

```sh
python3 scripts/prepare_compiler.py
jac build repros/native_visit_list.jac --native -o /tmp/qp-visit-repro
/tmp/qp-visit-repro
jac test -j 0
jac build main.jac --native -o main
QP_SMOKE=1 jac run main.jac
jac run main.jac
```

The setup script locates the compiler shipped inside the installed Jac 0.37.19
binary, copies it into the ignored `.jac/compiler` directory, removes the
copied sealed manifest, and applies the patch. Removing that manifest is
necessary: otherwise Jac executes the unchanged bundled bytecode instead of
the edited source. `[dev] jaclang_source` selects this private compiler copy.
The installed binary, its runtime cache, and other compiler checkouts remain
unmodified. First use compiles the sources and can take a few minutes.

Validation after the fix:

- `jac test -j 0`: **19 passed**; all four requested type checks pass.

- Native minimal repro builds and exits successfully; it asserts that both
  nodes were visited on each of 10,000 repeated traversals.
- Native engine builds successfully.
- Both `QP_SMOKE=1 ./main` and `QP_SMOKE=1 jac run main.jac` initialize raylib,
  write all three screenshots, and close successfully.
- Screenshots confirm both rooms are rendered facing the portal (2/2 visible),
  and the second room is culled facing away (1/2 visible).
- The interactive `jac run main.jac` ran beyond the earlier abort and then
  closed normally with exit code 0. Manual movement behavior is not exhaustively tested.
- Compiler setup succeeds in a fresh temporary directory and is idempotent.

The patch includes a comment in the compiler declaration file to invalidate
cached compiler bytecode alongside its implementation change. The compiler
patch is saved for upstream review, but has not been submitted.
The local setup deliberately accepts only 0.37.19: when upgrading Jac, retest
this repro with `JAC_NO_DEV_SOURCE=1` and retire or rebase the patch.
