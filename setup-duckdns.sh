#!/bin/bash

# DuckDNS + Let's Encrypt 免费域名部署脚本
# 无需购买域名，使用免费的DuckDNS服务

set -e

echo "🦆 DuckDNS + Zealot 部署脚本"
echo "============================"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_message "DuckDNS 是一个免费的动态DNS服务"
echo ""
echo "📋 使用步骤："
echo "1. 访问 https://www.duckdns.org"
echo "2. 使用GitHub/Google账户登录"
echo "3. 创建一个子域名 (例: myapp.duckdns.org)"
echo "4. 获取您的Token"
echo ""

read -p "是否已经完成DuckDNS注册? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    print_warning "请先完成以下步骤："
    echo "1. 访问 https://www.duckdns.org"
    echo "2. 登录并创建域名"
    echo "3. 记录您的域名和Token"
    echo "4. 重新运行此脚本"
    exit 1
fi

echo ""
print_message "请提供DuckDNS配置信息："

# 获取DuckDNS域名
while true; do
    read -p "📝 请输入您的DuckDNS域名 (例: myapp.duckdns.org): " DUCKDNS_DOMAIN
    if [[ -n "$DUCKDNS_DOMAIN" && "$DUCKDNS_DOMAIN" =~ \.duckdns\.org$ ]]; then
        break
    else
        print_error "请输入有效的DuckDNS域名 (必须以.duckdns.org结尾)"
    fi
done

