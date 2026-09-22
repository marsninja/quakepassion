"""Native decoding must honor the encoding and error policy."""
with entry {
    assert b"A\xffB".decode("utf-8", errors="replace") == "A\ufffdB";
    assert b"A\xffB".decode("utf-8", errors="ignore") == "AB";
    print("DECODE ERROR POLICY PASS");
}
