"""The studio's tools that live in modules of their own, listed in one
place. main.jac gives them to the studio once it is attached; neither the
studio nor this list imports the other."""
import from editor.tools.host { StudioTool }
import from editor.tools.camproutes { CampRoutes }
import from editor.tools.paths { Paths }
import from editor.tools.textures { TextureWriter }
import from editor.tools.packer { Packer }
import from editor.tools.makers { Makers }
import from editor.tools.starter { Starter }
import from editor.tools.moving { MovingPictures }
import from editor.tools.scripts { Scripts }

"""The tools, in the order the studio is to ask them."""
def studio_tools -> list[StudioTool] {
    return [CampRoutes(), Paths(), TextureWriter(), Packer(), Makers(), Starter(), MovingPictures(), Scripts()];
}
