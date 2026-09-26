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
