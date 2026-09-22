# Native bytes decoding error policy

The original-map shootable-door audit uses the same valid Jac decoding idiom as
`scripts/audit_campaigns.jac`: `data.decode("utf-8", errors="replace")`.
Native building rejects the `errors` keyword with E5092. The viewer itself uses
ordinary UTF-8 decoding and is unaffected by this harness-only build failure.

Minimal repro: `repros/native_decode_errors.jac`. Expected output is
`DECODE ERROR POLICY PASS` after replacement and ignore assertions. Build with
`jac build repros/native_decode_errors.jac --native` using the documented source
compiler to reproduce the lowering failure.

The native keyword binder in
`jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/core.impl.jac`
rejects the argument. More fundamentally,
`NativeBytesEmitter.emit_decode` in
`jac/jaclang/compiler/backends/native/impl/primitives_native.impl.jac`
currently copies the bytes into a native string without using its arguments.
Accepting the keyword alone would not implement correct decoding. An upstream
fix needs encoding/error-policy handling and Python/native parity tests,
including malformed UTF-8, replacement, ignore and strict failures.

The failing idiom is preserved; no engine implementation replaces it. Native
acceptance of this particular harness is pending that compiler capability.
