"""Builds World 2 "Sunset Town" levels 2-1 .. 2-10 with the World 1 segment recipes (build_world1.py)
in the town look, plus World 2's two new things (plan.md §11 M3, "one new hazard + one new enemy"):

  hoppers        - flat(..., hoppers=[(x, patrol)]): purple slimes that hop along their path
  crumble_steps  - a staircase of crumbling roof tiles up to a ledge too high to jump, with safe
                   ground under it (fall off = try again, no heart lost)
  crumble_bridge - crumbling roof tiles over the canal, hopped one after another

A hopper's harmful area is wider than a slime's: it can hop hop_length (150 px) past its path, so the
fairness rules count patrol + 200 px each way (dev/m1_fairness_test.gd).
Then: tools/make_level_data.gd (catalog) and the fairness + play-through tests.
Run:  python tools/levels/build_world2.py
"""
from build_world1 import RES, Level

STEP_UP = 170          # crumble steps: each tile this much higher than the last (a jump reaches 300)
STEP_ACROSS = 330      # ...and this far along (tiles are 300 wide: a 30 px gap)
TILE_GAP = 120         # crumble bridge: water between the shore and a tile, and between tiles


class TownLevel(Level):
    RES = {
        **RES,
        "slime": ("PackedScene", "res://scenes/actors/enemies/orange_slime.tscn"),   # World 2's slimes are orange
        "hopper": ("PackedScene", "res://scenes/actors/enemies/hopper_slime.tscn"),
        "crumble": ("PackedScene", "res://scenes/objects/crumble_tile.tscn"),
    }

    def __init__(self, number, name, energy):
        super().__init__(number, name, energy, world=2, theme="town")

    def flat(self, length, hoppers=(), **kw):
        """As World 1's flat, plus hoppers: (x, patrol) with a coin high above each."""
        for hx, patrol in hoppers:
            self._obj("hopper", self.x + hx, self.h, patrol_distance=float(patrol))
            self.coins((self.x + hx, self.h - 330))
        super().flat(length, **kw)

    def crumble_steps(self, n, length, **kw):
        """n crumbling tiles stepping up to a ledge (n + 1) * STEP_UP px higher, over safe ground."""
        x, h = self.x, self.h
        span = 200 + (n - 1) * STEP_ACROSS + 150 + 120   # the last tile ends 120 px before the ledge
        self._block(x, h, span)
        for i in range(n):
            cx, top = x + 200 + i * STEP_ACROSS, h - STEP_UP * (i + 1)
            self._obj("crumble", cx, top)
            self.coins((cx, top - 90))
        self.x += span
        self.h -= STEP_UP * (n + 1)
        self.flat(length, **kw)

    def crumble_bridge(self, n):
        """Canal crossed on n crumbling tiles level with the street (a short hop to each)."""
        assert self.h == 900
        width = TILE_GAP + n * 300 + (n - 1) * TILE_GAP + TILE_GAP
        self._obj("water", self.x, self.h + 100, width=float(width))
        for i in range(n):
            cx = self.x + TILE_GAP + 150 + i * (300 + TILE_GAP)
            self._obj("crumble", cx, self.h)
            self.coins((cx, self.h - 110))
        self.x += width


def level_1():
    L = TownLevel(1, "Rooftop Welcome", 0.8)
    L.flat(1300, coins=(400, 520, 640))
    L.crumble_steps(2, 1100, coins=(250, 400, 550))   # meet the roof tiles: safe ground below
    L.down(510, 1300, flag=150, spikes=[(800, False)])
    L.gap(220)
    L.flat(1400, slimes=[(700, 80)], milk=250)
    L.crumble_steps(3, 1000, yarn=(500, 260))
    L.down(680, 1300, coins=(300, 450, 600))
    L.planks(1)
    L.flat(1000, coins=(300,))
    L.finish()
    return L


def level_2():
    L = TownLevel(2, "Chimney Hop", 0.6)
    L.flat(1300, coins=(400, 520))
    L.crumble_bridge(2)
    L.flat(1400, slimes=[(700, 80)], flag=150)
    L.crumble_steps(2, 1300, slimes=[(700, 70)])
    L.down(510, 1300, milk=300, spikes=[(850, True)])
    L.crumble_bridge(3)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.gap(240)
    L.flat(1000, mushroom=500, yarn=(500, 780))
    L.finish()
    return L


def level_3():
    L = TownLevel(3, "Canal Crossing", 0.5)   # familiar planks: a calmer level between new things
    L.flat(1300, spikes=[(800, False)], coins=(400,))
    L.planks(2)
    L.flat(1400, slimes=[(600, 80)], flag=150)
    L.bobbers(2)
    L.flat(1300, milk=300, coins=(700, 820))
    L.lift(380, 1300, slimes=[(800, 90)], bridge=(250, 400), yarn=(450, 560))
    L.down(380, 1200, spikes=[(650, False)])
    L.planks(3)
    L.flat(1300, flag=150, slimes=[(700, 80)])
    L.gap(250)
    L.finish()
    return L


