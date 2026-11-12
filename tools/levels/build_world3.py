"""Builds World 3 "Whispering Forest" levels with the World 1 segment recipes (build_world1.py) in the
forest look, plus World 3's new pieces and the level tools from plan.md §13.3 (reusable later):

  flat(..., hedgehogs=[(x, patrol)], cones=[(x, every, delay)], crates=[(x, lift, coins, milk)])
                 hedgehogs can't be stomped (jump over); pinecones warn, then drop (every > 0 = again
                 and again); bump crates float `lift` px above the ground (0 = standing on it)
  hill(steps, step, top)
                 ground that steps up and back down again (terrain shape, not one flat strip)
  canopy(length, low=..., coins=..., yarn=...)
                 TWO ROUTES over one stretch: a safe-ish low route on the forest floor (with hazards)
                 and a high route on wooden walkways up in the trees, reached by two steps at the
                 start, with more coins (and maybe the yarn); you drop back down at its end
  tree_climb(rise, length)
                 a tall cliff (up to ~720 px) climbed on walkway ledges that zigzag up in front of it
                 (each 180 px higher than the last), then a stretch on top

Then: tools/make_level_data.gd (catalog) and the fairness + play-through tests.
Run:  python tools/levels/build_world3.py
"""
from pathlib import Path

from build_world1 import RES, Level

LEDGE_UP = 180        # tree climb: each ledge this much higher (a jump reaches ~300)
LEDGE_W = 220
HIGH = 360            # canopy: the high route's walkways are this far above the floor
STEP_UP = 180         # canopy: the two entry steps


class ForestLevel(Level):
    RES = {
        **RES,
        "hedgehog": ("PackedScene", "res://scenes/actors/enemies/hedgehog.tscn"),
        "cone": ("PackedScene", "res://scenes/objects/pinecone.tscn"),
        "crate": ("PackedScene", "res://scenes/objects/bump_crate.tscn"),
    }

    def __init__(self, number, name, energy):
        super().__init__(number, name, energy, world=3, theme="forest")

    def flat(self, length, hedgehogs=(), cones=(), crates=(), **kw):
        x, h = self.x, self.h
        for hx, patrol in hedgehogs:
            self._obj("hedgehog", x + hx, h, patrol_distance=float(patrol))
            self.coins((x + hx, h - 330))   # a coin high above: rewards a big jump over it
        for cx, every, delay in cones:
            # Fair-play: never under a walkway or ledge (its shadow is on the floor, not up there).
            assert not any(bx - 100 < x + cx < bx + bw + 100 and top < h and one_way
                           for bx, top, bw, _, one_way in self.blocks), f"pinecone at {x + cx} is under a ledge"
            self._obj("cone", x + cx, h, every=float(every), first_delay=float(delay))
        for cx, lift, coins, milk in crates:
            self._obj("crate", x + cx, h - lift, coins=coins, milk=milk)
        super().flat(length, **kw)

    def hill(self, steps=2, step=150, top=900, **kw):
        """Steps up `steps` times, a stretch on top (hazards etc. go there), and back down."""
        for _ in range(steps):
            self.up(step, 320)
        self.flat(top, **kw)
        for i in range(steps):
            self.down(step, 320 if i < steps - 1 else 400)

    def canopy(self, length, low=None, coins=4, yarn=False):
        """Two routes over `length` px: the floor (hazards from `low`, a dict of flat() options) and
        walkways HIGH px up, reached by two steps at the start, with `coins` coins (+ the yarn)."""
        x, h = self.x, self.h
        self.canopies = getattr(self, "canopies", 0) + 1
        tag = f"Canopy{self.canopies}"
        self.tags[len(self.blocks)] = f"{tag}_Step"
        self._block(x + 150, h - STEP_UP, 220, 40, True)          # entry step, then the walkways
        start, end = x + 470, x + length - 350
        pos, n = start, 0
        while pos < end:                                          # walkways with small gaps to hop
            w = min(460, end - pos)
            n += 1
            self.tags[len(self.blocks)] = f"{tag}_Walk{n}"
            self._block(pos, h - HIGH, w, 40, True)
            pos += w + 140
        step = (end - start) / max(coins, 1)
        self.coins(*[(round(start + 120 + i * step), h - HIGH - 80) for i in range(coins)])
        if yarn:
            self._obj("yarn", end - 120, h - HIGH - 120)
        self.flat(length, **(low or {}))

    def tree_climb(self, rise, length, **kw):
        """A cliff `rise` px high (more than a jump), climbed on ledges zigzagging up in front of it."""
        assert rise > 220 and rise <= 720
        x, h = self.x, self.h
        n = -(-(rise - 150) // LEDGE_UP)                          # ledges needed so the top one is <= 150 below
        span = 120 + LEDGE_W + 160 + LEDGE_W + 140               # floor in front of the cliff
        self._block(x, h, span)
        self.climbs = getattr(self, "climbs", 0) + 1
        for i in range(n):
            # zigzag left / right, always ending on the right ledge, beside the cliff
            right = (n - 1 - i) % 2 == 0
            lx = x + 120 + (LEDGE_W + 160 if right else 0)
            self.tags[len(self.blocks)] = f"Climb{self.climbs}_Ledge{i + 1}"
            self._block(lx, h - LEDGE_UP * (i + 1), LEDGE_W, 40, True)
            self.coins((lx + LEDGE_W // 2, h - LEDGE_UP * (i + 1) - 70))
        self.x += span
        self.h -= rise
        self.flat(length, **kw)


def demo():
    """Dev only (dev/forest_tools_demo.tscn): every new tool once, to look at and to test."""
    L = ForestLevel(0, "Tools Demo", 1.0)
    L.out_path = Path(__file__).resolve().parents[2] / "dev" / "forest_tools_demo.tscn"
    L.flat(1000, crates=[(500, 200, 3, False), (606, 200, 0, True)], coins=(250,))
    L.flat(1400, hedgehogs=[(700, 80)], flag=150)
    L.hill(2, 150, 900, cones=[(450, 2.5, 0.0)])
    L.canopy(2200, low={"hedgehogs": [(900, 60)]}, coins=5, yarn=True)
    L.flat(900, cones=[(450, 2.2, 0.6)])
    L.tree_climb(540, 1000, coins=(400, 520))
    L.down(540, 900)
    L.finish()
    return L


if __name__ == "__main__":
    demo().write()
