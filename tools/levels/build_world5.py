"""Builds World 5 "Sunny Dunes" levels with World 4's tools (build_world4.py: ice-free pieces only —
hills, slopes of steps, glacier-style ruin climbs, sky routes, ledge hops over the oasis, crumbling
tiles) in the desert look, plus World 5's own pieces:

  quicksand(length, **flat options)
                 a stretch of QUICKSAND at the current height (at most 800 px — a tired cat walking
                 straight across never goes under; no spikes on it)
  quick_field(n)  a quicksand valley: n quicksand pools (800 px each, the longest allowed) with small
                 firm-sand islands between them, clay pots and sandstone ledges above the pools to hop
                 along (walking straight through is always safe too)
  crumble_bridge(n), crumble_steps(n, length)
                 weathered sandstone blocks that crumble half a second after she lands: a bridge over
                 the oasis, or a staircase up to a ruin ledge;  ruins_down(steps) comes back down
  tree_climb(rise, length) (World 3) → a sandstone ruin climbed on zigzag ledges
  flat(..., moles=[(x, patrol)], coconuts=[(x, every, delay)])
                 sand moles tunnelling along their path; coconuts hanging above the path (they warn
                 with a shadow, then drop)
  slimes         → sand-yellow slimes;  crates → clay pots;  spikes → cactus spikes;
  planks / bobbers → flying carpets;  water → turquoise oasis

Levels follow World 4's lengths and a little more (~19k → ~30k px), with a checkpoint about every
5k px and milk about every 6k px. They are built ONE AT A TIME (owners: "step by step, precisely,
every level a little different") — each level's recipe is added here only when it's designed,
checked and played. Then: tools/make_level_data.gd (catalog) and the fairness + play-through tests.
Run:  python tools/levels/build_world5.py
"""
from build_world4 import SnowLevel

QUICK_MAX = 800   # the fair-play rule (dev/m1_fairness_test.gd)
POT_LIFT = 140    # quicksand fields: how high the stepping pots float


