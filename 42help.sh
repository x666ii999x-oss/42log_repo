#!/data/data/com.termux/files/usr/bin/bash

# Показываем ASCII-баннер 42LOG (фиолетовый, с тенью)
cd ~/42log 2>/dev/null
python -c "from banner import print_banner; print_banner()" 2>/dev/null

while true; do
    echo
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║          4 2 L O G   ·   menu        ║"
    echo "  ╚══════════════════════════════════════╝"
    echo
    echo "    1)  сервер       — создать комнату"
    echo "    2)  туннель      — serveo.net"
    echo "    3)  клиент       — чат"
    echo "    4)  дешифратор   — 42dec"
    echo "    5)  справка      — что и как"
    echo "    0)  выход"
    echo
    read -p "  выбор: " c

    case "$c" in
        1)
            cd ~/42log
            python server.py
            ;;
        2)
            echo
            echo "  [*] Туннель через serveo.net..."
            echo "  [*] Жди строку 'tcp://serveo.net:XXXXX' и передай её собеседнику."
            echo
            ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
                -R 0:localhost:5555 serveo.net
            ;;
        3)
            cd ~/42log
            python client.py
            ;;
        4)
            cd ~/42log/42dec
            python decryptor.py
            ;;
        5)
            echo
            echo "  ПОРЯДОК ЗАПУСКА:"
            echo "   1) 42 → 1 (сервер) → newroom → получишь ключ"
            echo "   2) 42 → 2 (туннель) → запиши порт"
            echo "   3) 42 → 3 (клиент) → хост, порт, ник, /join <ключ>"
            echo "   4) 42 → 4 (дешифратор) → расшифровка"
            echo
            echo "  КОМАНДЫ КЛИЕНТА:"
            echo "   /join <ключ>  /rooms  /switch <N>  /leave  /quit"
            echo
            read -p "  Enter для возврата в меню..."
            ;;
        0|q|quit|exit|"")
            echo
            echo "  выходим..."
            exit 0
            ;;
        *)
            echo
            echo "  нет такого пункта"
            sleep 1
            ;;
    esac

    echo
    echo "  [нажми Enter для возврата в меню]"
    read
done
