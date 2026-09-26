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