class DesertLevel(SnowLevel):
    CRATE_LOOK = "pot"
    CRUMBLE_LOOK = "sandstone"
    RES = {
        **SnowLevel.RES,
        "slime": ("PackedScene", "res://scenes/actors/enemies/yellow_slime.tscn"),
        "mole": ("PackedScene", "res://scenes/actors/enemies/mole.tscn"),
    }

    def __init__(self, number, name, energy):
        super(SnowLevel, self).__init__(number, name, energy)   # ForestLevel's set-up...
        self.world, self.theme = 5, "sand"                      # ...in World 5's desert

    def _obj(self, kind, x, y, **props):
        if kind == "spikes":
            props.setdefault("look", "cactus")
        elif kind == "cone":   # World 5's falling hazard is a coconut
            props.setdefault("look", "coconut")
        super()._obj(kind, x, y, **props)

    def flat(self, length, moles=(), coconuts=(), **kw):
        x, h = self.x, self.h
        for mx, patrol in moles:
            self._obj("mole", x + mx, h, patrol_distance=float(patrol))
            self.coins((x + mx, h - 300))   # a coin above its path: rewards a jump over it
        for cx, every, delay in coconuts:
            self._obj("cone", x + cx, h, every=float(every), first_delay=float(delay))
        super().flat(length, **kw)

    def quicksand(self, length, **kw):
        """A stretch of quicksand at the current height (firm sand around it comes from the pieces
        before and after)."""
        assert length <= QUICK_MAX, f"quicksand {length} px is longer than the fair-play {QUICK_MAX}"
        assert "spikes" not in kw, "no spikes on quicksand (fair-play)"
        self.block_themes[len(self.blocks)] = "quicksand"
        self.flat(length, **kw)

    def quick_field(self, n, island=300):
        for i in range(n):
            if i % 2 == 0:   # pots to hop along: 140 px up, so she walks under them (she's 104 tall) and
                             # their lids (244 px up) are an easy jump (a full jump reaches 312)
                self.quicksand(QUICK_MAX, crates=[(200, POT_LIFT, 1, False), (430, POT_LIFT, 1, False), (660, POT_LIFT, 1, False)])
            else:            # a sandstone ledge over the pool, coins along it
                self.quicksand(QUICK_MAX, bridge=(150, 500))
            if i < n - 1:
                self.flat(island, coins=(island // 2,))

    def ice(self, *a, **kw):
        raise NotImplementedError("no ice in the desert")

    def thin_ice(self, *a, **kw):
        raise NotImplementedError("in the desert it's crumble_bridge (weathered sandstone)")

    def crumble_bridge(self, n):
        """Oasis water crossed on n blocks of crumbling sandstone, a short hop apart (World 4's thin ice)."""
        SnowLevel.thin_ice(self, n)

    def crumble_steps(self, n, length, **kw):
        """n crumbling sandstone blocks stepping up to a ruin ledge (n + 1) * 170 px higher, over firm
        sand (World 2's roof-tile staircase): each breaks half a second after she lands."""
        x, h = self.x, self.h
        span = 200 + (n - 1) * 330 + 150 + 120   # the last block ends 120 px before the ledge
        self._block(x, h, span)
        for i in range(n):
            cx, top = x + 200 + i * 330, h - 170 * (i + 1)
            self._obj("crumble", cx, top, look=self.CRUMBLE_LOOK)
            self.coins((cx, top - 90))
        self.x += span
        self.h -= 170 * (n + 1)
        self.flat(length, **kw)

    def ruins_down(self, steps, step=170, length=500, **kw):
        """Down the far side of a ruin: `steps` drops of `step` px, each onto a stretch `length` long."""
        for i in range(steps):
            self.down(step, length, **(kw if i == steps - 1 else {}))


def level_1():
    L = DesertLevel(1, "Sunny Dunes", 0.8)   # meet quicksand gently: short patches first, firm sand all around
    L.flat(1500, crates=[(700, 200, 2, False)], coins=(330, 450))
    L.quicksand(300, coins=(80, 150, 220))               # the first quicksand: just a short patch, nothing on it
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.gap(220)
    L.flat(1400, spikes=[(700, False)], coins=(300, 1100))
    L.quicksand(500, coins=(100, 250, 400))              # a little longer: keep walking (or hop it)
    L.flat(1500, milk=300, flag=1000, crates=[(600, 200, 3, False)])
    L.planks(2)                                          # flying carpets over the oasis
    L.flat(1300, slimes=[(650, 80)])
    L.hill(2, 150, 1000, crates=[(500, 200, 0, True)])   # milk in a pot on the dune top
    L.flat(1200, flag=150, spikes=[(800, True)])
    L.quicksand(700, coins=(150, 350, 550))              # the long one: walking straight across is safe
    L.flat(1300, milk=400, crates=[(800, 200, 2, False)])
    L.gap(240)
    L.flat(1400, slimes=[(700, 80)], flag=150)
    L.quicksand(400, coins=(100, 200, 300))
    L.flat(1300, crates=[(400, 200, 3, False)], bridge=(700, 400), yarn=(900, 560))
    L.finish(1100)
    return L


def level_2():
    L = DesertLevel(2, "Mole Hills", 0.75)   # meet the sand moles: one alone, then pairs, one on a hilltop
    L.flat(1500, crates=[(700, 200, 2, False)], coins=(330, 450))
    L.flat(1800, moles=[(900, 200)])                     # the first mole, alone: watch the mound, the tremble, the pop
    L.gap(220)
    L.flat(1500, slimes=[(700, 80)], flag=150)
    L.quicksand(400, coins=(100, 200, 300))
    L.flat(1900, moles=[(500, 120), (1350, 150)])        # two moles, popping at different times
    L.planks(2)
    L.flat(1400, milk=300, flag=1000, crates=[(600, 200, 3, False)])
    L.hill(2, 150, 1100, moles=[(550, 150)])             # a mole up on the dune top
    L.quicksand(500, coins=(100, 250, 400))
    L.flat(1600, milk=300, moles=[(1000, 200)])
    L.flat(1300, slimes=[(650, 70)], flag=150, spikes=[(1150, False)])
    L.flat(2000, moles=[(600, 150), (1400, 150)])        # the mole hills: a pair along a long stretch
    L.gap(240)
    L.flat(1300, crates=[(500, 200, 2, False)], bridge=(700, 400), yarn=(900, 560))
    L.finish(1100)
    return L


def level_3():
    L = DesertLevel(3, "Palm Oasis", 0.75)   # across the oasis on flying carpets, under the coconut palms
    L.flat(1400, crates=[(700, 200, 2, False)], coins=(330, 450))
    L.flat(1600, coconuts=[(550, 0, 0), (1050, 0, 0.6)])   # meet the coconuts: each drops once, watch the shadow
    L.planks(2)                                          # carpets over the oasis
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.bobbers(2)                                         # carpets bobbing up and down
    L.flat(450, coins=(225,))                            # a little palm island
    L.planks(3)
    L.flat(1500, milk=300, flag=1000, crates=[(600, 200, 3, False)])
    L.quicksand(400, coins=(100, 200, 300))
    L.flat(1800, coconuts=[(400, 2.5, 0), (870, 2.5, 1.2), (1340, 2.5, 0.5)])   # a palm grove: coconuts on a rhythm
    L.diagonal(200, 1300, moles=[(650, 150)])            # a carpet rides up to a higher dune, a mole on top
    L.down(200, 1200, milk=600)
    L.bobbers(3)
    L.flat(1300, flag=150, crates=[(500, 200, 0, True)])
    L.flat(1600, coconuts=[(400, 2.2, 0.4)], moles=[(1150, 120)])
    L.gap(240)
    L.flat(1300, crates=[(500, 200, 2, False)], bridge=(700, 400), yarn=(900, 560))
    L.finish(1100)
    return L


def level_4():
    L = DesertLevel(4, "Quicksand Valley", 0.7)   # long quicksand fields: hop pot to pot, or keep walking
    L.flat(1400, crates=[(700, 200, 2, False)], coins=(330, 450))
    L.quick_field(2)                                     # the first field: two pools, an island between
    L.flat(1400, slimes=[(700, 80)], flag=150)
    L.gap(220)
    L.flat(1500, moles=[(800, 150)], milk=200)
    L.quick_field(3)                                     # three pools
    L.flat(1500, flag=150, crates=[(800, 200, 0, True)])
    L.planks(2)
    L.flat(1300, coconuts=[(500, 2.4, 0)], spikes=[(1000, False)])
    L.hill(2, 150, 1000, slimes=[(500, 60)])
    L.quick_field(4)                                     # the big valley: four pools in a row
    L.flat(1400, flag=150, milk=800)
    L.flat(1700, moles=[(400, 120), (1250, 120)])   # a pair, far enough apart to pass one at a time
    L.quicksand(600, coins=(150, 300, 450))
    L.flat(1300, crates=[(500, 200, 2, False)], bridge=(700, 400), yarn=(900, 560))
    L.finish(1100)
    return L


def level_5():
    L = DesertLevel(5, "Sunset Bazaar", 0.75)   # a market at sunset: pots everywhere, a secret route over the awnings
    L.level_props["sky"] = "sunset"
    L.flat(1500, crates=[(500, 200, 1, False), (604, 200, 3, False), (708, 200, 1, False)], coins=(330,))
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.sky_route(2600, low={"moles": [(1300, 200)]}, coins=6)   # the first secret way up: pot stairs to the awnings
    L.gap(220)
    L.flat(1400, milk=300, flag=1000, crates=[(700, 200, 0, True)])
    L.quicksand(500, crates=[(250, POT_LIFT, 2, False)])
    L.flat(1500, crates=[(400, 200, 2, False), (900, 200, 1, False), (1004, 200, 2, False)])
    L.planks(2)
    L.flat(1400, flag=150, coconuts=[(700, 2.5, 0)])
    L.hill(2, 150, 1000, crates=[(500, 200, 3, False)])   # a pot on the dune top
    L.flat(1300, slimes=[(800, 70)], crates=[(350, 200, 0, True)])
    L.sky_route(3000, low={"slimes": [(1200, 70)], "moles": [(2100, 150)]}, coins=8, yarn=True)   # the yarn is hidden up here
    L.flat(1200, flag=150, milk=900)
    L.quick_field(2)
    L.flat(1200, crates=[(400, 200, 2, False), (504, 200, 2, False), (608, 200, 2, False)])
    L.gap(240)
    L.flat(1000, coins=(300, 500, 700))
    L.finish(1100)
    return L


def level_6():
    L = DesertLevel(6, "Ruins Climb", 0.7)   # up and over the old sandstone ruins, some of it crumbling
    L.level_props["sky"] = "sunset"
    L.flat(1300, crates=[(650, 200, 2, False)], coins=(330, 450))
    L.crumble_bridge(2)                                  # meet crumbling sandstone: pale, cracked, keep moving
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.tree_climb(360, 900, coins=(300, 450, 600))        # the first ruin
    L.ruins_down(2, 180, 500)
    L.flat(1300, moles=[(700, 150)], milk=200)
    L.crumble_steps(2, 1000, coins=(300, 500, 700))      # crumbling steps up to a ruin top
    L.ruins_down(3, 170, 450, flag=150)
    L.quicksand(600, coins=(150, 300, 450))
    L.flat(1300, crates=[(700, 200, 0, True)])
    L.tree_climb(540, 800, flag=300)                     # the tall ruin
    L.flat(1000, coconuts=[(500, 2.4, 0)])               # a palm up on the ruin top
    L.ruins_down(3, 180, 450)
    L.crumble_bridge(3)
    L.flat(1500, moles=[(500, 120), (1200, 120)], flag=150, milk=1350)
    L.crumble_steps(3, 900, yarn=(450, 260))             # the great crumbling stair: the yarn waits on top
    L.ruins_down(4, 170, 400)
    L.gap(240)
    L.flat(1100, crates=[(400, 200, 2, False), (504, 200, 2, False)], flag=800)
    L.finish(1100)
    return L


def level_7():
    L = DesertLevel(7, "Carpet Ride", 0.7)   # across a deep canyon river on long chains of flying carpets
    L.flat(1300, crates=[(650, 200, 2, False)], coins=(330, 450))
    L.planks(3)
    L.flat(400, coins=(200,))                            # a tiny ledge of rock between the chains
    L.bobbers(3)
    L.flat(1300, slimes=[(700, 80)], flag=150)
    L.planks(4)
    L.flat(400, coins=(200,))
    L.planks(4)                                          # two long chains, one after the other
    L.flat(1400, moles=[(800, 150)], milk=200, flag=1250)
    L.diagonal(200, 1200, coconuts=[(600, 2.4, 0)])      # a carpet rides up to a higher rock, a palm on top
    L.down(200, 1000)
    L.bobbers(4)
    L.flat(400, coins=(200,))
    L.planks(5)                                          # the great carpet ride: five in a row...
    L._obj("yarn", L.x - 1180, L.h - 260)                # ...with the yarn floating above the middle one
    L.flat(1400, flag=150, milk=900, crates=[(500, 200, 3, False)])
    L.lift(360, 1000, moles=[(550, 120)])                 # a carpet lift up the canyon wall
    L.ruins_down(2, 180, 500)
    L.quicksand(500, coins=(150, 250, 350))
    L.flat(1000, slimes=[(500, 70)])
    L.bobbers(3)
    L.flat(1300, crates=[(400, 200, 2, False), (504, 200, 2, False)], flag=900)
    L.finish(1100)
    return L


def level_8():
    L = DesertLevel(8, "Cactus Canyon", 0.7)   # the grand tour: every World 5 idea once more, cactus spikes everywhere
    L.flat(1300, crates=[(650, 200, 2, False)], coins=(330, 450))
    L.flat(1500, spikes=[(450, False), (1050, True)])    # the canyon floor bristles with cacti
    L.hill(2, 150, 1000, moles=[(500, 150)])             # a mole on the dune top
    L.quicksand(600, coins=(150, 300, 450))
    L.flat(1300, flag=150, spikes=[(800, True)])
    L.planks(3)
    L.flat(1600, coconuts=[(400, 2.4, 0), (900, 2.4, 1.2)])   # a palm grove
    L.crumble_bridge(3)
    L.flat(1300, milk=300, flag=1000, crates=[(600, 200, 3, False)])
    L.tree_climb(540, 900, spikes=[(600, False)])        # a canyon wall, cacti on top
    L.ruins_down(3, 180, 450)
    L.quick_field(2)
    L.flat(1600, moles=[(420, 100), (1100, 100)], flag=150)
    L.bobbers(3)
    L.flat(1300, slimes=[(500, 80)], spikes=[(1100, True)], milk=150)
    L.sky_route(2600, low={"spikes": [(600, True), (2000, True)], "moles": [(1300, 120)]}, coins=7, yarn=True)   # up over the cactus field
    L.flat(1200, flag=150)
    L.gap(240)
    L.flat(1100, crates=[(400, 200, 2, False), (504, 200, 0, True)])
    L.finish(1100)
    return L


LEVELS = [level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8]

if __name__ == "__main__":
    for make in LEVELS:
        make().write()
