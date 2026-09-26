import subprocess

FONT = {
    '4': ["10000", "10000", "10000", "11110", "00010", "00010", "00010"],
    '2': ["11110", "00001", "00001", "01110", "10000", "10000", "11111"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'G': ["01110", "10001", "10000", "10011", "10001", "10001", "01110"],
}

TEXT = "42LOG"
GAP = "  "
PIX = "\u2588"

try:
    cols = int(subprocess.check_output(["tput", "cols"]).strip())
except Exception:
    cols = 60


def make_shadow(grid):
    h = len(grid)
    w = max(len(r) for r in grid)
    grid = [r.ljust(w) for r in grid]
    new = [["0"] * (w + 1) for _ in range(h + 1)]
    for y in range(h):
        for x in range(w):
            if grid[y][x] == "1":
                new[y][x] = "1"
    for y in range(h):
        for x in range(w):
            if grid[y][x] == "1":
                if x + 1 < w + 1 and new[y][x + 1] == "0":
                    new[y][x + 1] = "2"
                if y + 1 < h + 1 and new[y + 1][x] == "0":
                    new[y + 1][x] = "2"
    return ["".join(r) for r in new]


def render_raw_row(row):
    parts = []
    for ch in TEXT:
        parts.append(FONT[ch][row])
        parts.append("0" * len(GAP))
    return "".join(parts)[:-(len(GAP))]


def build_grid():
    raw = [render_raw_row(r) for r in range(7)]
    return make_shadow(raw)


def apply_colors(line):
    PURPLE = "\033[95m"
    SHADOW = "\033[35m"
    RESET = "\033[0m"
    out = []
    for c in line:
        if c == "1":
            out.append(PURPLE + PIX)
        elif c == "2":
            out.append(SHADOW + PIX)
        else:
            out.append(" ")
    return "".join(out) + RESET


def main():
    grid = build_grid()
    colored = [apply_colors(row) for row in grid]
    block = chr(10).join(colored)
    with open("banner.py", "w", encoding="utf-8") as f:
        f.write('PURPLE = "\\033[95m"' + chr(10))
        f.write('SHADOW = "\\033[35m"' + chr(10))
        f.write('RESET = "\\033[0m"' + chr(10) + chr(10))
        f.write("BANNER = '''" + chr(10))
        f.write(block)
        f.write(chr(10) + "'''" + chr(10) + chr(10))
        f.write('SUBTITLE = """' + chr(10) + chr(10))
        f.write("     42log messenger  .  temporary  .  encrypted" + chr(10))
        f.write('"""' + chr(10) + chr(10))
        f.write("def print_banner():" + chr(10))
        f.write("    print(BANNER)" + chr(10))
        f.write("    print(PURPLE + SUBTITLE + RESET)" + chr(10))
    print("banner.py записан")


if __name__ == "__main__":
    main()
