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
        n = -(-rise // LEDGE_UP) - 1                              # ledges, spaced evenly: every hop the same,
        up = rise / (n + 1)                                       # at most LEDGE_UP, the last one onto the cliff
        span = 120 + LEDGE_W + 160 + LEDGE_W + 140               # floor in front of the cliff
        self._block(x, h, span)
        self.climbs = getattr(self, "climbs", 0) + 1
        for i in range(n):
            # zigzag left / right, always ending on the right ledge, beside the cliff
            right = (n - 1 - i) % 2 == 0
            lx = x + 120 + (LEDGE_W + 160 if right else 0)
            self.tags[len(self.blocks)] = f"Climb{self.climbs}_Ledge{i + 1}"
            self._block(lx, round(h - up * (i + 1)), LEDGE_W, 40, True)
            self.coins((lx + LEDGE_W // 2, round(h - up * (i + 1)) - 70))
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


def level_1():
    L = ForestLevel(1, "Into the Woods", 0.8)   # meet the bump crates (easy)
    L.flat(1300, crates=[(600, 200, 1, False), (706, 200, 1, False), (812, 200, 1, False)], coins=(300,))
    L.hill(2, 150, 900, crates=[(450, 200, 3, False)])
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.gap(220)
    L.flat(1300, crates=[(450, 0, 0, False), (700, 200, 0, True)], coins=(1000, 1120))
    L.planks(1)
    L.flat(1200, mushroom=600, yarn=(600, 780))
    L.hill(1, 150, 700, coins=(250, 400))
    L.finish()
    return L


def level_2():
    L = ForestLevel(2, "Hedgehog Hollow", 0.7)   # meet the hedgehog: jump over, don't stomp
    L.flat(1500, hedgehogs=[(900, 0)], coins=(300,))
    L.gap(220)
    L.flat(1400, hedgehogs=[(700, 70)], flag=150)
    L.hill(2, 150, 1000, hedgehogs=[(500, 60)])
    L.flat(1300, crates=[(500, 200, 3, False)], milk=1000)
    L.planks(2)
    L.flat(1600, hedgehogs=[(500, 60)], slimes=[(1150, 70)], flag=150)
    L.gap(240)
    L.flat(1100, crates=[(500, 0, 0, False)], bridge=(350, 400), yarn=(550, 560))
    L.finish()
    return L


def level_3():
    L = ForestLevel(3, "Canopy Walk", 0.6)   # the first high / low route, yarn up in the trees
    L.flat(1300, crates=[(600, 200, 2, False)], coins=(300,))
    L.canopy(2600, low={"hedgehogs": [(1100, 60)], "slimes": [(1900, 70)]}, coins=6, yarn=True)
    L.flat(1300, flag=150, milk=700)
    L.gap(240)
    L.hill(2, 150, 1000, hedgehogs=[(500, 60)])
    L.canopy(2200, low={"slimes": [(1200, 80)]}, coins=5)
    L.flat(900, coins=(300,))
    L.finish()
    return L


def level_4():
    L = ForestLevel(4, "Pinecone Path", 0.6)   # meet the pinecones, one at a time with clear shadows
    L.flat(1600, cones=[(900, 0, 0)], coins=(300,))
    L.flat(1500, cones=[(700, 0, 0)], crates=[(1200, 200, 2, False)], flag=150)
    L.gap(230)
    L.flat(1600, cones=[(600, 2.6, 0.0)], milk=1200)
    L.hill(2, 150, 1100, cones=[(550, 2.4, 0.0)])
    L.planks(2)
    L.flat(1700, cones=[(500, 2.4, 0.0)], hedgehogs=[(1150, 60)], flag=150)
    L.gap(240)
    L.flat(1100, mushroom=550, yarn=(550, 780))
    L.finish()
    return L


def level_5():
    L = ForestLevel(5, "Mushroom Grove", 0.5)   # a long chain of bouncy mushrooms, up and across
    L.flat(1300, mushroom=650, coins=(300,))
    L.mushroom_up(380, 1000, crates=[(500, 200, 2, False)], flag=200)
    L.mushroom_up(300, 1100, hedgehogs=[(600, 60)], yarn=(600, 380))
    L.down(680, 1300, milk=300, cones=[(900, 0, 0)])
    L.gap(240)
    L.flat(1400, mushroom=450, slimes=[(1000, 70)], flag=150)
    L.mushroom_up(400, 1200, coins=(300, 450, 600))
    L.down(400, 1200, mushroom=600)
    L.planks(2)
    L.flat(900, coins=(300,))
    L.finish()
    return L


def level_6():
    L = ForestLevel(6, "Log Raft River", 0.5)   # a long ride over the stream on log rafts
    L.flat(1300, crates=[(600, 200, 2, False)], coins=(300,))
    L.planks(3)
    L.flat(1400, hedgehogs=[(700, 60)], flag=150)
    L.bobbers(3)
    L.flat(1300, milk=400, cones=[(900, 0, 0)])
    L.planks(4)
    L.flat(1500, slimes=[(500, 70)], hedgehogs=[(1050, 60)], flag=150)
    L.diagonal(200, 1300, crates=[(600, 200, 3, False)])
    L.down(200, 1100)
    L.bobbers(2)
    L.flat(1100, bridge=(350, 400), yarn=(550, 560))
    L.finish()
    return L


def level_7():
    L = ForestLevel(7, "The Great Oak", 0.5)   # climb a giant tree, run along its branches
    L.flat(1300, hedgehogs=[(800, 60)], coins=(300,))
    L.tree_climb(540, 600, flag=150)
    L.canopy(2400, low={"hedgehogs": [(1200, 60)]}, coins=6, yarn=True)
    L.flat(800, milk=300)
    L.down(540, 1300, cones=[(700, 2.4, 0.0)])
    L.tree_climb(700, 1200, crates=[(600, 200, 3, False)], flag=150)
    L.down(700, 1300, slimes=[(700, 70)])
    L.gap(240)
    L.finish()
    return L


def level_8():
    L = ForestLevel(8, "Misty Glade", 0.4)   # everything mixed
    L.flat(1400, cones=[(800, 0, 0)], coins=(300,))
    L.hill(2, 150, 1100, hedgehogs=[(550, 60)])
    L.planks(3)
    L.flat(1400, crates=[(400, 200, 2, False)], slimes=[(1000, 70)], flag=150)
    L.canopy(2400, low={"cones": [(2250, 2.2, 0.0)], "hedgehogs": [(1000, 60)]}, coins=6, yarn=True)
    L.flat(1000, milk=400)
    L.tree_climb(540, 1300, hedgehogs=[(800, 60)], flag=150)
    L.down(540, 1200, cones=[(700, 2.4, 0.4)])
    L.bobbers(3)
    L.flat(900, coins=(300, 450))
    L.finish()
    return L


def level_9():
    L = ForestLevel(9, "Thorn Thicket", 0.4)   # the hardest: pinecone rhythms, hedgehogs, two routes
    L.flat(1500, hedgehogs=[(600, 60)], cones=[(1100, 2.2, 0.0)])
    L.gap(250)
    L.hill(2, 150, 1300, cones=[(400, 2.0, 0.0)], hedgehogs=[(900, 60)])
    L.planks(4)
    L.flat(1600, slimes=[(500, 70)], cones=[(1100, 2.0, 0.5)], flag=150)
    L.canopy(2800, low={"hedgehogs": [(700, 60), (1500, 60)], "cones": [(2620, 2.0, 0.0)]}, coins=7, yarn=True)
    L.flat(1200, milk=400, spikes=[(900, False)])
    L.tree_climb(700, 1300, hedgehogs=[(700, 60)], flag=150)
    L.down(700, 1300, cones=[(500, 2.0, 0.0)], crates=[(1000, 200, 3, False)])
    L.bobbers(3)
    L.flat(1500, spikes=[(600, True)], milk=1200)
    L.gap(260)
    L.finish()
    return L


def level_10():
    L = ForestLevel(10, "Forest Home", 0.8)   # calm finale: the big reunion and "World 3 complete"
    L.flat(1300, crates=[(600, 200, 3, False)], coins=(300,))
    L.hill(1, 150, 900, coins=(300, 450, 600))
    L.planks(2)
    L.flat(1400, hedgehogs=[(700, 60)], flag=150)
    L.canopy(2200, coins=6, yarn=True)
    L.flat(1000, milk=400, mushroom=800)
    L.bobbers(2)
    L.flat(1000, crates=[(400, 200, 2, False)])
    L.gap(220)
    L.finish(1600, coins=(150, 300, 450, 600, 750, 900, 1050, 1200))   # a calm walk home to her
    return L


if __name__ == "__main__":
    demo().write()
    for make in [level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10]:
        make().write()
