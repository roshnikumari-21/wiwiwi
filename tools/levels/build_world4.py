"""Builds World 4 "Frosty Peaks" levels with World 3's tools (build_world3.py: hills, two routes,
tree climbs → icy cliff climbs, crates → gift boxes) in the snow look, plus World 4's own pieces:

  ice(length, **flat options)
                 a stretch of slippery ice. It always ends on STOP px of snow (the fair-play rule:
                 she slides ~200 px, so never straight into a gap), and spikes are never put on it.
  flat(..., penguins=[(x, patrol)])
                 sliding penguins: waddle, warn, belly-slide along their whole path
  thin_ice(n)    a lake crossed on n slabs of THIN ICE (crumbling tiles, "ice" look): each cracks
                 the moment she lands and breaks half a second later, so she has to keep hopping
  ice_hill(steps, step, top, **kw)
                 snowy steps up to an ICY hilltop (then its stop-snow), and back down
  slope(n, step, length, slimes={terrace: [...]})
                 the mountainside: n snowy steps up, then n + 1 icy terraces sliding back down
                 (each ends on its stop-snow, then a drop to the next)
  tree_climb(rise, length)  (from World 3) → a glacier cliff climbed on zigzag ledges
  ice_descent(n, step, length, slimes={terrace: [...]})
                 coming back down a glacier: n drops of `step` px, each onto an icy terrace
                 (ending on its stop-snow)
  icicle_arch(length, icicles=[(walkway, every, delay)], low=..., coins=..., yarn=...)
                 World 3's two routes (canopy) with icicles hanging under the high walkways: they
                 warn (shadow), then drop onto the floor route below. Up on the arch they can't reach her.
  ledge_hop(n)   a wide icy river crossed on n narrow snowy ledges (a hop apart, alternately higher)
  sky_route(length, low=..., coins=..., yarn=...)
                 a HIDDEN HIGH ROUTE: a snowy step, then two floating gift boxes as stairs up to
                 walkways far above the ground (SKY px), out of the usual view; the floor below is the
                 normal route (hazards from `low`). Bump the gift boxes from below for a coin each.
  slimes         → blue snow slimes;  crates → gift boxes;  planks → ice floes

Levels are ~1.5x World 3's length (owners, 13 Nov 2026), with a checkpoint about every 5k px and milk
about every 6k px. They are built ONE AT A TIME (owners: "step by step, precisely, every level a little
different") — each level's recipe is added here only when it's designed, checked and played.
Then: tools/make_level_data.gd (catalog) and the fairness + play-through tests.
Run:  python tools/levels/build_world4.py
"""
from build_world3 import ForestLevel

STOP = 400   # snow after every ice stretch (> the 300 px fair-play rule)
SKY = 720        # sky route: the walkways are this far above the floor (step 180, gifts 360 / 540)
ICICLE_HEIGHT = 281   # a falling icicle hangs this far above the floor, tucked under a 360 px walkway
HOP_LEDGE, HOP_GAP, HOP_RISE = 260, 130, 80   # ledge hop: ledge width, water between, every other one higher
TILE_GAP = 120   # thin ice: water between the shore and a slab, and between slabs (a short hop)


