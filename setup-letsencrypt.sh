#!/bin/bash

# Let's Encrypt SSL证书自动化设置脚本
# 适用于Zealot Docker部署

set -e

echo "🔐 Let's Encrypt SSL证书设置脚本"
echo "=================================="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  请不要以root用户运行此脚本"
   exit 1
fi

# 获取域名
read -p "📝 请输入您的域名 (例: zealot.yourdomain.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo "❌ 域名不能为空"
    exit 1
fi

# 获取邮箱
read -p "📧 请输入您的邮箱地址: " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo "❌ 邮箱不能为空"
    exit 1
fi

echo "🌐 域名: $DOMAIN"
echo "📧 邮箱: $EMAIL"
echo ""

# 确认继续
read -p "确认继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 1
fi

echo "📦 安装Certbot..."

# 检查操作系统并安装Certbot
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if ! command -v brew &> /dev/null; then
        echo "❌ 请先安装Homebrew: https://brew.sh/"
        exit 1
    fi
    brew install certbot
elif [[ -f /etc/debian_version ]]; then
    # Debian/Ubuntu
    sudo apt update
    sudo apt install -y certbot
elif [[ -f /etc/redhat-release ]]; then
    # CentOS/RHEL
    sudo yum install -y epel-release
    sudo yum install -y certbot
else
    echo "❌ 不支持的操作系统，请手动安装Certbot"
    exit 1
fi

echo "🛑 停止Zealot服务以释放80端口..."
docker-compose down

echo "🔐 申请Let's Encrypt证书..."

# 使用standalone模式申请证书
sudo certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

# 检查证书是否申请成功
if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    echo "❌ 证书申请失败"
    exit 1
fi

echo "📋 复制证书到Nginx目录..."

# 创建SSL目录
mkdir -p nginx/ssl

# 复制证书文件
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "nginx/ssl/zealot.crt"
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "nginx/ssl/zealot.key"

# 修改文件权限
sudo chown $(whoami):$(whoami) nginx/ssl/zealot.crt nginx/ssl/zealot.key
chmod 644 nginx/ssl/zealot.crt
chmod 600 nginx/ssl/zealot.key

echo "⚙️  更新Docker Compose配置..."

# 更新docker-compose.yml中的域名
sed -i.bak "s/ZEALOT_DOMAIN: 192.168.203.6/ZEALOT_DOMAIN: $DOMAIN/" docker-compose.yml
sed -i.bak "s/server_name localhost 192.168.203.6 zealot.local;/server_name $DOMAIN;/" nginx/nginx.conf

echo "🚀 重新启动Zealot服务..."
docker-compose up -d

echo "✅ Let's Encrypt证书设置完成！"
echo ""
echo "🌐 现在可以通过 https://$DOMAIN 访问Zealot"
echo "🔒 证书有效期90天，建议设置自动续期"
echo ""
echo "📅 设置自动续期 (可选):"
echo "   sudo crontab -e"
echo "   添加: 0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'cd $(pwd) && ./update-ssl.sh'"

# 创建证书更新脚本
cat > update-ssl.sh << 'EOF'
#!/bin/bash
# SSL证书更新脚本

DOMAIN=$(grep "ZEALOT_DOMAIN:" docker-compose.yml | cut -d':' -f2 | tr -d ' ')

if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    echo "📋 更新SSL证书..."
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "nginx/ssl/zealot.crt"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "nginx/ssl/zealot.key"
    sudo chown $(whoami):$(whoami) nginx/ssl/zealot.crt nginx/ssl/zealot.key
    chmod 644 nginx/ssl/zealot.crt
    chmod 600 nginx/ssl/zealot.key
    
    echo "🔄 重启Nginx..."
    docker-compose restart nginx
    echo "✅ SSL证书更新完成"
else
    echo "❌ 证书文件不存在"
fi
EOF

chmod +x update-ssl.sh

echo ""
echo "🎉 所有设置已完成！"