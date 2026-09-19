node Area {}
walker Flood {
    has visited: int = 0;
    can flood with Area entry {
        self.visited += 1;
        nbrs = [here -->];
        for i in range(len(nbrs)) {
            visit [nbrs[i]];
        }
    }
}
with entry {
    a = Area();
    a ++> Area();
    # Exercise ownership across repeated visits, not just compilation.
    for i in range(10000) {
        result = a spawn Flood();
        assert result.visited == 2;
    }
}