class SnowLevel(ForestLevel):
    RES = {
        **ForestLevel.RES,
        "slime": ("PackedScene", "res://scenes/actors/enemies/blue_slime.tscn"),
        "penguin": ("PackedScene", "res://scenes/actors/enemies/penguin.tscn"),
        "crumble": ("PackedScene", "res://scenes/objects/crumble_tile.tscn"),
    }

    def __init__(self, number, name, energy):
        super(ForestLevel, self).__init__(number, name, energy, world=4, theme="snow")

    def flat(self, length, penguins=(), crates=(), **kw):
        x, h = self.x, self.h
        for px, patrol in penguins:
            self._obj("penguin", x + px, h, patrol_distance=float(patrol))
            self.coins((x + px, h - 330))   # a coin high above: rewards a big jump over it
        for cx, lift, coins, milk in crates:   # World 4's bump crates are gift boxes
            self._obj("crate", x + cx, h - lift, coins=coins, milk=milk, look="gift")
        super().flat(length, **kw)

    def ice(self, length, **kw):
        """A slippery ice stretch at the current height, then STOP px of snow to come to a stop on."""
        assert "spikes" not in kw, "no spikes on ice (fair-play)"
        self.block_themes[len(self.blocks)] = "ice"
        self.flat(length, **kw)
        self.flat(STOP)

    def ice_hill(self, steps=2, step=150, top=900, **kw):
        for _ in range(steps):
            self.up(step, 320)
        self.ice(top, **kw)
        for i in range(steps):
            self.down(step, 320 if i < steps - 1 else 400)

    def slope(self, n, step=150, length=900, slimes=None):
        slimes = slimes or {}
        for _ in range(n):
            self.up(step, 320)
        for i in range(n + 1):
            if i:
                self.h += step   # drop to the next terrace
            # coins along the terrace (none near a slime)
            spots = [p for p in range(200, length - 100, 250) if all(abs(p - sx) > 150 for sx, _ in slimes.get(i, ()))]
            self.ice(length, slimes=slimes.get(i, ()), coins=tuple(spots))

    def ice_descent(self, n, step=180, length=600, slimes=None):
        slimes = slimes or {}
        for i in range(n):
            self.h += step
            assert self.h <= 900, "a descent can't go below the ground"
            spots = [p for p in range(200, length - 100, 250) if all(abs(p - sx) > 150 for sx, _ in slimes.get(i, ()))]
            self.ice(length, slimes=slimes.get(i, ()), coins=tuple(spots))

    def icicle_arch(self, length, icicles=(), low=None, coins=5, yarn=False):
        first = len(self.blocks)
        self.canopy(length, low=low, coins=coins, yarn=yarn)
        tag = f"Canopy{self.canopies}_Walk"
        idx = [i for i in sorted(self.tags) if i >= first and self.tags[i].startswith(tag)]
        self.plain.update(idx)   # no decorative icicles here: every icicle under an arch is one that falls
        walks = [self.blocks[i] for i in idx]
        for walk, every, delay in icicles:
            bx, top, w, _, _ = walks[walk]
            self._obj("cone", bx + w // 2, self.h, look="icicle", height=float(ICICLE_HEIGHT),
                      every=float(every), first_delay=float(delay))

    def ledge_hop(self, n):
        assert self.h == 900
        width = HOP_GAP + n * HOP_LEDGE + (n - 1) * HOP_GAP + HOP_GAP
        self._obj("water", self.x, self.h + 100, width=float(width))
        self.hops = getattr(self, "hops", 0) + 1
        for i in range(n):
            lx = self.x + HOP_GAP + i * (HOP_LEDGE + HOP_GAP)
            top = self.h - (HOP_RISE if i % 2 == 0 else 0)
            self.tags[len(self.blocks)] = f"Hop{self.hops}_Ledge{i + 1}"
            self._block(lx, top, HOP_LEDGE, 40, True)
            self.coins((lx + HOP_LEDGE // 2, top - 90))
        self.x += width

    def sky_route(self, length, low=None, coins=5, yarn=False):
        x, h = self.x, self.h
        self.skies = getattr(self, "skies", 0) + 1
        tag = f"Sky{self.skies}"
        self.tags[len(self.blocks)] = f"{tag}_Step"
        self._block(x + 150, h - 180, 220, 40, True)               # a snowy step (one-way)
        for gx, top in ((520, 360), (720, 540)):                   # gift-box stairs (tops 180 px apart)
            self._obj("crate", x + gx, h - top + 104, coins=1, milk=False, look="gift")
        start, end = x + 900, x + length - 350
        pos, n = start, 0
        while pos < end:                                          # walkways with small gaps to hop
            w = min(460, end - pos)
            n += 1
            self.tags[len(self.blocks)] = f"{tag}_Walk{n}"
            self._block(pos, h - SKY, w, 40, True)
            pos += w + 140
        step = (end - start) / max(coins, 1)
        self.coins(*[(round(start + 120 + i * step), h - SKY - 80) for i in range(coins)])
        if yarn:
            self._obj("yarn", end - 120, h - SKY - 120)
        self.flat(length, **(low or {}))

    def thin_ice(self, n):
        """A lake crossed on n slabs of thin ice, level with the shore, a short hop apart."""
        assert self.h == 900
        width = TILE_GAP + n * 300 + (n - 1) * TILE_GAP + TILE_GAP
        self._obj("water", self.x, self.h + 100, width=float(width))
        for i in range(n):
            cx = self.x + TILE_GAP + 150 + i * (300 + TILE_GAP)
            self._obj("crumble", cx, self.h, look="ice")
            self.coins((cx, self.h - 110))
        self.x += width


def level_1():
    L = SnowLevel(1, "Snowy Start", 0.8)   # meet slippery ice, gently: short ice, always snow to stop on
    L.flat(1500, crates=[(700, 200, 2, False)], coins=(300, 420))
    L.ice(900, coins=(200, 400, 600))                      # first ice: short, nothing on it
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.gap(220)
    L.ice(1600, coins=(300, 600, 900, 1200))              # longer ice: just slide and enjoy
    L.flat(1400, milk=300, crates=[(800, 200, 0, True), (906, 200, 3, False)])
    L.planks(2)                                          # ice floes over the frozen lake
    L.flat(1500, slimes=[(500, 80), (1100, 70)], flag=150)
    L.hill(2, 150, 1000, coins=(300, 500, 700))
    L.ice(1300, slimes=[(700, 60)])                       # a slime on the ice: jump it while sliding
    L.flat(1300, flag=150, milk=900)
    L.gap(230)
    L.flat(1200, bridge=(350, 400), yarn=(550, 560))
    L.finish(1100)
    return L


def level_2():
    L = SnowLevel(2, "Penguin Parade", 0.7)   # meet the sliding penguins: one at a time, then pairs
    L.flat(1500, crates=[(700, 200, 2, False)], coins=(300, 420))
    L.flat(1600, penguins=[(900, 200)])                    # the first penguin: watch it waddle, warn, slide
    L.gap(220)
    L.flat(1500, slimes=[(700, 80)], flag=150)
    L.ice(1400, coins=(300, 600, 900, 1200))
    L.flat(1800, penguins=[(480, 150), (1300, 150)])       # two penguins, sliding at different times
    L.planks(2)                                          # ice floes over the frozen lake
    L.flat(1500, milk=300, flag=1000, crates=[(600, 200, 0, True)])
    L.hill(2, 150, 1100, penguins=[(550, 150)])            # a penguin up on the hilltop
    L.ice(1300, slimes=[(700, 60)])
    L.flat(2000, penguins=[(1000, 320)], flag=150)         # the long slide: a whole stretch to time
    L.gap(240)
    L.flat(1300, crates=[(500, 200, 3, False)], bridge=(700, 400), yarn=(900, 560))
    L.finish(1100)
    return L


def level_3():
    L = SnowLevel(3, "Frozen Lake", 0.7)   # out across the lake: floes, bobbing floes and thin ice, island to island
    L.flat(1300, crates=[(700, 200, 2, False)], coins=(300, 420, 540))
    L.thin_ice(2)                                        # meet thin ice: it cracks when she lands, so keep going
    L.flat(1200, slimes=[(700, 80)], flag=150)
    L.planks(2)                                          # drifting floes
    L.flat(450, coins=(225,))                            # a little snowy island in the lake
    L.thin_ice(3)
    L.flat(1400, milk=300, flag=1000, crates=[(650, 200, 3, False)])
    L.ice(1000, coins=(250, 500, 750))
    L.bobbers(2)                                         # floes bobbing in the swell
    L.flat(1500, penguins=[(800, 200)], flag=150)
    L.planks(3)
    L.flat(450, coins=(225,))
    L.thin_ice(4)                                        # the long thin-ice run: no stopping
    L.flat(1300, flag=150, milk=900, crates=[(550, 200, 0, True)])
    L.ice(1200, slimes=[(600, 60)])
    L.flat(1200, penguins=[(600, 150)])
    L.gap(240)
    L.flat(1200, crates=[(450, 200, 3, False)], bridge=(650, 400), yarn=(850, 560))
    L.finish(1100)
    return L


def level_4():
    L = SnowLevel(4, "Slippery Slopes", 0.7)   # up the mountain on snowy steps, slide down icy terraces
    L.flat(1200, crates=[(650, 200, 2, False)], coins=(300, 420))
    L.ice_hill(2, 150, 900, coins=(250, 450, 650))       # a small icy hilltop
    L.flat(1200, slimes=[(600, 80)], flag=150, milk=1000)
    L.slope(2, 150, 900)                                 # the first slope: three icy terraces down
    L.flat(1200, penguins=[(600, 150)])
    L.gap(220)
    L.flat(1300, milk=300, flag=1000, crates=[(600, 200, 3, False)])
    L.planks(2)                                          # floes over a mountain tarn
    L.flat(1300, flag=150, penguins=[(800, 150)])
    L.slope(3, 150, 700, slimes={2: [(400, 50)]})        # the big slope: four terraces, a slime on the third
    L.flat(1200, flag=150, milk=900, crates=[(500, 200, 0, True)])
    L.gap(240)
    L.flat(1200, crates=[(450, 200, 3, False)], bridge=(650, 400), yarn=(850, 560))
    L.finish(1100)
    return L


def level_5():
    L = SnowLevel(5, "Gift Box Grove", 0.75)   # a calm, generous level: gift boxes everywhere, two secret sky routes
    L.flat(1500, crates=[(500, 200, 1, False), (604, 200, 3, False), (708, 200, 1, False)], coins=(330,))
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.sky_route(2600, low={"penguins": [(1300, 200)]}, coins=6)   # the first secret way up
    L.gap(220)
    L.flat(1400, milk=300, flag=1000, crates=[(700, 200, 0, True)])
    L.ice(1200, coins=(300, 600, 900))
    L.flat(1500, crates=[(400, 200, 2, False), (900, 200, 1, False), (1004, 200, 2, False)])
    L.planks(2)
    L.flat(1300, flag=150, penguins=[(800, 150)])
    L.hill(2, 150, 1000, crates=[(500, 200, 3, False)])   # a gift on the hilltop
    L.thin_ice(2)
    L.flat(1300, slimes=[(800, 70)], crates=[(400, 200, 0, True)])
    L.sky_route(3000, low={"slimes": [(1200, 70)], "penguins": [(2100, 150)]}, coins=8, yarn=True)   # the yarn is hidden up here
    L.flat(1200, flag=150, milk=900)
    L.gap(240)
    L.flat(1200, crates=[(400, 200, 2, False), (504, 200, 2, False), (608, 200, 2, False)])
    L.finish(1100)
    return L


def level_6():
    L = SnowLevel(6, "Glacier Climb", 0.7)   # up three glaciers (each taller), across their icy tops, slide down
    L.flat(1300, crates=[(650, 200, 2, False)], coins=(330, 450))
    L.tree_climb(360, 900, coins=(300, 450, 600))        # the first glacier: a short climb
    L.ice_descent(2, 180, 500)                           # ...and down its icy terraces
    L.flat(1300, penguins=[(700, 150)], flag=150)
    L.gap(220)
    L.flat(1000, milk=300, crates=[(650, 200, 3, False)])
    L.tree_climb(540, 800, flag=300)                     # the second glacier: taller
    L.ice(900, coins=(250, 500, 750))                    # an icy glacier top
    L.flat(1000, penguins=[(500, 150)])                  # a penguin up on the glacier
    L.ice_descent(3, 180, 500, slimes={1: [(380, 50)]})
    L.flat(1000, flag=150, milk=700, crates=[(450, 200, 0, True)])
    L.tree_climb(720, 800, flag=300)                     # the great glacier: as tall as a climb gets
    L.ice(1000, coins=(250, 500, 750))
    L.flat(900, yarn=(450, 260), coins=(200, 700))      # the top of the world: the yarn, a jump up
    L.ice_descent(4, 180, 400)                           # four icy terraces all the way down
    L.flat(1000, milk=500)
    L.gap(240)
    L.flat(1100, crates=[(400, 200, 2, False), (504, 200, 2, False)], flag=800)
    L.finish(1100)
    return L


def level_7():
    L = SnowLevel(7, "Icicle Bridge", 0.7)   # falling icicles under icy arches, narrow ledges over icy rivers
    L.flat(1300, crates=[(650, 200, 2, False)], coins=(330, 450))
    L.icicle_arch(2200, icicles=[(1, 0, 0), (2, 0, 0.6)], coins=5)        # meet the icicles: each drops once
    L.flat(1200, slimes=[(700, 80)], flag=150)
    L.ledge_hop(3)                                                        # the first icy river: 3 ledges
    L.flat(1300, milk=300, penguins=[(850, 150)])
    L.icicle_arch(2600, icicles=[(0, 2.5, 0), (2, 2.5, 1.2)], low={"slimes": [(1300, 60)]}, coins=6)   # a slime between two icicles
    L.gap(220)
    L.flat(1300, flag=150, crates=[(700, 200, 0, True)])
    L.ledge_hop(4)
    L.flat(1300, penguins=[(650, 150)])
    L.thin_ice(3)
    L.flat(1200, flag=150, milk=900)
    L.icicle_arch(3000, icicles=[(0, 2.0, 0), (1, 2.0, 1.0), (2, 2.0, 0.5), (3, 2.0, 1.5)],
                  coins=8, yarn=True)                     # the long arch: four icicles in a rhythm
    L.flat(600, coins=(300,))
    L.ledge_hop(5)                                                        # the widest river
    L.flat(1200, flag=150, milk=700)
    L.gap(240)
    L.flat(1100, crates=[(400, 200, 2, False), (504, 200, 2, False)])
    L.finish(1100)
    return L


LEVELS = [level_1, level_2, level_3, level_4, level_5, level_6, level_7]

if __name__ == "__main__":
    for make in LEVELS:
        make().write()