def level_4():
    L = TownLevel(4, "Market Street", 0.6)   # meet the hopper
    L.flat(1500, hoppers=[(900, 0)], coins=(400, 520))
    L.gap(220)
    L.flat(1500, hoppers=[(750, 60)], flag=150)
    L.crumble_bridge(2)
    L.flat(1600, hoppers=[(550, 40)], slimes=[(1220, 70)], milk=200)
    L.crumble_steps(2, 1200, hoppers=[(700, 40)])
    L.down(510, 1200, mushroom=600, yarn=(600, 780))
    L.planks(2)
    L.flat(1600, hoppers=[(700, 40)], flag=150, coins=(1300,))
    L.finish()
    return L


def level_5():
    L = TownLevel(5, "Clock Tower", 0.5)
    L.flat(1300, spikes=[(800, True)], coins=(400,))
    L.lift(400, 1300, hoppers=[(700, 40)], flag=200)
    L.down(400, 1200, milk=250, coins=(600, 720))
    L.crumble_bridge(3)
    L.flat(1500, slimes=[(500, 80), (1100, 70)], flag=150)
    L.crumble_steps(3, 1100, yarn=(550, 300))
    L.down(680, 1300, spikes=[(700, False)])
    L.planks(2)
    L.flat(900, coins=(300, 450))
    L.finish()
    return L


def level_6():
    L = TownLevel(6, "Hopper Square", 0.6)
    L.flat(1900, hoppers=[(600, 40), (1400, 0)], coins=(300,))
    L.gap(240)
    L.flat(1500, mushroom=700, flag=150)
    L.mushroom_up(380, 1300, hoppers=[(700, 40)])
    L.down(380, 1300, slimes=[(700, 80)], milk=200)
    L.crumble_bridge(2)
    L.flat(1900, hoppers=[(600, 40), (1400, 0)], flag=150)
    L.bobbers(2)
    L.flat(1400, slimes=[(700, 80)], milk=250)
    L.gap(250)
    L.flat(1000, mushroom=500, yarn=(500, 780))
    L.finish()
    return L


def level_7():
    L = TownLevel(7, "Bell Rooftops", 0.4)
    L.flat(1300, spikes=[(800, False)], coins=(400,))
    L.crumble_steps(2, 1300, hoppers=[(700, 40)], flag=200)
    L.down(510, 1100, milk=250)
    L.planks(2)
    L.flat(1700, slimes=[(500, 80)], hoppers=[(1200, 40)])
    L.crumble_bridge(3)
    L.flat(1400, spikes=[(700, True)], flag=150)
    L.lift(400, 1400, hoppers=[(800, 40)], bridge=(250, 400), yarn=(450, 560))
    L.down(400, 1200, milk=200)
    L.gap(260)
    L.finish()
    return L


def level_8():
    L = TownLevel(8, "Long Canal", 0.5)
    L.flat(1300, hoppers=[(800, 0)], coins=(300,))
    L.planks(3)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.crumble_bridge(3)
    L.flat(1900, hoppers=[(600, 40), (1400, 0)], milk=200)
    L.bobbers(3)
    L.flat(1500, spikes=[(700, True)], flag=150)
    L.diagonal(200, 1300, hoppers=[(700, 40)])
    L.down(200, 1100, mushroom=550, yarn=(550, 780))
    L.planks(2)
    L.flat(800)
    L.finish()
    return L


def level_9():
    L = TownLevel(9, "Sunset Run", 0.4)   # the hardest
    L.flat(1700, spikes=[(600, False)], hoppers=[(1200, 0)])
    L.crumble_bridge(3)
    L.flat(1500, slimes=[(500, 80), (1100, 70)], flag=150)
    L.crumble_steps(3, 1200, hoppers=[(700, 40)])
    L.down(680, 1200, milk=250)
    L.planks(3)
    L.flat(1900, hoppers=[(600, 40), (1400, 0)], flag=150)
    L.crumble_bridge(4)
    L.flat(1500, spikes=[(700, True)], milk=200)
    L.lift(400, 1500, slimes=[(500, 80), (1100, 80)], bridge=(250, 400), yarn=(450, 560))
    L.down(400, 1100, spikes=[(650, False)])
    L.gap(260)
    L.finish()
    return L


def level_10():
    L = TownLevel(10, "Home Street", 0.8)   # calm finale: the big reunion and "World 2 complete"
    L.flat(1300, mushroom=650, coins=(400, 520))
    L.crumble_bridge(2)
    L.flat(1500, hoppers=[(750, 40)], flag=150)
    L.planks(2)
    L.flat(1300, milk=250, coins=(600, 720, 840))
    L.crumble_steps(2, 1300, bridge=(350, 600), yarn=(650, 560))
    L.down(510, 1300, slimes=[(700, 80)], flag=150)
    L.bobbers(2)
    L.flat(1000, mushroom=500)
    L.gap(220)
    L.finish(1600, coins=(150, 300, 450, 600, 750, 900, 1050, 1200))   # a calm walk home to her
    return L


if __name__ == "__main__":
    for make in [level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10]:
        make().write()
