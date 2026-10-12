"""The developer's readout: what the figures the system gives are, in the
words the status bar shows."""

"""The megabytes `ps -o rss=` says a program holds in memory: it answers in
kilobytes, with spaces about the figure (0.0 when it said nothing that is a
number)."""
def resident_megabytes(said: str) -> float {
    word = said.strip().split("\n")[0].strip() if said.strip() else "";
    if not word.isdigit() {
        return 0.0;
    }
    return float(int(word)) / 1024.0;
}

"""A count of megabytes as the readout shows it: whole megabytes, and from
a thousand of them gigabytes to one place. Nothing when it is not known."""
def memory_words(megabytes: float) -> str {
    if megabytes <= 0.0 {
        return "";
    }
    if megabytes >= 1000.0 {
        return str(round(megabytes / 1024.0, 1)) + " GB";
    }
    return str(int(round(megabytes))) + " MB";
}
