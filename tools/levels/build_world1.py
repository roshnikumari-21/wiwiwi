"""Builds World 1 levels 1-2 .. 1-10 from short recipes of segments (1-1 is the hand-made tutorial).

Each level is a list of segments laid left to right; the builder keeps the cursor and ground height
and writes scenes/levels/w1/level_w1_XX.tscn. Then run tools/make_level_data.gd (catalog) and the
fairness + path checks (dev/m1_fairness_test.gd).

Physics the numbers rely on (player.gd): full jump rises ~300 px and travels ~395 px; a tired cat
still clears 300 px gaps; a ledge up to ~280 px can be jumped (we use <= 220); a mushroom's small
bounce lifts the cat ~480 px above its cap (cliffs up to 420 px).
Run:  python tools/levels/build_world1.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "scenes" / "levels" / "w1"
BOTTOM = 1300          # ground blocks reach down to here
BASE = 900             # normal ground height (water only next to this height)
RUNOFF = 1000          # road past the girl at the end of every level (the hug stays mid-screen)

RES = {
    "base": ("PackedScene", "res://scenes/levels/level_base.tscn"),
    "block": ("PackedScene", "res://scenes/objects/ground_block.tscn"),
    "coin": ("PackedScene", "res://scenes/objects/coin.tscn"),
    "yarn": ("PackedScene", "res://scenes/objects/golden_yarn.tscn"),
    "flag": ("PackedScene", "res://scenes/objects/checkpoint.tscn"),
    "girl": ("PackedScene", "res://scenes/objects/goal_girl.tscn"),
    "milk": ("PackedScene", "res://scenes/objects/milk_bowl.tscn"),
    "spikes": ("PackedScene", "res://scenes/objects/spikes.tscn"),
    "slime": ("PackedScene", "res://scenes/actors/enemies/slime.tscn"),
    "plank": ("PackedScene", "res://scenes/objects/moving_platform.tscn"),
    "water": ("PackedScene", "res://scenes/objects/water.tscn"),
    "mushroom": ("PackedScene", "res://scenes/objects/mushroom.tscn"),
}


class Level:
    RES = RES      # scenes a level may use (a later world adds its own, see build_world2.py)

    def __init__(self, number, name, energy, world=1, theme=None):
        self.number, self.name, self.energy = number, name, energy
        self.world, self.theme = world, theme   # theme: None = meadow, or e.g. "town"
        self.x, self.h = 0, BASE
        self.blocks, self.objects = [], []          # (props), (kind, props)
        self.tags = {}                              # block index -> name (tests find climbs and routes by it)
        self.block_themes = {}                      # block index -> a theme other than the level's (e.g. "ice")
        self.plain = set()                          # block indexes drawn without decorations (decorate = false)
        self.level_props = {}                       # extra properties on the level node (e.g. sky = "aurora")
        self.counts = {}

    # --- helpers ---------------------------------------------------------------------------
    def _block(self, x, top, w, h=None, one_way=False):
        self.blocks.append((x, top, w, (BOTTOM - top) if h is None else h, one_way))

    def _obj(self, kind, x, y, **props):
        self.objects.append((kind, x, y, props))

    def coins(self, *points):
        for x, y in points:
            self._obj("coin", x, y)

    def arc(self, x0, x1, top_y, n=3):
        """Coin arc over a jump from x0 to x1."""
        for i in range(n):
            t = (i + 1) / (n + 1)
            self._obj("coin", round(x0 + (x1 - x0) * t), round(top_y + 160 * (2 * t - 1) ** 2))

    # --- segments --------------------------------------------------------------------------
    def flat(self, length, slimes=(), spikes=(), milk=None, flag=None, coins=(), mushroom=None,
             yarn=None, bridge=None):
        """Ground at the current height. Positions are relative to the segment start.
        slimes: (x, patrol); spikes: (x, long); a long spike gets a one-way step above it.
        mushroom: x of a bonus mushroom with a coin column above it.
        yarn: (x, height above ground). bridge: (x, width) one-way step 220 px above ground."""
        x, h = self.x, self.h
        self._block(x, h, length)
        for sx, patrol in slimes:
            self._obj("slime", x + sx, h, patrol_distance=float(patrol))
            self.coins((x + sx, h - 230))
        for sx, long in spikes:
            self._obj("spikes", x + sx, h, long=long)
            if long:
                self._block(x + sx - 150, h - 200, 300, 40, True)
                self.coins((x + sx - 50, h - 260), (x + sx + 50, h - 260))
            else:
                self.coins((x + sx, h - 170))
        if milk is not None:
            self._obj("milk", x + milk, h)
        if flag is not None:
            self._obj("flag", x + flag, h)
        if mushroom is not None:
            self._obj("mushroom", x + mushroom, h)
            self.coins((x + mushroom, h - 280), (x + mushroom, h - 420))
        if yarn is not None:
            self._obj("yarn", x + yarn[0], h - yarn[1])
        if bridge is not None:
            bx, bw = bridge
            self._block(x + bx, h - 220, bw, 40, True)
            self.coins(*[(x + bx + 60 + i * 120, h - 280) for i in range(max(1, (bw - 60) // 120))])
        for cx in coins:
            self.coins((x + cx, h - 60))
        self.x += length

    def up(self, rise, length, **kw):
        """Step up (jumpable: <= 220 px) onto a new stretch."""
        assert rise <= 220, "steps higher than 220 px need a mushroom or a lift"
        self.h -= rise
        self.flat(length, **kw)

    def down(self, drop, length, **kw):
        self.h = min(self.h + drop, BASE)
        self.flat(length, **kw)

    def gap(self, width):
        """A small pond to jump (<= 260 px, so a tired cat makes it)."""
        assert width <= 260 and self.h == BASE
        self._obj("water", self.x, self.h + 100, width=float(width))
        self.arc(self.x - 60, self.x + width + 60, self.h - 200)
        self.x += width

    def planks(self, n):
        """Wide pond crossed on n sideways planks moving together (110 px hops between them).
        They glide slowly (2.6 s a trip): while the cat is in the air the next plank only drifts
        ~60 px, so a normal jump lands near its middle (tested in dev/m1_levels_test.gd)."""
        assert self.h == BASE
        width = 725 + 380 * (n - 1)   # the far shore is 120 px from the last plank's far end
        self._obj("water", self.x, self.h + 100, width=float(width))
        for i in range(n):
            px = self.x + 140 + i * 380
            self._obj("plank", px, self.h, move_by=(330, 0), travel_time=2.6)
            self.coins((px + 165, self.h - 120))
        self.x += width

    def bobbers(self, n, rise=220):
        """River crossed on n planks bobbing up and down together (150 px hops)."""
        assert self.h == BASE
        width = 140 + (n - 1) * 420 + 135 + 150
        self._obj("water", self.x, self.h + 100, width=float(width))
        for i in range(n):
            px = self.x + 140 + i * 420
            self._obj("plank", px, self.h, move_by=(0, -rise), travel_time=1.6)
            self.coins((px, self.h - rise - 80))
        self.x += width

    def lift(self, rise, length, **kw):
        """Pond with a lift up to a cliff `rise` px higher."""
        assert self.h == BASE and rise <= 420
        self._obj("water", self.x, self.h + 100, width=350.0)
        self._obj("plank", self.x + 175, self.h, move_by=(0, -(rise + 20)))
        self.coins((self.x + 175, self.h - rise // 2))
        self.x += 350
        self.h -= rise
        self.flat(length, **kw)

    def diagonal(self, rise, length, **kw):
        """Pond with a plank that rides across and up to a ledge `rise` px higher."""
        assert self.h == BASE and rise <= 220
        self._obj("water", self.x, self.h + 100, width=665.0)
        self._obj("plank", self.x + 140, self.h, move_by=(330, -rise))
        self.coins((self.x + 305, self.h - rise // 2 - 120))
        self.x += 665
        self.h -= rise
        self.flat(length, **kw)

    def mushroom_up(self, rise, length, **kw):
        """A mushroom just before a cliff `rise` px higher (too high to jump)."""
        assert rise <= 420
        self.flat(450, coins=(100,))
        self._obj("mushroom", self.x - 200, self.h)
        self.coins((self.x - 200, self.h - 300), (self.x - 120, self.h - rise - 80))
        self.h -= rise
        self.flat(length, **kw)

    def finish(self, length=900, coins=(150, 300, 450)):
        """Last stretch with the girl near its end (no hazards here), and RUNOFF px of road past her,
        so during the hug the camera keeps her near the middle of the screen instead of the world
        ending right behind her (owners, 14 Nov 2026)."""
        self.flat(length + RUNOFF, coins=coins)
        self._obj("girl", self.x - 200 - RUNOFF, self.h)

    # --- output ----------------------------------------------------------------------------
    def write(self):
        ids = {k: f"{i + 1}_{k}" for i, k in enumerate(self.RES)}
        out = ["[gd_scene format=3]\n\n"]
        out += [f'[ext_resource type="{t}" path="{p}" id="{ids[k]}"]\n' for k, (t, p) in self.RES.items()]
        num = f"{self.number:02d}"
        world = self.world
        theme = f'theme = "{self.theme}"\n' if self.theme else ""   # on the level, its ground, planks and water
        out.append(f'\n[node name="LevelW{world}_{num}" instance=ExtResource("{ids["base"]}")]\n'
                   f'level_id = "w{world}_{num}"\nstart_energy = {self.energy}\n{theme}'
                   + "".join(f'{k} = "{v}"\n' for k, v in self.level_props.items()) + "\n")
        walls = [(-128, -200, 128, 1500, False), (self.x, -200, 128, 1500, False)]
        names = ["LeftWall"] + [self.tags.get(i, f"Ground{i + 1}") for i in range(len(self.blocks))] + ["RightWall"]
        for n, (name, (x, top, w, hgt, one_way)) in enumerate(zip(names, [walls[0]] + self.blocks + [walls[1]])):
            own = self.block_themes.get(n - 1)   # n - 1: the left wall comes first
            out.append(f'[node name="{name}" parent="Terrain" instance=ExtResource("{ids["block"]}")]\n'
                       f'position = Vector2({x}, {top})\nsize = Vector2({w}, {hgt})\n'
                       + ("one_way = true\n" if one_way else "") + (f'theme = "{own}"\n' if own else theme)
                       + ("decorate = false\n" if n - 1 in self.plain else "") + "\n")
        counts = {}
        for kind, x, y, props in self.objects:
            counts[kind] = counts.get(kind, 0) + 1
            name = {"girl": "GoalGirl", "yarn": "GoldenYarn"}.get(kind, {"flag": "Checkpoint"}.get(kind, kind.capitalize()) + str(counts[kind]))
            lines = [f"position = Vector2({x}, {y})"]
            for k, v in props.items():
                if isinstance(v, tuple):
                    v = f"Vector2({v[0]}, {v[1]})"
                elif isinstance(v, bool):
                    v = "true" if v else "false"
                elif isinstance(v, str):
                    v = f'"{v}"'
                lines.append(f"{k} = {v}")
            if theme and kind in ("plank", "water"):
                lines.append(theme.strip())
            out.append(f'[node name="{name}" parent="Objects" instance=ExtResource("{ids[kind]}")]\n'
                       + "\n".join(lines) + "\n\n")
        path = getattr(self, "out_path", None) or OUT.parent / f"w{world}" / f"level_w{world}_{num}.tscn"   # a demo can write elsewhere
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(out).rstrip("\n") + "\n", encoding="utf-8", newline="\n")
        self.counts = counts
        print(f"  {world}-{self.number} {self.name:18s} {self.x:6d} px  {counts.get('coin', 0):3d} coins  "
              f"{counts.get('slime', 0):2d} slimes  {counts.get('spikes', 0):2d} spikes  "
              f"{counts.get('plank', 0):2d} planks  {counts.get('mushroom', 0):2d} mushrooms")
        return self


def level_2():
    L = Level(2, "Slime Meadow", 0.6)
    L.flat(1300, coins=(400, 520, 640), slimes=[(900, 80)])
    L.gap(220)
    L.flat(1250, slimes=[(600, 80)], flag=150)
    L.gap(240)
    L.flat(1000, milk=350, coins=(500, 620))
    L.planks(1)
    L.flat(1500, slimes=[(450, 70), (1000, 70)], coins=(1300,))
    L.up(160, 900, coins=(200, 350, 500))
    L.down(160, 900, mushroom=450, yarn=(450, 780))
    L.finish()
    return L


def level_3():
    L = Level(3, "Over the Water", 0.5)
    L.flat(1300, coins=(400, 520), spikes=[(800, False)])
    L.gap(240)
    L.flat(1400, spikes=[(700, True)], flag=150)
    L.lift(380, 1300, slimes=[(700, 100)], coins=(200, 1100))
    L.down(380, 1200, milk=350, coins=(600, 720))
    L.gap(260)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.planks(2)
    L.flat(900, bridge=(250, 400), yarn=(450, 560), coins=(150,))
    L.finish()
    return L


def level_4():
    L = Level(4, "Mushroom Hill", 0.6)
    L.flat(1300, mushroom=600, coins=(400, 520))
    L.gap(240)
    L.mushroom_up(380, 1200, slimes=[(650, 90)], flag=200)
    L.down(380, 1200, spikes=[(650, False)], milk=200)
    L.planks(2)
    L.flat(1400, slimes=[(500, 80)], mushroom=1050, yarn=(1050, 780), flag=150)
    L.gap(250)
    L.mushroom_up(420, 1100, coins=(300, 450, 600))
    L.down(420, 1300, slimes=[(600, 100)], coins=(1100,))
    L.finish()
    return L


def level_5():
    L = Level(5, "Bobbing River", 0.5)
    L.flat(1300, coins=(400, 520), spikes=[(800, True)])
    L.bobbers(2)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.lift(400, 1500, bridge=(400, 600), yarn=(700, 560), coins=(200, 1300))
    L.down(400, 1300, milk=300, spikes=[(800, False)])
    L.bobbers(3)
    L.flat(1500, slimes=[(450, 90)], spikes=[(1050, True)], flag=150)
    L.gap(260)
    L.finish()
    return L


def level_6():
    L = Level(6, "Slime Parade", 0.6)
    L.flat(1600, slimes=[(550, 70), (1150, 80)])
    L.gap(250)
    L.flat(2000, slimes=[(500, 80), (1070, 80), (1640, 80)], bridge=(380, 1300), yarn=(1000, 560), flag=150)
    L.diagonal(200, 1400, slimes=[(700, 90)], milk=250)
    L.down(200, 1300, mushroom=650, coins=(150, 1100))
    L.planks(2)
    L.flat(2000, slimes=[(500, 80), (1070, 80)], spikes=[(1600, False)], flag=150)
    L.gap(250)
    L.flat(1300, slimes=[(600, 90)])
    L.finish()
    return L


def level_7():
    L = Level(7, "Long Way Home", 0.3)
    L.flat(1300, slimes=[(800, 80)], coins=(400, 520))
    L.gap(250)
    L.flat(1300, milk=300, spikes=[(850, False)], flag=150)
    L.lift(380, 1400, slimes=[(750, 100)])
    L.down(380, 1200, spikes=[(650, True)])
    L.planks(3)
    L.flat(1700, milk=300, slimes=[(600, 80), (1200, 70)], flag=150)
    L.bobbers(2)
    L.flat(1300, mushroom=650, yarn=(650, 780), coins=(150, 1100))
    L.diagonal(200, 1300, slimes=[(650, 90)], milk=200)
    L.down(200, 1200, spikes=[(600, False)])
    L.gap(260)
    L.finish()
    return L


def level_8():
    L = Level(8, "Windmill Way", 0.5)
    L.flat(1300, spikes=[(700, True)], coins=(400, 520))
    L.mushroom_up(400, 1300, slimes=[(700, 90)], flag=200)
    L.down(400, 1100, milk=250)
    L.planks(3)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.bobbers(3)
    L.flat(1600, spikes=[(600, True), (1150, False)], milk=200)
    L.lift(400, 1500, slimes=[(500, 80), (1100, 70)], bridge=(450, 500), yarn=(700, 560), flag=200)
    L.down(400, 1200, spikes=[(650, False)])
    L.diagonal(200, 1200, slimes=[(650, 90)])
    L.down(200, 1000)
    L.finish()
    return L


def level_9():
    L = Level(9, "Last Stretch", 0.4)
    L.flat(1500, spikes=[(600, False)], slimes=[(1100, 60)], coins=(400,))
    L.gap(260)
    L.mushroom_up(380, 1000, flag=150)
    L.mushroom_up(300, 1100, slimes=[(650, 80)], yarn=(650, 380))
    L.down(680, 1100, milk=250)
    L.planks(4)
    L.flat(1600, slimes=[(500, 80), (1070, 80)], flag=150)
    L.bobbers(3)
    L.flat(1800, spikes=[(600, True), (1200, True)], milk=200)
    L.lift(400, 1500, slimes=[(500, 80), (1100, 80)], flag=200)
    L.down(400, 1100, spikes=[(650, False)])
    L.diagonal(200, 1300, slimes=[(700, 90)])
    L.down(200, 900)
    L.gap(260)
    L.finish()
    return L


def level_10():
    L = Level(10, "Home Again", 0.8)
    L.flat(1300, mushroom=650, coins=(400, 520))
    L.gap(250)
    L.flat(1500, slimes=[(500, 80), (1070, 80)], flag=150)
    L.bobbers(3)
    L.flat(1300, milk=250, spikes=[(800, True)])
    L.planks(3)
    L.flat(1400, slimes=[(500, 80)], flag=150, coins=(1100, 1220))
    L.lift(400, 1400, bridge=(350, 600), yarn=(650, 560), slimes=[(1100, 60)])
    L.down(400, 1300, spikes=[(650, False)], milk=200)
    L.diagonal(200, 1300, slimes=[(650, 90)], flag=150)
    L.down(200, 1000, mushroom=500)
    L.gap(220)
    L.finish(1600, coins=(150, 300, 450, 600, 750, 900, 1050, 1200))   # a calm walk home to her
    return L


if __name__ == "__main__":
    for make in [level_2, level_3, level_4, level_5, level_6, level_7, level_8, level_9, level_10]:
        make().write()
