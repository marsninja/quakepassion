"""Native bytearray.extend incorrectly lowers typed integer elements.
Expected stdout: 3. No game assets or graphics are required.
"""
with entry {
    colors = bytearray();
    values: list[u8] = [u8(1), u8(0), u8(2)];
    colors.extend(values);
    print(len(colors));
}
