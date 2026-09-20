with entry {
    names: set[str] = {"e1m2", "e1m1"};
    ordered = sorted(names);
    assert ordered == ["e1m1", "e1m2"];
    print(ordered);
}
