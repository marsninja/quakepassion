import from "@jac/runtime" { Link }
import from "lucide-react" { Github }

def:pub SiteHeader() -> JsxElement {
    return <header className="sticky top-0 z-50 border-b border-border/60 bg-background/80 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
            <Link to="/" className="flex items-center gap-3">
                <img src="/static/assets/logo.svg" alt="QuakePassion logo" className="size-9"/>
                <span className="text-lg font-bold uppercase tracking-widest">
                    Quake<span className="text-primary">Passion</span>
                </span>
            </Link>
            <nav className="flex items-center gap-6 text-sm">
                <Link to="/" className="text-muted-foreground transition-colors hover:text-foreground">
                    Home
                </Link>
                <Link to="/architecture" className="text-muted-foreground transition-colors hover:text-foreground">
                    Architecture
                </Link>
                <a
                    href="https://github.com/marsninja/quakepassion"
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex h-8 items-center gap-2 rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
                >
                    <Github className="size-4"/>
                    GitHub
                </a>
            </nav>
        </div>
    </header>;
}
