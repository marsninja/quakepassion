"""Tuple handlers must match each member, including exception subclasses."""
with entry {
    caught = False;
    try {
        try {
            with open("/qp-intentionally-missing-directory/cache.light","rb") as stream {
                data = stream.read();
            }
        } except OSError { caught = True; }
    } except Exception { }
    print("single OSError caught:",caught);
    tuple_caught = False;
    try {
        try {
            with open("/qp-intentionally-missing-directory/cache.light","rb") as stream {
                data = stream.read();
            }
        } except (OSError,ValueError) { tuple_caught = True; }
    } except Exception { }
    print("tuple OSError caught:",tuple_caught);
    value_caught = False;
    try {
        try { raise ValueError("test"); }
        except (OSError,ValueError) { value_caught = True; }
    } except Exception { }
    print("tuple ValueError caught:",value_caught);
    assert caught and tuple_caught and value_caught;
}
