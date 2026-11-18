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


LEVELS = []

if __name__ == "__main__":
    for make in LEVELS:
        make().write()
