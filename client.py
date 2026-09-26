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
