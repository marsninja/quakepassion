"""QuakePassion — project website. One engine. Three Quakes. Pure Jac."""

cl import from ".components.header" { SiteHeader }
cl import from ".components.footer" { SiteFooter }
cl import from ".pages.home" { Home }
cl import from ".pages.architecture" { Architecture }
cl import from "@jac/runtime" { Router, Routes, Route }
cl import ".global.css";

cl {
    def:pub app() -> JsxElement {
        return <Router>
            <div className="dark min-h-screen bg-background text-foreground antialiased">
                <SiteHeader/>
                <Routes>
                    <Route path="/" element={<Home/>}/>
                    <Route path="/architecture" element={<Architecture/>}/>
                </Routes>
                <SiteFooter/>
            </div>
        </Router>;
    }
}
