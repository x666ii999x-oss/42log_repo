#!/data/data/com.termux/files/usr/bin/bash
# 42log installer v1.0
set -e

echo "========================================"
echo "    42log installer"
echo "========================================"

# 1. Проверка Termux
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    echo "ОШИБКА: этот установщик рассчитан только на Termux."
    exit 1
fi

# 2. Обновление репозиториев
echo "[*] Обновление пакетов..."
pkg update -y >/dev/null 2>&1 || true

# 3. Установка всех зависимостей
echo "[*] Установка Python, OpenSSH, termux-api, pillow, chafa, cloudflared..."
pkg install -y python openssh termux-api python-pillow chafa cloudflared >/dev/null 2>&1 || true

# 4. Проверка папок
BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)

for d in ~/42log; do
    if [ -d "$d" ]; then
        echo
        echo "ВНИМАНИЕ: папка $d уже существует."
        read -p "Перезаписать? Сделаем бэкап как ${d}.backup_${BACKUP_SUFFIX} [y/N]: " ans
        if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
            echo "Отменено. Ничего не изменено."
            exit 0
        fi
        mv "$d" "${d}.backup_${BACKUP_SUFFIX}"
        echo "[*] Старая папка сохранена: ${d}.backup_${BACKUP_SUFFIX}"
    fi
done

mkdir -p ~/42log ~/42log/42dec
echo "[*] Папки ~/42log и ~/42dec созданы"

# ============================================================
# 5. Запись файлов проекта
# ============================================================

echo "[*] Пишу cipher.py (в обе папки)..."
cat > ~/42log/cipher.py << 'PYEOF'
ERROR_MAP = {
    'а': "bash: cat: command not found",
    'б': "ls: Permission denied",
    'в': "cp: No such file or directory",
    'г': "Segmentation fault (core dumped)",
    'д': "bash: syntax error near unexpected token",
    'е': "mv: Is a directory",
    'ё': "rmdir: Directory not empty",
    'ж': "cd: Not a directory",
    'з': "bash: cannot execute binary file",
    'и': "ssh: Connection refused",
    'й': "curl: (7) Connection timed out",
    'к': "ssh: Connection reset by peer",
    'л': "write: Broken pipe",
    'м': "fork: Resource temporarily unavailable",
    'н': "chmod: Operation not permitted",
    'о': "touch: Read-only file system",
    'п': "No space left on device",
    'р': "Too many open files",
    'с': "Argument list too long",
    'т': "Input/output error",
    'у': "Invalid argument",
    'ф': "bind: Address already in use",
    'х': "ping: Network is unreachable",
    'ц': "ssh: No route to host",
    'ч': "Disk quota exceeded",
    'ш': "File name too long",
    'щ': "Interrupted system call",
    'ъ': "Bad file descriptor",
    'ы': "Numerical result out of range",
    'ь': "Message too long",
    'э': "Protocol not available",
    'ю': "Link has been severed",
    'я': "Unknown error 42",
    ' ': "warning: deprecated call to legacy module",
}

INVERSE = {v: k for k, v in ERROR_MAP.items()}
INVERSE[''] = ' '


def encrypt(text):
    out = []
    for ch in text.lower():
        if ch in ERROR_MAP:
            out.append(ERROR_MAP[ch])
        else:
            out.append(ch)
    return chr(10).join(out)


def decrypt(block):
    out = []
    for line in block.split(chr(10)):
        if line in INVERSE:
            out.append(INVERSE[line])
    return ''.join(out)
PYEOF

cp ~/42log/cipher.py ~/42log/42dec/cipher.py

echo "[*] Пишу make_logo.py..."
cat > ~/42log/make_logo.py << 'PYEOF'
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
PYEOF

echo "[*] Пишу decryptor.py в 42dec..."
cat > ~/42log/42dec/decryptor.py << 'PYEOF'
import sys
import subprocess

from cipher import decrypt, encrypt


def read_clipboard():
    try:
        r = subprocess.run(["termux-clipboard-get"], capture_output=True, text=True, timeout=5)
        if r.returncode == 0:
            return r.stdout
    except Exception:
        pass
    return None


