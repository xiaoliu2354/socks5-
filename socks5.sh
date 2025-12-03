#!/bin/bash
# SOCKS5代理服务器自动部署脚本（支持IPv6 + 用户名密码认证）

if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 运行脚本"
    exit 1
fi

echo "🔧 安装 Dante ..."
apt update -y >/dev/null 2>&1
apt install -y dante-server curl netcat-openbsd >/dev/null 2>&1

# 配置端口
read -p "🛡️ 输入代理端口 (默认1080): " PORT
PORT=${PORT:-1080}

# 账号密码
USER="xiaoliu"
PASS="ENlilui123"

# 获取网卡
INTERFACE=$(ip -6 route | awk '/default/ {print $5; exit}')
[ -z "$INTERFACE" ] && INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

echo "📝 生成 /etc/danted.conf ..."

cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: 0.0.0.0 port = $PORT
internal: :: port = $PORT
external: $INTERFACE

# 认证方式：用户名密码
clientmethod: username
socksmethod: username

user.privileged: root
user.notprivileged: nobody
user.libwrap: nobody

# 定义用户密码
userlist: "/etc/danted_users"

# ----------------- 客户端访问控制 -----------------
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: ::/0 to: ::/0
    log: connect disconnect error
}

# 拒绝其他
socks block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF

# 写入用户名密码
echo "$USER:$PASS" > /etc/danted_users
chmod 600 /etc/danted_users

echo "🔥 配置防火墙..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/tcp >/dev/null 2>&1
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=$PORT/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
fi

echo "🚀 重启 Dante ..."
systemctl restart danted
systemctl enable danted >/dev/null 2>&1

sleep 1

echo "🔍 测试端口..."
if nc -zv 127.0.0.1 $PORT >/dev/null 2>&1; then
    IPV4=$(curl -s4 ifconfig.me)
    IPV6=$(curl -s6 ifconfig.me)
    echo ""
    echo "========================================="
    echo "🎉 SOCKS5 代理已成功部署"
    echo "地址: $IPV4 / $IPV6"
    echo "端口: $PORT"
    echo "用户名: $USER"
    echo "密码: $PASS"
    echo "协议: SOCKS5"
    echo "========================================="
else
    echo "❌ 启动失败，请检查 /etc/danted.conf"
    exit 1
fi
