class_name Layers
## Physics layer bits, matching Project Settings > Layer Names > 2D Physics.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const MONSTERS := 1 << 2
const PICKUPS := 1 << 3
## Ponds: stop whoever walks, not shots nor sight.
const WATER := 1 << 4