def clean_lines(text):
    out = []
    for raw in text.splitlines():
        s = raw.rstrip()
        if s == "":
            out.append("")
            continue
        t = s.strip()
        if "журнал ошибок" in t:
            continue
        if set(t) <= {"-"} and len(t) >= 3:
            continue
        if "---" in t and any(x in t for x in ("ты", "k1", "k2", "n1", "n2", "n3")):
            continue
        if s.startswith("  "):
            s = s[2:]
        if t.endswith(" >") and len(t.split()) == 2:
            continue
        if t == ">" or (len(t) == 2 and t[1] == ">"):
            continue
        out.append(s)
    return "\n".join(out)


def show_decrypt(text):
    cleaned = clean_lines(text)
    if not cleaned.strip():
        print("(пусто)")
        return
    print()
    print("\033[36m--- расшифровка ---\033[0m")
    print(decrypt(cleaned))
    print("\033[36m-------------------\033[0m")


def show_encrypt(text):
    print()
    print("\033[36m--- шифр (журнал ошибок) ---\033[0m")
    print(encrypt(text))
    print("\033[36m----------------------------\033[0m")


def input_manual_decrypt():
    print("\033[90mВводи строки журнала. Пустая строка — конец.\033[0m")
    lines = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line == "" and lines:
            break
        lines.append(line)
    return "\n".join(lines)


def input_manual_encrypt():
    try:
        return input("текст: ")
    except (EOFError, KeyboardInterrupt):
        return ""


def process_file(path, mode):
    try:
        with open(path, encoding="utf-8") as f:
            data = f.read()
    except Exception as e:
        print(f"не прочитать файл: {e}")
        return
    if mode == "enc":
        show_encrypt(data.strip())
    else:
        show_decrypt(data)


