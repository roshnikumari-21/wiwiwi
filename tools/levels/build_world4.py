"""Builds World 4 "Frosty Peaks" levels with World 3's tools (build_world3.py: hills, two routes,
tree climbs → icy cliff climbs, crates → gift boxes) in the snow look, plus World 4's own pieces:

  ice(length, **flat options)
                 a stretch of slippery ice. It always ends on STOP px of snow (the fair-play rule:
                 she slides ~200 px, so never straight into a gap), and spikes are never put on it.
  flat(..., penguins=[(x, patrol)])
                 sliding penguins: waddle, warn, belly-slide along their whole path
  thin_ice(n)    a lake crossed on n slabs of THIN ICE (crumbling tiles, "ice" look): each cracks
                 the moment she lands and breaks half a second later, so she has to keep hopping
  slimes         → blue snow slimes;  crates → gift boxes;  planks → ice floes

Levels are ~1.5x World 3's length (owners, 13 Nov 2026), with a checkpoint about every 5k px and milk
about every 6k px. They are built ONE AT A TIME (owners: "step by step, precisely, every level a little
different") — each level's recipe is added here only when it's designed, checked and played.
Then: tools/make_level_data.gd (catalog) and the fairness + play-through tests.
Run:  python tools/levels/build_world4.py
"""
from build_world3 import ForestLevel

STOP = 400   # snow after every ice stretch (> the 300 px fair-play rule)
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


LEVELS = [level_1, level_2, level_3]

if __name__ == "__main__":
    for make in LEVELS:
        make().write()
