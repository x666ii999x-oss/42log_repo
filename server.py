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