def main():
    if len(sys.argv) >= 2:
        path = sys.argv[1]
        mode = "dec"
        if len(sys.argv) >= 3 and sys.argv[2] in ("-e", "--encrypt"):
            mode = "enc"
        process_file(path, mode)
        return

    print("=== 42dec ===")
    while True:
        print()
        print("  1) расшифровать (ввод вручную)")
        print("  2) расшифровать (из буфера)")
        print("  3) зашифровать (ввод вручную)")
        print("  4) выход")
        print()
        try:
            c = input("выбор: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if c == "1":
            show_decrypt(input_manual_decrypt())
        elif c == "2":
            t = read_clipboard()
            if t:
                show_decrypt(t)
        elif c == "3":
            t = input_manual_encrypt()
            if t:
                show_encrypt(t)
        elif c in ("4", "q", "quit", "exit"):
            return
        else:
            print("введи 1, 2, 3 или 4")


if __name__ == "__main__":
    main()
PYEOF


echo "[*] Пишу server.py..."
cat > ~/42log/server.py << 'PYEOF'
import socket
import threading
import json
import secrets
import os
from banner import print_banner

HOST = '0.0.0.0'
PORT = 5555
MAX_MSG = 8192


class QuitSignal(Exception):
    pass


rooms = {}
conns = {}
lock = threading.Lock()


def send(conn, obj):
    try:
        conn.sendall((json.dumps(obj, ensure_ascii=False) + "\n").encode('utf-8'))
    except Exception:
        pass


def send_err(conn, text, code=None):
    m = {"type": "error", "text": text}
    if code:
        m["code"] = code
    send(conn, m)


def gen_key():
    return "-".join(secrets.token_hex(2) for _ in range(3))


def close_room(key, reason, exclude_conn=None):
    with lock:
        r = rooms.pop(key, None)
    if not r:
        return
    for u in (r["u1"], r["u2"]):
        if not u:
            continue
        st = conns.get(u["conn"])
        if st:
            st["rooms"].discard(key)
        if u["conn"] is not exclude_conn:
            send(u["conn"], {"type": "room_closed", "key": key, "reason": reason})


def process(conn, st, m):
    t = m.get("type")

    if t == "login":
        nick = str(m.get("nick", "")).strip()[:20]
        if not nick:
            send_err(conn, "пустой ник")
            return
        with lock:
            taken = {s["nick"] for s in conns.values() if s.get("nick")}
            if nick in taken:
                send_err(conn, f"ник '{nick}' уже занят", code="nick_taken")
                return
            st["nick"] = nick
        send(conn, {"type": "login_ok", "nick": nick})
        print(f"[+] {nick} вошёл ({conn.getpeername()[0]})")
        return

    if not st.get("nick"):
        send_err(conn, "сначала login")
        return

    if t == "join":
        key = str(m.get("key", "")).strip().lower()
        if not key:
            send_err(conn, "пустой ключ")
            return
        if key in st["rooms"]:
            send_err(conn, "ты уже в этой комнате")
            return
        with lock:
            r = rooms.get(key)
            if not r:
                send_err(conn, "промокод не найден", code="no_room")
                return
            if r["state"] == "active":
                send_err(conn, "промокод уже использован", code="used")
                return
            if r["u1"] is None:
                r["u1"] = {"conn": conn, "nick": st["nick"]}
                st["rooms"].add(key)
                send(conn, {"type": "join_ok", "key": key, "peer": None, "state": "waiting"})
                print(f"[*] {st['nick']} ждёт в комнате {key}")
            else:
                r["u2"] = {"conn": conn, "nick": st["nick"]}
                r["state"] = "active"
                st["rooms"].add(key)
                u1 = r["u1"]
                send(conn, {"type": "join_ok", "key": key, "peer": u1["nick"], "state": "active"})
                send(u1["conn"], {"type": "join_ok", "key": key, "peer": st["nick"], "state": "active"})
                print(f"[*] комната {key}: {u1['nick']} <-> {st['nick']}")
        return

    if t == "chat":
        key = str(m.get("key", "")).strip().lower()
        text = str(m.get("text", "")).rstrip()
        if not text:
            return
        if key not in st["rooms"]:
            send_err(conn, "ты не в этой комнате")
            return
        with lock:
            r = rooms.get(key)
            if not r or r["state"] != "active":
                send_err(conn, "комната неактивна")
                return
            u1, u2 = r["u1"], r["u2"]
        for u in (u1, u2):
            if u and u["conn"] is not conn:
                send(u["conn"], {"type": "chat", "key": key, "from": st["nick"], "text": text})
        return

    if t == "leave":
        key = str(m.get("key", "")).strip().lower()
        if key not in st["rooms"]:
            send_err(conn, "ты не в этой комнате")
            return
        with lock:
            r = rooms.get(key)
        if not r:
            st["rooms"].discard(key)
            return
        if r["state"] == "active":
            close_room(key, "peer_left", exclude_conn=conn)
            send(conn, {"type": "room_closed", "key": key, "reason": "self_left"})
        else:
            with lock:
                rooms.pop(key, None)
            st["rooms"].discard(key)
            send(conn, {"type": "room_closed", "key": key, "reason": "self_left"})
        return

    if t == "quit":
        raise QuitSignal()


def handle_client(conn, addr):
    st = {"nick": None, "rooms": set()}
    with lock:
        conns[conn] = st
    buf = b""
    try:
        while True:
            chunk = conn.recv(MAX_MSG)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if not line.strip():
                    continue
                try:
                    m = json.loads(line.decode("utf-8"))
                except Exception:
                    send_err(conn, "неверный JSON")
                    continue
                process(conn, st, m)
    except QuitSignal:
        pass
    except Exception as e:
        print(f"[!] {addr}: {e}")
    finally:
        disconnect(conn, st)


def disconnect(conn, st):
    with lock:
        conns.pop(conn, None)
        keys = list(st["rooms"])
    for key in keys:
        with lock:
            r = rooms.get(key)
        if not r:
            continue
        if r["state"] == "active":
            close_room(key, "peer_left", exclude_conn=conn)
        else:
            with lock:
                rooms.pop(key, None)
    try:
        conn.close()
    except Exception:
        pass
    if st.get("nick"):
        print(f"[-] {st['nick']} отключился")


def admin_console():
    print()
    print("=== АДМИН-КОНСОЛЬ ===")
    print("  newroom         - создать комнату")
    print("  rooms           - список комнат")
    print("  kick <ник>      - отключить юзера")
    print("  close <ключ>    - закрыть комнату")
    print("  quit            - остановить сервер")
    print()
    while True:
        try:
            line = input()
        except (EOFError, KeyboardInterrupt):
            os._exit(0)
        parts = line.strip().split()
        if not parts:
            continue
        cmd = parts[0].lower()

        if cmd == "newroom":
            key = gen_key()
            with lock:
                rooms[key] = {"state": "waiting", "u1": None, "u2": None}
            print(f"  КЛЮЧ: {key}")
            print(f"  передай собеседнику, жду подключений...")
        elif cmd == "rooms":
            with lock:
                snapshot = list(rooms.items())
            if not snapshot:
                print("  (нет комнат)")
            for k, r in snapshot:
                if r["state"] == "waiting":
                    print(f"  {k}  ожидание")
                else:
                    print(f"  {k}  {r['u1']['nick']} <-> {r['u2']['nick']}")
        elif cmd == "kick":
            if len(parts) < 2:
                print("  kick <ник>")
                continue
            target = parts[1]
            with lock:
                found = next((c for c, s in conns.items() if s.get("nick") == target), None)
            if found:
                try:
                    found.close()
                except Exception:
                    pass
                print(f"  {target} отключён")
            else:
                print(f"  не найден: {target}")
        elif cmd == "close":
            if len(parts) < 2:
                print("  close <ключ>")
                continue
            close_room(parts[1].lower(), "admin_closed")
            print(f"  комната {parts[1]} закрыта")
        elif cmd in ("quit", "exit"):
            print("  выход")
            os._exit(0)
        else:
            print(f"  неизвестно: {cmd}")


def main():
    print_banner()
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen()
    print(f"[*] 42log сервер на {HOST}:{PORT}")
    print(f"[*] в другом окне: ssh -R 0:localhost:{PORT} serveo.net")

    threading.Thread(target=admin_console, daemon=True).start()

    try:
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()
    except KeyboardInterrupt:
        print("\nостановка")
    finally:
        server.close()


if __name__ == "__main__":
    main()
PYEOF

echo "[*] Пишу client.py..."
cat > ~/42log/client.py << 'PYEOF'
import socket
import threading
import json
import sys
import time

from cipher import encrypt
from banner import print_banner

DEFAULT_PORT = 5555

state = {
    "sock": None,
    "stop": threading.Event(),
    "rooms": {},
    "current": None,
    "login_ok": False,
}


def send(obj):
    try:
        state["sock"].sendall((json.dumps(obj, ensure_ascii=False) + "\n").encode('utf-8'))
    except Exception:
        pass


def print_msg(s):
    sys.stdout.write("\r\033[K" + s + "\n")
    sys.stdout.flush()


def room_label(key):
    r = state["rooms"].get(key)
    if not r:
        return key
    if r["state"] == "waiting":
        return f"{key} (ожидание)"
    return f"{key} <-> {r['peer']}"


def render(m):
    t = m.get("type")

    if t == "login_ok":
        state["login_ok"] = True
        print_msg(f"\033[32m[*] ник принят: {m['nick']}\033[0m")

    elif t == "join_ok":
        key = m["key"]
        state["rooms"][key] = {"peer": m.get("peer"), "state": m["state"]}
        state["current"] = key
        if m["state"] == "waiting":
            print_msg(f"\033[36m[*] комната {key}: ждём собеседника...\033[0m")
        else:
            print_msg(f"\033[32m[*] соединён с {m['peer']} (комната {key})\033[0m")

    elif t == "chat":
        key = m["key"]
        prefix = "" if key == state["current"] else f"\033[90m[{key}]\033[0m "
        lines_txt = m["text"].split("\n")
        print_msg(f"{prefix}\033[1;35m{m['from']}\033[0m \033[33m--- журнал ошибок ---\033[0m")
        for _ln in lines_txt:
            if _ln.strip():
                print_msg(f"  \033[31m{_ln}\033[0m")
            else:
                print_msg("")
        print_msg(f"{prefix}\033[33m--------------------\033[0m")

    elif t == "system":
        print_msg(f"\033[36m[*] {m.get('text','')}\033[0m")

    elif t == "room_closed":
        key = m["key"]
        state["rooms"].pop(key, None)
        if state["current"] == key:
            state["current"] = None
        reason = m.get("reason")
        if reason == "peer_left":
            print_msg(f"\033[33m[*] {key}: ЧАТ ЗАВЕРШЁН — собеседник вышел\033[0m")
        elif reason == "self_left":
            print_msg(f"\033[36m[*] {key}: ты вышел\033[0m")
        elif reason == "admin_closed":
            print_msg(f"\033[33m[*] {key}: комната закрыта админом\033[0m")

    elif t == "error":
        print_msg(f"\033[31m[!] {m['text']}\033[0m")


def reader():
    buf = b""
    while not state["stop"].is_set():
        try:
            chunk = state["sock"].recv(8192)
            if not chunk:
                print_msg("\033[31m[*] сервер закрыл соединение\033[0m")
                state["stop"].set()
                return
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if not line.strip():
                    continue
                try:
                    m = json.loads(line.decode("utf-8"))
                except Exception:
                    continue
                render(m)
        except Exception:
            state["stop"].set()
            return


def list_rooms():
    if not state["rooms"]:
        print("  (нет комнат)")
        return
    for i, key in enumerate(state["rooms"], 1):
        mark = " *" if key == state["current"] else ""
        print(f"  {i}. {room_label(key)}{mark}")


def main():
    print_banner()
    print("=== 42log ===")
    host = input("хост [127.0.0.1]: ").strip() or "127.0.0.1"
    port_str = input(f"порт [{DEFAULT_PORT}]: ").strip()
    try:
        port = int(port_str) if port_str else DEFAULT_PORT
    except ValueError:
        port = DEFAULT_PORT
    nick = input("nickname: ").strip()
    if not nick:
        print("нужен ник")
        return

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect((host, port))
    except Exception as e:
        print(f"[!] не удалось: {e}")
        return
    state["sock"] = sock

    send({"type": "login", "nick": nick})
    threading.Thread(target=reader, daemon=True).start()

    for _ in range(30):
        if state["login_ok"] or state["stop"].is_set():
            break
        time.sleep(0.1)
    if not state["login_ok"]:
        print("не удалось войти (см. ошибку выше)")
        return

    print()
    print("команды: /join <ключ> | /rooms | /switch <номер> | /leave | /quit")
    print()

    try:
        while not state["stop"].is_set():
            if state["current"]:
                p = f"{state['current']} > "
            else:
                p = "> "
            try:
                line = input(p)
                if not line.startswith("/"):
                    sys.stdout.write("\033[A\r\033[K")
                    sys.stdout.flush()
            except (EOFError, KeyboardInterrupt):
                break
            if not line.strip():
                continue

            if line.startswith("/"):
                parts = line.split(maxsplit=1)
                cmd = parts[0].lower()
                if cmd in ("/quit", "/exit"):
                    send({"type": "quit"})
                    break
                elif cmd == "/join":
                    if len(parts) < 2:
                        print("  /join <ключ>")
                        continue
                    send({"type": "join", "key": parts[1].strip()})
                elif cmd == "/rooms":
                    list_rooms()
                elif cmd == "/switch":
                    if len(parts) < 2:
                        print("  /switch <номер>")
                        continue
                    try:
                        idx = int(parts[1]) - 1
                        key = list(state["rooms"].keys())[idx]
                        state["current"] = key
                        print(f"  -> {room_label(key)}")
                    except (ValueError, IndexError):
                        print("  нет такой комнаты")
                elif cmd == "/leave":
                    if not state["current"]:
                        print("  ты не в комнате")
                        continue
                    send({"type": "leave", "key": state["current"]})
                else:
                    print(f"  неизвестная команда: {cmd}")
            else:
                if not state["current"]:
                    print("  сначала выбери комнату: /switch или /join")
                    continue
                enc = encrypt(line)
                send({"type": "chat", "key": state["current"], "text": enc})
                lines_txt = enc.split("\n")
                print_msg(f"\033[1;35mты\033[0m \033[33m--- журнал ошибок ---\033[0m")
                for _ln in lines_txt:
                    if _ln.strip():
                        print_msg(f"  \033[31m{_ln}\033[0m")
                    else:
                        print_msg("")
                print_msg(f"\033[33m--------------------\033[0m")
    except KeyboardInterrupt:
        pass
    finally:
        state["stop"].set()
        try:
            sock.close()
        except Exception:
            pass
        print("\n[*] отключено")


if __name__ == "__main__":
    main()
PYEOF

# ============================================================
# 6. Генерация баннера
# ============================================================
echo "[*] Генерирую баннер..."
cd ~/42log
python make_logo.py || echo "[!] ошибка генерации баннера"
cp banner.py banner.py.final 2>/dev/null || true

# ============================================================
# 7. Ярлыки в $PREFIX/bin
# ============================================================
echo "[*] Создаю ярлыки в \$PREFIX/bin..."

cat > $PREFIX/bin/42log-server << 'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/42log
python server.py
SH
chmod +x $PREFIX/bin/42log-server

cat > $PREFIX/bin/42log-client << 'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/42log
python client.py
SH
chmod +x $PREFIX/bin/42log-client

cat > $PREFIX/bin/42dec << 'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/42log/42dec
python decryptor.py
SH
chmod +x $PREFIX/bin/42dec

cat > $PREFIX/bin/42tunnel << 'SH'
#!/data/data/com.termux/files/usr/bin/bash
echo "[*] Туннель через serveo.net..."
echo "[*] Дождись строки 'tcp://serveo.net:XXXXX' и передай её собеседнику."
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 0:localhost:5555 serveo.net
SH
chmod +x $PREFIX/bin/42tunnel

# ============================================================
# 8. README.md
# ============================================================
cat > ~/42log/README.md << 'MDEOF'
# 42log

Мессенджер для Termux. Временные комнаты 1-на-1 по одноразовым ключам.
Текст шифруется в "журнал ошибок терминала".

## Запуск

1. Сервер:
   в админ-консоли: `newroom` → получишь КЛЮЧ.

2. Туннель (для связи через интернет):
   Запиши порт из строки `tcp://serveo.net:XXXXX`.

3. Клиент:
   - хост: `serveo.net` (или `127.0.0.1` для локального теста)
   - порт: из туннеля (или `5555`)
   - ник: любой
   - `/join <КЛЮЧ>`

4. Дешифратор:
   Меню: расшифровать/зашифровать/выход.

## Команды клиента

- `/join <ключ>` — войти в комнату
- `/rooms` — список моих комнат
- `/switch <N>` — переключиться на комнату N
- `/leave` — выйти из текущей
- `/quit` — выйти из мессенджера

## Команды сервера

- `newroom` — создать комнату
- `rooms` — список
- `kick <ник>` — отключить юзера
- `close <ключ>` — закрыть комнату
- `quit` — остановить сервер

## Как это работает

Каждая русская буква заменяется на типичную ошибку терминала.
Пример: "привет" → 6 строк ошибок, каждая соответствует букве.
Обратное преобразование делает дешифратор в папке 42dec.

## ⚠️ Безопасность

Шифр — не криптография! Это подстановка, ломается частотным анализом.
Защищает от случайного взгляда, не от целенаправленного перехвата.

Для реальной защиты добавь Tor (скрывает IP) и E2E-шифрование.
MDEOF

# ============================================================
# 9. Финальное сообщение
# ============================================================
echo
echo "========================================"
echo "    ✅ Установка завершена!"
echo "========================================"
echo
echo "Ярлыки:"
echo " 42log-server   — запустить сервер"
echo " 42log-client   — запустить клиент"
echo " 42tunnel       — SSH-туннель через serveo"
echo " 42dec          — дешифратор"
echo
echo "Файлы:"
echo " ~/42log/    — мессенджер"
echo " ~/42dec/    — дешифратор"
echo
echo "Читай: ~/42log/README.md"
echo
echo "Первый запуск:"
echo "  1) открой новую сессию: 42log-server"
echo "  2) во второй сессии:    42tunnel"
echo "  3) в третьей:           42log-client"
echo
