
# Ярлык "42" — общая справка
cat > $PREFIX/bin/42 << 'SH'
#!/data/data/com.termux/files/usr/bin/bash
echo
echo "  ╔══════════════════════════════════════╗"
echo "  ║          4 2 L O G   ·   help        ║"
echo "  ╚══════════════════════════════════════╝"
echo
echo "  ЗАПУСК:"
echo "   42log-server   — сервер (создать комнату: newroom)"
echo "   42tunnel       — туннель через serveo.net"
echo "   42log-client   — клиент (чат)"
echo "   42dec          — дешифратор"
echo
echo "  ПОРЯДОК:  server → tunnel → client → dec"
echo
SH
chmod +x $PREFIX/bin/42
