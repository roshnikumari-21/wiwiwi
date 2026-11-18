"""Builds World 5 "Sunny Dunes" levels with World 4's tools (build_world4.py: ice-free pieces only —
hills, slopes of steps, glacier-style ruin climbs, sky routes, ledge hops over the oasis, crumbling
tiles) in the desert look, plus World 5's own pieces:

  quicksand(length, **flat options)
                 a stretch of QUICKSAND at the current height (at most 800 px — a tired cat walking
                 straight across never goes under; no spikes on it)
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


class DesertLevel(SnowLevel):
    CRATE_LOOK = "pot"
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

    def ice(self, *a, **kw):
        raise NotImplementedError("no ice in the desert")

    def thin_ice(self, *a, **kw):
        raise NotImplementedError("World 5 crumbling sandstone comes later (ruins levels)")


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


LEVELS = [level_1, level_2, level_3]

if __name__ == "__main__":
    for make in LEVELS:
        make().write()
