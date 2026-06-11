def:pub SiteFooter() -> JsxElement {
    return <footer className="border-t border-border/60 bg-background">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-4 px-6 py-12 text-center">
            <img src="/static/assets/logo.svg" alt="" className="size-12 opacity-90"/>
            <p className="max-w-xl text-sm text-muted-foreground">
                A heartfelt attempt to build a beautiful 3D engine in pure Jac and raylib —
                one engine that plays all three Quakes.
            </p>
            <p className="max-w-xl text-xs text-muted-foreground/70">
                Dedicated to John Carmack — the man, the coder, the ninja who invented
                3D games as we know it.
            </p>
            <div className="flex items-center gap-6 text-xs text-muted-foreground">
                <a href="https://github.com/marsninja/quakepassion" target="_blank" rel="noreferrer" className="transition-colors hover:text-foreground">GitHub</a>
                <a href="https://github.com/jaseci-labs/jaseci" target="_blank" rel="noreferrer" className="transition-colors hover:text-foreground">Jac Language</a>
                <a href="https://www.raylib.com" target="_blank" rel="noreferrer" className="transition-colors hover:text-foreground">raylib</a>
                <span>MIT License</span>
            </div>
        </div>
    </footer>;
}
