"""Bytes are iterable integers; native set construction should deduplicate them."""
with entry {
    samples = b"\x01\x02\x01";
    values = set(samples);
    assert len(values) == 2;
    assert 1 in values and 2 in values;
    print("SET BYTES PASS");
}
