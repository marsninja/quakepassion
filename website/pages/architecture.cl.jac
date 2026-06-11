import from "lucide-react" { Network, Cpu, FolderTree, Map, Footprints, Rocket }
import from ..components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..components.ui.badge { Badge }
import from ..components.ui.separator { Separator }


def SchemaCard(name: str, kind: str, desc: str) -> JsxElement {
    return <Card className="border-border/60 bg-card/60">
        <CardHeader>
            <div className="flex items-center justify-between">
                <CardTitle className="font-mono text-base">{name}</CardTitle>
                <Badge variant="outline" className="font-mono text-primary">{kind}</Badge>
            </div>
            <CardDescription>{desc}</CardDescription>
        </CardHeader>
    </Card>;
}


def PassPill(num: str, name: str, desc: str) -> JsxElement {
    return <div className="flex flex-col gap-1 rounded-xl border border-border/60 bg-card/60 p-4">
        <span className="font-mono text-xs text-primary">{num}</span>
        <span className="font-semibold">{name}</span>
        <span className="text-xs text-muted-foreground">{desc}</span>
    </div>;
}


def TreeRow(path: str, desc: str) -> JsxElement {
    return <div className="flex flex-col gap-0.5 py-1 sm:flex-row sm:gap-6">
        <span className="w-56 shrink-0 whitespace-pre font-mono text-sm text-amber-400/90">{path}</span>
        <span className="text-sm text-muted-foreground">{desc}</span>
    </div>;
}


def StepRow(num: str, title: str, desc: str) -> JsxElement {
    return <div className="flex gap-4">
        <div className="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/15 font-mono text-sm font-bold text-primary">{num}</div>
        <div>
            <p className="font-semibold">{title}</p>
            <p className="text-sm text-muted-foreground">{desc}</p>
        </div>
    </div>;
}


