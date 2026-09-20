"""A metadata-only refresh must not bless native code built against old bodies.

Run with jac run repros/native_cache_section_merge.jac using a source compiler.
This isolates the cache writer used by interface persistence; it does not clear
or repair engine caches.
"""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.jir {
    SEC_CTDEPS, SEC_NATIVE_OBJ, ct_deps_section, ct_deps_fresh,
    get_module_cache_path, read_section_bytes, write_module_cache
}

with entry {
    with TemporaryDirectory(prefix="qp-section-merge-") as directory {
        folder = Path(directory);
        dependency = folder / "value.jac";
        consumer = folder / "consumer.jac";
        dependency.write_text("def value() -> int { return 1; }\n");
        consumer.write_text("import from .value { value }\nwith entry { print(value()); }\n");
        # A stand-in payload is sufficient: the writer treats native code as opaque.
        old_native = b"native code compiled against value returning 1";
        write_module_cache(str(consumer), None, extra_sections={
            SEC_CTDEPS: ct_deps_section([str(dependency)], [str(dependency)]),
            SEC_NATIVE_OBJ: old_native
        });
        cache = get_module_cache_path(str(consumer));
        dependency.write_text("def value() -> int { return 2; }\n");
        assert not ct_deps_fresh(cache.read_bytes());
        # Interface persistence refreshes metadata without producing native code.
        write_module_cache(str(consumer), None, extra_sections={
            SEC_CTDEPS: ct_deps_section([str(dependency)], [str(dependency)])
        });
        data = cache.read_bytes();
        retained = read_section_bytes(data, SEC_NATIVE_OBJ) is not None;
        print("Metadata fresh:", ct_deps_fresh(data), "Old native code retained:", retained);
        assert not retained, "Metadata refresh retained obsolete native code";
    }
}
