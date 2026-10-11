"""What of a scene is off the grid. Declarations live in scene.jac."""

impl Scene.off_grid(size: float = 8.0) -> int {
    grid = size if size > 0.0 else 1.0;
    count = 0;
    for item in self.items() {
        at = item.origin();
        if at is not None {
            snapped = Vec3(
                x=float(round(at.x / grid)) * grid, y=float(round(at.y / grid)) * grid, z=float(round(at.z / grid)) * grid
            );
            if snapped.sub(at).length() > 0.0001 {
                count += 1;
            }
        }
    }
    for solid in self.solids() {
        astray = False;
        for corner in brush_corners(solid.sides) {
            snapped = Vec3(
                x=float(round(corner.x / grid)) * grid,
                y=float(round(corner.y / grid)) * grid,
                z=float(round(corner.z / grid)) * grid
            );
            if snapped.sub(corner).length() > 0.0001 {
                astray = True;
            }
        }
        if astray {
            count += 1;
        }
    }
    return count;
}
