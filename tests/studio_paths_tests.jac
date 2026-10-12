import from editor.document.scene { Scene, Item }
import from editor.tools.paths { path_of }

test "a path is every corner reached from one of them, either way" {
    scene = Scene(game="q1", name="studio:test");
    first = scene.add_item({"classname": "path_corner", "origin": "0 0 0", "targetname": "a", "target": "b"});
    second = scene.add_item({"classname": "path_corner", "origin": "64 0 0", "targetname": "b", "target": "c"});
    third = scene.add_item({"classname": "path_corner", "origin": "64 64 0", "targetname": "c", "target": "a"});
    train = scene.add_item({"classname": "func_train", "origin": "0 0 32", "target": "a"});
    other = scene.add_item({"classname": "path_corner", "origin": "500 0 0", "targetname": "x", "target": "y"});
    far = scene.add_item({"classname": "path_corner", "origin": "600 0 0", "targetname": "y"});
    lone = scene.add_item({"classname": "light", "origin": "0 0 128"});
    scene.relink();
    everything = scene.items();
    # From the middle corner: round the loop, and back to the train that rides it.
    whole = path_of(everything, [second]);
    assert whole[0] is second and len(whole) == 4 and first in whole and third in whole and train in whole;
    assert other not in whole and far not in whole and lone not in whole;
    # From its end, the other path's two; a thing on no path is alone.
    assert path_of(everything, [far]) == [far, other] and path_of(everything, [lone]) == [lone];
    assert path_of(everything, []) == [] and len(path_of(everything, [second, other])) == 6;
}