def:pub Architecture() -> JsxElement {
    return <div className="mx-auto max-w-5xl px-6 py-16">
        <Badge variant="outline" className="mb-4 border-primary/40 text-primary">Design Document</Badge>
        <h1 className="mb-4 text-4xl font-bold tracking-tight">The Architecture</h1>
        <p className="mb-12 max-w-3xl text-lg text-muted-foreground">
            The core insight that makes this project beautiful rather than forced:
            Quake was always secretly object-spatial. BSP maps are graphs of areas and
            portals. Entity triggers are graphs of targets. The think loop is an ability
            on a node. QuakePassion just says it out loud — in a language built for it.
        </p>

        <img
            src="/static/assets/arch-graph.svg"
            alt="The world graph: root, Game, World, Areas joined by Portals, Entities joined by Targets"
            className="mb-16 w-full rounded-xl border border-border/60 bg-card/40 p-6"
        />

        <div className="mb-6 flex items-center gap-3">
            <Network className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">The world graph</h2>
        </div>
        <p className="mb-8 max-w-3xl text-muted-foreground">
            Everything hangs off the Jac root node — which means save games come for free
            through graph persistence. The world model is the same for all three games;
            their differences are normalized away at the asset boundary.
        </p>
        <div className="mb-16 grid gap-4 md:grid-cols-2">
            <SchemaCard name="Area" kind="node" desc="A region of the map, born from BSP leafs and clusters. The atom of visibility and spatial queries."/>
            <SchemaCard name="Portal" kind="edge" desc="Connects two Areas. Visibility is a walker flooding through portals from the camera's area."/>
            <SchemaCard name="Entity" kind="node" desc="Doors, monsters, items, players. Lives in an Area via an In edge that moves when it does. Subtypes override behavior."/>
            <SchemaCard name="Targets" kind="edge" desc="Quake's trigger/target chains as first-class typed edges. A button firing a door is a walker traversing this edge."/>
            <SchemaCard name="AssetRegistry" kind="node" desc="Maps, models, textures, sounds — with DependsOn edges so loading a map resolves its whole dependency closure."/>
            <SchemaCard name="Frame passes" kind="walkers" desc="Input, Think, Physics, Triggers, Vis, Render — each tick is a sequence of walkers sweeping the graph."/>
        </div>

        <div className="mb-6 flex items-center gap-3">
            <Footprints className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">A tick in the life</h2>
        </div>
        <p className="mb-8 max-w-3xl text-muted-foreground">
            Fixed-timestep simulation, variable-rate rendering — Quake's classic split,
            expressed as walkers. Entity logic fires as node abilities: every entity type
            answers the ThinkPass in its own way, exactly like Quake's think functions,
            but with inheritance instead of function pointers.
        </p>
        <div className="mb-16 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <PassPill num="01" name="InputPass" desc="Sample raylib input, update player intent."/>
            <PassPill num="02" name="ThinkPass" desc="Every entity's think ability fires — AI, doors, items."/>
            <PassPill num="03" name="PhysicsPass" desc="Quake-style movement: friction, accel, air control, traces."/>
            <PassPill num="04" name="TriggerPass" desc="Fired triggers traverse their Targets edges."/>
            <PassPill num="05" name="VisPass" desc="Flood from the camera's Area through Portal edges."/>
            <PassPill num="06" name="RenderPass" desc="Draw only what VisPass collected, through raylib."/>
        </div>

        <div className="mb-6 flex items-center gap-3">
            <Map className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">Where OSP lives — and where it doesn't</h2>
        </div>
        <div className="mb-16 grid gap-6 md:grid-cols-2">
            <Card className="border-primary/30 bg-card/60">
                <CardHeader>
                    <CardTitle className="text-primary">Walkers and the graph</CardTitle>
                    <CardDescription>Structure, relationships, and orchestration.</CardDescription>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-muted-foreground">
                    <p>· World topology — areas, portals, visibility</p>
                    <p>· Entity relationships — containment, attachment, targeting</p>
                    <p>· Game logic — think, triggers, spawning, game rules</p>
                    <p>· Asset dependency resolution and loading</p>
                    <p>· Save games — the graph persists from root</p>
                </CardContent>
            </Card>
            <Card className="border-border/60 bg-card/60">
                <CardHeader>
                    <CardTitle>Plain objects and math</CardTitle>
                    <CardDescription>Hot loops stay hot. Honesty is part of the design.</CardDescription>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-muted-foreground">
                    <p>· Vec3, Quat, Mat4, Plane, AABB — pure obj types</p>
                    <p>· Collision solving and trace math</p>
                    <p>· Vertex and surface data headed to the GPU</p>
                    <p>· A Quake map has hundreds of entities — walkers handle that easily.</p>
                    <p>· Millions of triangles belong to raylib and the GPU.</p>
                </CardContent>
            </Card>
        </div>

        <div className="mb-6 flex items-center gap-3">
            <FolderTree className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">Repo layout</h2>
        </div>
        <p className="mb-6 max-w-3xl text-muted-foreground">
            Declaration files read as API specs; implementations live in impl files —
            you should understand the whole engine by reading engine/world alone.
        </p>
        <Card className="mb-16 border-border/60 bg-card/60">
            <CardContent className="pt-4">
                <TreeRow path="engine/core/" desc="App lifecycle, game loop, fixed-timestep clock, console and cvars"/>
                <TreeRow path="engine/math/" desc="Vec3, Quat, Mat4, Plane, AABB — pure objects, pure speed"/>
                <TreeRow path="engine/world/" desc="The OSP heart: World, Area, Portal, Entity and the frame-pass walkers"/>
                <TreeRow path="engine/physics/" desc="Quake-style movement, brush collision, traces"/>
                <TreeRow path="engine/render/" desc="The only raylib-facing wall: surfaces, materials, models, camera"/>
                <TreeRow path="engine/audio/" desc="Playback and spatialization"/>
                <TreeRow path="engine/assets/" desc="Engine-native runtime types and the AssetRegistry graph"/>
                <TreeRow path="formats/common/" desc="PAK, PK3, palettes, shared image codecs"/>
                <TreeRow path="formats/q1/" desc="BSP29, MDL, WAD, SPR"/>
                <TreeRow path="formats/q2/" desc="BSP38, MD2, WAL"/>
                <TreeRow path="formats/q3/" desc="BSP46, MD3, shader scripts"/>
                <TreeRow path="games/q1 q2 q3/" desc="Each game stays itself: entities, weapons, movement tuning, HUD"/>
                <TreeRow path="tools/" desc="Asset inspector, format converter, world-graph visualizer"/>
                <TreeRow path="tests/" desc="Jac test blocks — fresh graph per test, perfect for format parsers"/>
            </CardContent>
        </Card>

        <div className="mb-6 flex items-center gap-3">
            <Cpu className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">Runtime decisions</h2>
        </div>
        <div className="mb-16 grid gap-4 md:grid-cols-3">
            <Card className="border-border/60 bg-card/60">
                <CardHeader>
                    <CardTitle className="text-base">Python backend first</CardTitle>
                    <CardDescription>
                        Iterate fast with the raylib bindings. Jac's native backend
                        (llvmlite, proven by the in-repo raylib shooter) is the
                        performance tier waiting when we need it.
                    </CardDescription>
                </CardHeader>
            </Card>
            <Card className="border-border/60 bg-card/60">
                <CardHeader>
                    <CardTitle className="text-base">raylib behind one wall</CardTitle>
                    <CardDescription>
                        All rendering and audio calls confined to engine/render and
                        engine/audio — swapping backends touches nothing else.
                    </CardDescription>
                </CardHeader>
            </Card>
            <Card className="border-border/60 bg-card/60">
                <CardHeader>
                    <CardTitle className="text-base">Fix Jac, not workarounds</CardTitle>
                    <CardDescription>
                        This project exists to stress the language. If an idiom that
                        should work doesn't, we improve jaclang upstream — never
                        contort the engine around it.
                    </CardDescription>
                </CardHeader>
            </Card>
        </div>

        <div className="mb-6 flex items-center gap-3">
            <Rocket className="size-6 text-primary"/>
            <h2 className="text-2xl font-bold tracking-tight">The road to playable</h2>
        </div>
        <div className="mb-8 space-y-6">
            <StepRow num="1" title="Math + PAK/BSP29 parsing" desc="Pure functions, heavily tested. The foundation everything stands on."/>
            <StepRow num="2" title="Render a Quake map" desc="Build the Area/Portal graph from BSP, cull through it, draw with raylib."/>
            <StepRow num="3" title="Player movement" desc="The legendary feel: friction, acceleration, air control, bunny hopping."/>
            <StepRow num="4" title="Entities and triggers" desc="The think loop, Targets edges, doors that open and buttons that fire."/>
            <StepRow num="5" title="Quake playable" desc="The first full game loop — then the IR is proven."/>
            <StepRow num="6" title="Quake II and III slot in" desc="New parsers feeding an already-working engine. One world, three games."/>
        </div>

        <Separator className="mb-8"/>
        <p className="pb-8 text-center text-sm text-muted-foreground">
            The taste test for clean and beautiful: read engine/world alone and
            understand how the whole engine thinks.
        </p>
    </div>;
}
