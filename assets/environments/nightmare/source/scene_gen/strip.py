"""Раскладка горной дороги вдоль пути из прямых и дуг (локальные оси: вперёд −Z, стена +X, бездна −X).

Модули горного набора: дорога 4 м (полотно 2,5 м), стены 6/4,8/5,8 м с лицом на x = +1,3,
кромки 5 м (губа на x = −2,0), высокие массивы 24 м (лицо смотрит в −X)."""
import math

WALLS = [("rock_wall_a", 6.0), ("rock_wall_b", 6.0), ("rock_wall_a", 6.0), ("rock_wall_broken_c", 5.8),
         ("rock_wall_b", 6.0), ("rock_wall_a", 6.0), ("rock_overhang_b", 4.8), ("rock_wall_b", 6.0)]
EDGES = ["cliff_edge_a1", "cliff_edge_a2", "cliff_edge_a1", "cliff_edge_collapsed_b"]


class Path:
    """Путь в плоскости XZ: старт (x, z), курс 0 = вдоль −Z; сегменты ('line', длина) и
    ('arc', радиус, угол°) — угол > 0 поворачивает вправо (к стене, +X)."""

    def __init__(self, x=0.0, z=0.0, heading=0.0, y=0.0, grade=0.0):
        self.start = (x, z, heading)
        self.y0 = y
        self.grade = grade  # подъём на метр пути
        self.segs = []

    def line(self, length):
        self.segs.append(("line", length))
        return self

    def arc(self, radius, deg):
        self.segs.append(("arc", radius, deg))
        return self

    @property
    def length(self):
        return sum(s[1] if s[0] == "line" else abs(math.radians(s[2])) * s[1] for s in self.segs)

    def at(self, s):
        x, z, h = self.start
        for seg in self.segs:
            if seg[0] == "line":
                d = min(s, seg[1])
                x += math.sin(h) * d
                z -= math.cos(h) * d
                s -= d
                if s <= 0:
                    break
            else:
                r, deg = seg[1], seg[2]
                total = abs(math.radians(deg)) * r
                d = min(s, total)
                sgn = 1.0 if deg > 0 else -1.0
                # Центр дуги — справа (sgn > 0) или слева от курса.
                cx = x + math.cos(h) * r * sgn
                cz = z + math.sin(h) * r * sgn
                a = d / r * sgn
                h2 = h + a
                x = cx - math.cos(h2) * r * sgn
                z = cz - math.sin(h2) * r * sgn
                h = h2
                s -= d
                if s <= 0:
                    break
        return x, z, h

    def y(self, s):
        return self.y0 + self.grade * s

    def offset(self, s, lateral):
        """Точка, сдвинутая вбок от оси на lateral (+ — к стене)."""
        x, z, h = self.at(s)
        return x + math.cos(h) * lateral, z + math.sin(h) * lateral, h


def yaw_of(h):
    # Модуль смотрит вперёд в −Z; курс h → поворот вокруг Y на −h.
    return -h


def lay_road(S, parent, path, s0=0.0, s1=None, prefix="", ice=(), skip=(), y_extra=0.0):
    """Полотно 4-метровыми модулями. Возвращает число модулей."""
    s1 = path.length if s1 is None else s1
    k = 0
    s = s0
    while s < s1 - 0.5:
        if k not in skip:
            x, z, h = path.at(s)
            n = "mountain/road_old_02_ice" if k in ice else "mountain/road_old_01"
            # Уклон модуля по высоте пути: соседние модули стыкуются без ступеней.
            pitch = math.atan((path.y(s + 4.0) - path.y(s)) / 4.0)
            if abs(pitch) > 1e-4:
                S.inst(f"{prefix}Road{k:02d}", parent, n, (x, path.y(s) + y_extra, z), rot=(pitch, yaw_of(h), 0.0))
            else:
                S.inst(f"{prefix}Road{k:02d}", parent, n, (x, path.y(s) + y_extra, z), yaw=yaw_of(h))
        s += 4.0
        k += 1
    return k


def _lat(lateral, s):
    return lateral(s) if callable(lateral) else lateral


def _lat_yaw(lateral, s, h, ln):
    """Поворот модуля, когда боковой сдвиг меняется по пути (ниша, расширение)."""
    if not callable(lateral):
        return h
    d = (lateral(s + ln) - lateral(s)) / ln
    return h + math.atan(d)


def lay_walls(S, parent, path, s0=0.0, s1=None, prefix="", start=0, lateral=1.3, seq=WALLS, y_extra=0.0):
    s1 = path.length if s1 is None else s1
    s = s0
    k = 0
    while s < s1:
        n, ln = seq[(start + k) % len(seq)]
        x, z, h = path.offset(s, _lat(lateral, s))
        S.inst(f"{prefix}Wall{k:02d}", parent, "mountain/" + n, (x, path.y(s) + y_extra, z),
               yaw=yaw_of(_lat_yaw(lateral, s, h, ln)))
        s += ln
        k += 1
    return k


def lay_edges(S, parent, path, s0=0.0, s1=None, prefix="", start=0, y_extra=0.0, seq=EDGES, lateral=0.0):
    s1 = path.length if s1 is None else s1
    s = s0
    k = 0
    while s < s1:
        x, z, h = path.offset(s, _lat(lateral, s))
        S.inst(f"{prefix}Edge{k:02d}", parent, "mountain/" + seq[(start + k) % len(seq)],
               (x, path.y(s) + y_extra, z), yaw=yaw_of(_lat_yaw(lateral, s, h, 5.0)))
        s += 5.0
        k += 1
    return k


def lay_faces(S, parent, path, s0=0.0, s1=None, prefix="", drop=True, upper=True, drop_x=-3.0, drop_y=-40.0,
              upper_x=4.6, upper_y=9.0, step=22.0, drop_lat=None, upper_lat=None):
    """Высокие массивы: под кромкой (лицо обрыва в бездну) и над стенами."""
    s1 = path.length if s1 is None else s1
    s = s0
    k = 0
    while s < s1:
        if drop:
            x, z, h = path.offset(s, drop_x + (drop_lat(s) if drop_lat else 0.0))
            S.inst(f"{prefix}Drop{k:02d}", parent, "backdrop/cliff_face_tall_" + "ab"[k % 2],
                   (x, path.y(s) + drop_y, z), yaw=yaw_of(h))
        if upper:
            x, z, h = path.offset(s, upper_x + (upper_lat(s) if upper_lat else 0.0))
            S.inst(f"{prefix}Upper{k:02d}", parent, "backdrop/cliff_face_tall_" + "ba"[k % 2],
                   (x, path.y(s) + upper_y, z), yaw=yaw_of(h))
        s += step
        k += 1
    return k


def path_ending_at(segs, end_x, end_z, end_h=0.0, y=0.0, grade=0.0):
    """Путь из сегментов, который заканчивается в заданной точке с заданным курсом
    (дорога, которая «приходит» в площадку из-за поворота)."""
    turn = sum(math.radians(s[2]) for s in segs if s[0] == "arc")
    p = Path(0.0, 0.0, end_h - turn, y=y, grade=grade)
    for s in segs:
        if s[0] == "line":
            p.line(s[1])
        else:
            p.arc(s[1], s[2])
    ex, ez, _ = p.at(p.length)
    p.start = (end_x - ex, end_z - ez, end_h - turn)
    return p