# 获取DuckDNS Token
while true; do
    read -p "🔑 请输入您的DuckDNS Token: " DUCKDNS_TOKEN
    if [[ -n "$DUCKDNS_TOKEN" && ${#DUCKDNS_TOKEN} -eq 36 ]]; then
        break
    else
        print_error "请输入有效的DuckDNS Token (36位字符)"
    fi
done

# 获取邮箱
while true; do
    read -p "📧 请输入您的邮箱地址: " EMAIL
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        print_error "请输入有效的邮箱地址"
    fi
done

# 获取管理员密码
read -s -p "🔐 请输入Zealot管理员密码 (默认: ze@l0t): " ADMIN_PASSWORD
echo ""
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"ze@l0t"}

echo ""
print_message "配置确认："
echo "🌐 DuckDNS域名: $DUCKDNS_DOMAIN"
echo "📧 邮箱: $EMAIL"
echo "👤 管理员邮箱: admin@zealot.com"
echo ""

read -p "确认开始部署? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "部署已取消"
    exit 1
fi

# 获取当前公网IP
print_message "获取公网IP地址..."
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [[ -z "$PUBLIC_IP" ]]; then
    print_error "无法获取公网IP地址"
    exit 1
fi
echo "🌐 当前公网IP: $PUBLIC_IP"

# 更新DuckDNS记录
print_message "更新DuckDNS DNS记录..."
SUBDOMAIN=$(echo "$DUCKDNS_DOMAIN" | cut -d'.' -f1)
RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")

if [[ "$RESPONSE" == "OK" ]]; then
    print_message "DuckDNS记录更新成功"
else
    print_error "DuckDNS记录更新失败: $RESPONSE"
    exit 1
fi

# 等待DNS传播
print_message "等待DNS记录传播 (30秒)..."
sleep 30

# 验证DNS解析
print_message "验证DNS解析..."
RESOLVED_IP=$(nslookup "$DUCKDNS_DOMAIN" | grep "Address:" | tail -1 | cut -d' ' -f2)
if [[ "$RESOLVED_IP" == "$PUBLIC_IP" ]]; then
    print_message "DNS解析验证成功"
else
    print_warning "DNS解析可能需要更多时间，继续部署..."
fi

# 创建目录
print_message "创建目录结构..."
mkdir -p certbot/{www,conf}
mkdir -p data/{postgres,uploads,backup}
mkdir -p nginx/ssl

# 更新配置文件
print_message "更新配置文件..."
cp docker-compose.letsencrypt.yml docker-compose.yml
cp nginx/nginx.letsencrypt.conf nginx/nginx.conf

# 替换域名
sed -i.bak "s/your-domain.com/$DUCKDNS_DOMAIN/g" docker-compose.yml
sed -i.bak "s/your-domain.com/$DUCKDNS_DOMAIN/g" nginx/nginx.conf

# 更新管理员密码
sed -i.bak "s/ZEALOT_ADMIN_PASSWORD: ze@l0t/ZEALOT_ADMIN_PASSWORD: $ADMIN_PASSWORD/" docker-compose.yml

# 生成新的SECRET_KEY_BASE
SECRET_KEY=$(openssl rand -hex 64)
sed -i.bak "s/SECRET_KEY_BASE: .*/SECRET_KEY_BASE: $SECRET_KEY/" docker-compose.yml

print_message "启动临时HTTP服务器..."
docker-compose up -d nginx

# 等待服务启动
sleep 10

print_message "申请Let's Encrypt证书..."
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot/ \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DUCKDNS_DOMAIN"

# 检查证书
if [[ ! -f "certbot/conf/live/$DUCKDNS_DOMAIN/fullchain.pem" ]]; then
    print_error "证书申请失败"
    exit 1
fi

print_message "证书申请成功！"

# 重启服务
print_message "启动完整服务..."
docker-compose down
docker-compose up -d

# 等待服务启动
sleep 30

# 初始化数据库
print_message "初始化数据库..."
docker-compose exec -T zealot rails db:create db:migrate db:seed || true

# 创建DuckDNS更新脚本
print_message "创建DuckDNS自动更新脚本..."
cat > update-duckdns.sh << EOF
#!/bin/bash

# DuckDNS IP地址自动更新脚本

SUBDOMAIN="$SUBDOMAIN"
TOKEN="$DUCKDNS_TOKEN"

# 获取当前公网IP
CURRENT_IP=\$(curl -s https://api.ipify.org)

# 更新DuckDNS记录
RESPONSE=\$(curl -s "https://www.duckdns.org/update?domains=\$SUBDOMAIN&token=\$TOKEN&ip=\$CURRENT_IP")

if [[ "\$RESPONSE" == "OK" ]]; then
    echo "\$(date): DuckDNS更新成功 - IP: \$CURRENT_IP"
else
    echo "\$(date): DuckDNS更新失败 - \$RESPONSE"
fi
EOF

chmod +x update-duckdns.sh

# 创建证书续期脚本
cat > renew-cert.sh << 'EOF'
#!/bin/bash

cd "$(dirname "$0")"

echo "🔄 检查证书续期..."
docker-compose run --rm certbot renew

if [[ $? -eq 0 ]]; then
    echo "📋 重启Nginx..."
    docker-compose restart nginx
    echo "✅ 证书续期完成"
else
    echo "❌ 证书续期失败"
fi
EOF

chmod +x renew-cert.sh

echo ""
print_message "🎉 部署完成！"
echo ""
echo "📋 部署信息："
echo "   🌐 访问地址: https://$DUCKDNS_DOMAIN"
echo "   👤 管理员邮箱: admin@zealot.com"
echo "   🔐 管理员密码: $ADMIN_PASSWORD"
echo ""
echo "🔄 自动化任务设置建议："
echo "   # 编辑定时任务"
echo "   crontab -e"
echo ""
echo "   # 添加以下行："
echo "   # 每5分钟更新DuckDNS IP"
echo "   */5 * * * * $(pwd)/update-duckdns.sh >> $(pwd)/duckdns.log 2>&1"
echo "   # 每天凌晨3点检查证书续期"
echo "   0 3 * * * $(pwd)/renew-cert.sh >> $(pwd)/renew.log 2>&1"
echo ""
echo "🛠  常用命令："
echo "   查看服务状态: docker-compose ps"
echo "   查看日志: docker-compose logs -f"
echo "   手动更新IP: ./update-duckdns.sh"
echo "   手动续期证书: ./renew-cert.sh"
echo ""
print_message "DuckDNS + Let's Encrypt 部署完成！"