import from "@jac/runtime" { Link }
import from "lucide-react" { ArrowRight, Flame, Network, Package, Heart }
import from ..components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..components.ui.badge { Badge }


def GameCard(icon: str, title: str, year: str, desc: str, formats: str) -> JsxElement {
    return <Card className="border-border/60 bg-card/60 transition-all hover:border-primary/50 hover:shadow-[0_0_30px_-10px_rgba(255,122,24,0.4)]">
        <CardHeader>
            <div className="mb-2 flex items-center justify-between">
                <img src={icon} alt={title} className="size-12"/>
                <Badge variant="outline" className="font-mono text-muted-foreground">{year}</Badge>
            </div>
            <CardTitle className="text-lg">{title}</CardTitle>
            <CardDescription>{desc}</CardDescription>
        </CardHeader>
        <CardContent>
            <p className="font-mono text-xs tracking-wide text-primary/80">{formats}</p>
        </CardContent>
    </Card>;
}


def:pub Home() -> JsxElement {
    return <div>
        <section className="relative overflow-hidden">
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_60%_50%_at_50%_-10%,rgba(255,122,24,0.18),transparent)]"></div>
            <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 pb-20 pt-24 lg:grid-cols-2">
                <div className="flex flex-col items-start gap-6">
                    <Badge variant="outline" className="gap-2 border-primary/40 px-3 py-1 text-primary">
                        <Flame className="size-3"/>
                        Built with Jac + raylib
                    </Badge>
                    <h1 className="text-5xl font-bold leading-tight tracking-tight">
                        One engine.
                        <br/>
                        Three Quakes.
                        <br/>
                        <span className="bg-gradient-to-r from-amber-300 via-orange-500 to-orange-700 bg-clip-text text-transparent">Pure Jac.</span>
                    </h1>
                    <p className="max-w-lg text-lg text-muted-foreground">
                        QuakePassion is a love letter to the games that invented an industry —
                        a single, coherent 3D engine that loads the original assets of Quake,
                        Quake II, and Quake III Arena, and makes them all playable in one world.
                    </p>
                    <div className="flex flex-wrap gap-3">
                        <Link
                            to="/architecture"
                            className="inline-flex h-11 items-center gap-2 rounded-lg bg-primary px-6 font-medium text-primary-foreground transition-colors hover:bg-primary/90"
                        >
                            Explore the Architecture
                            <ArrowRight className="size-4"/>
                        </Link>
                        <a
                            href="https://github.com/marsninja/quakepassion"
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex h-11 items-center rounded-lg border border-border px-6 font-medium transition-colors hover:bg-muted"
                        >
                            View on GitHub
                        </a>
                    </div>
                </div>
                <div className="relative">
                    <img src="/static/assets/world-graph.svg" alt="The world as a graph of areas, portals, and entities" className="w-full"/>
                </div>
            </div>
        </section>

        <section className="border-t border-border/40 bg-card/20">
            <div className="mx-auto max-w-6xl px-6 py-20">
                <h2 className="mb-3 text-3xl font-bold tracking-tight">Not a source port. A rebirth.</h2>
                <p className="mb-12 max-w-2xl text-muted-foreground">
                    QuakePassion builds its own coherent engine, physics, and file formats.
                    It will feel different from the originals — by design. What it promises
                    is compatibility where it matters: everything loads, everything plays.
                </p>
                <div className="grid gap-6 md:grid-cols-3">
                    <Card className="border-border/60 bg-card/60">
                        <CardHeader>
                            <Flame className="mb-2 size-8 text-primary"/>
                            <CardTitle>Its own engine</CardTitle>
                            <CardDescription>
                                One architecture, one physics model, one set of native formats.
                                Coherence over emulation — a single world that hosts three games.
                            </CardDescription>
                        </CardHeader>
                    </Card>
                    <Card className="border-border/60 bg-card/60">
                        <CardHeader>
                            <Package className="mb-2 size-8 text-primary"/>
                            <CardTitle>Loads the originals</CardTitle>
                            <CardDescription>
                                PAK, PK3, BSP, MDL, MD2, MD3, WAD, WAL, shaders — drop in your
                                original game files and the engine takes it from there.
                            </CardDescription>
                        </CardHeader>
                    </Card>
                    <Card className="border-border/60 bg-card/60">
                        <CardHeader>
                            <Network className="mb-2 size-8 text-primary"/>
                            <CardTitle>Object-Spatial to the core</CardTitle>
                            <CardDescription>
                                The world is a graph of areas, portals, and entities. Engine
                                systems are walkers that travel it. Computation moves to data.
                            </CardDescription>
                        </CardHeader>
                    </Card>
                </div>
            </div>
        </section>

        <section>
            <div className="mx-auto max-w-6xl px-6 py-20">
                <h2 className="mb-3 text-3xl font-bold tracking-tight">Three games. One world.</h2>
                <p className="mb-12 max-w-2xl text-muted-foreground">
                    Every relevant original file format, normalized into one engine-native
                    representation at the asset boundary — so each game stays itself, and the
                    engine stays clean.
                </p>
                <div className="grid gap-6 md:grid-cols-3">
                    <GameCard
                        icon="/static/assets/q1.svg"
                        title="Quake"
                        year="1996"
                        desc="The original. Gothic dread, lightning movement, and the level design that started it all."
                        formats="PAK · BSP29 · MDL · WAD"
                    />
                    <GameCard
                        icon="/static/assets/q2.svg"
                        title="Quake II"
                        year="1997"
                        desc="The war against the Strogg. Industrial worlds, colored lighting, and a heavier kind of momentum."
                        formats="PAK · BSP38 · MD2 · WAL"
                    />
                    <GameCard
                        icon="/static/assets/q3.svg"
                        title="Quake III Arena"
                        year="1999"
                        desc="Pure arena perfection. Strafe-jumping, rail duels, and shaders that changed real-time rendering."
                        formats="PK3 · BSP46 · MD3 · Shaders"
                    />
                </div>
            </div>
        </section>

        <section className="border-t border-border/40 bg-card/20">
            <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 py-20 lg:grid-cols-2">
                <div>
                    <h2 className="mb-3 text-3xl font-bold tracking-tight">Quake is already a graph.</h2>
                    <p className="mb-4 text-muted-foreground">
                        BSP maps are areas joined by portals. Entities are wired together by
                        trigger chains. id Software encoded a graph in C structs in 1996 —
                        QuakePassion makes that graph first-class with Jac nodes, edges, and
                        walkers.
                    </p>
                    <p className="mb-6 text-muted-foreground">
                        Visibility is a walker flooding through portal edges. A button firing a
                        door is a walker traversing a Targets edge. Every tick is a set of
                        walkers sweeping the world.
                    </p>
                    <Link to="/architecture" className="inline-flex items-center gap-2 font-medium text-primary hover:underline">
                        Read the full architecture
                        <ArrowRight className="size-4"/>
                    </Link>
                </div>
                <img src="/static/assets/arch-graph.svg" alt="World graph schema" className="w-full rounded-xl border border-border/60 bg-card/40 p-4"/>
            </div>
        </section>

        <section>
            <div className="mx-auto max-w-3xl px-6 py-24 text-center">
                <Heart className="mx-auto mb-6 size-10 text-primary"/>
                <blockquote className="text-2xl font-medium leading-relaxed">
                    Quake is the thing that got me into programming. This project celebrates
                    that passion — and the true GOAT, John Carmack, who invented 3D games as
                    we know it.
                </blockquote>
                <p className="mt-6 text-sm uppercase tracking-widest text-muted-foreground">
                    The journey is the point
                </p>
            </div>
        </section>
    </div>;
}
