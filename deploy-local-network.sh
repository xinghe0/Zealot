#!/bin/bash

# Zealot 局域网部署脚本（无需域名）
# 适用于内网环境和开发测试

set -e

echo "🏠 Zealot 局域网部署脚本"
echo "========================="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 获取本机IP地址
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        LOCAL_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    else
        print_warning "无法自动获取IP地址，请手动输入"
        read -p "请输入本机IP地址: " LOCAL_IP
    fi
    echo "$LOCAL_IP"
}

print_message "检测网络配置..."
LOCAL_IP=$(get_local_ip)

if [[ -z "$LOCAL_IP" ]]; then
    print_warning "无法获取本机IP地址"
    read -p "请手动输入本机IP地址: " LOCAL_IP
fi

echo ""
print_message "网络配置信息："
echo "🌐 本机IP地址: $LOCAL_IP"
echo "📱 移动设备访问地址: https://$LOCAL_IP"
echo "💻 本机访问地址: https://localhost 或 https://$LOCAL_IP"
echo ""

# 获取管理员密码
read -s -p "🔐 请输入Zealot管理员密码 (默认: ze@l0t): " ADMIN_PASSWORD
echo ""
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"ze@l0t"}

print_warning "注意事项："
echo "1. 使用自签名证书，浏览器会显示'不安全'警告"
echo "2. 首次访问需要点击'高级' -> '继续访问'"
echo "3. 仅适用于内网环境，不建议公网使用"
echo ""

read -p "确认开始部署? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 部署已取消"
    exit 1
fi

# 创建目录
print_message "创建目录结构..."
mkdir -p data/{postgres,uploads,backup}
mkdir -p nginx/ssl

# 更新配置
print_message "更新配置文件..."
sed -i.bak "s/ZEALOT_DOMAIN: 192.168.203.6/ZEALOT_DOMAIN: $LOCAL_IP/" docker-compose.yml
sed -i.bak "s/server_name localhost 192.168.203.6 zealot.local;/server_name localhost $LOCAL_IP;/" nginx/nginx.conf
sed -i.bak "s/ZEALOT_ADMIN_PASSWORD: ze@l0t/ZEALOT_ADMIN_PASSWORD: $ADMIN_PASSWORD/" docker-compose.yml

# 生成SSL证书
print_message "生成自签名SSL证书..."
./generate-ssl.sh

# 启动服务
print_message "启动Zealot服务..."
docker-compose up -d

# 等待服务启动
print_message "等待服务启动完成..."
sleep 30

# 初始化数据库
print_message "初始化数据库..."
docker-compose exec -T zealot rails db:create db:migrate db:seed || true

# 创建快捷脚本
cat > access-info.sh << EOF
#!/bin/bash

echo "📱 Zealot 移动应用分发平台"
echo "=========================="
echo ""
echo "🌐 访问地址:"
echo "   本机访问: https://localhost"
echo "   局域网访问: https://$LOCAL_IP"
echo ""
echo "👤 管理员账户:"
echo "   邮箱: admin@zealot.com"
echo "   密码: $ADMIN_PASSWORD"
echo ""
echo "⚠️  首次访问提示:"
echo "   1. 浏览器会显示'连接不安全'警告"
echo "   2. 点击'高级'或'详细信息'"
echo "   3. 选择'继续访问'或'接受风险并继续'"
echo ""
echo "🔧 服务管理:"
echo "   查看状态: docker-compose ps"
echo "   查看日志: docker-compose logs -f"
echo "   重启服务: docker-compose restart"
echo "   停止服务: docker-compose down"
EOF

chmod +x access-info.sh

echo ""
print_message "🎉 部署完成！"
echo ""
echo "📋 访问信息："
echo "   🌐 本机访问: https://localhost"
echo "   📱 局域网访问: https://$LOCAL_IP"
echo "   👤 管理员: admin@zealot.com"
echo "   🔐 密码: $ADMIN_PASSWORD"
echo ""
echo "📱 移动设备访问步骤："
echo "   1. 确保设备连接同一WiFi网络"
echo "   2. 打开浏览器访问: https://$LOCAL_IP"
echo "   3. 忽略证书警告，选择继续访问"
echo ""
echo "💡 提示: 运行 ./access-info.sh 可随时查看访问信息"
echo ""
print_message "局域网部署完成！"