#!/bin/bash

# Zealot + Let's Encrypt 完整部署脚本
# 适用于生产环境部署

set -e

echo "🚀 Zealot + Let's Encrypt 部署脚本"
echo "=================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色消息
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要条件
print_message "检查系统环境..."

# 检查Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker未安装，请先安装Docker"
    exit 1
fi

# 检查Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

# 检查是否为root用户（生产环境通常需要）
if [[ $EUID -eq 0 ]]; then
    print_warning "正在以root用户运行"
fi

# 获取配置信息
echo ""
print_message "请提供部署配置信息："

# 获取域名
while true; do
    read -p "📝 请输入您的域名 (例: zealot.yourdomain.com): " DOMAIN
    if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        print_error "请输入有效的域名"
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

# 确认配置
echo ""
print_message "配置确认："
echo "🌐 域名: $DOMAIN"
echo "📧 邮箱: $EMAIL"
echo "👤 管理员邮箱: admin@zealot.com"
echo ""

read -p "确认开始部署? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "部署已取消"
    exit 1
fi

# 创建必要目录
print_message "创建目录结构..."
mkdir -p certbot/www certbot/conf
mkdir -p data/{postgres,uploads,backup}
mkdir -p nginx/ssl

# 更新配置文件
print_message "更新配置文件..."

# 复制Let's Encrypt配置文件
cp docker-compose.letsencrypt.yml docker-compose.yml
cp nginx/nginx.letsencrypt.conf nginx/nginx.conf

# 替换域名占位符
sed -i.bak "s/your-domain.com/$DOMAIN/g" docker-compose.yml
sed -i.bak "s/your-domain.com/$DOMAIN/g" nginx/nginx.conf

# 更新管理员密码
sed -i.bak "s/ZEALOT_ADMIN_PASSWORD: ze@l0t/ZEALOT_ADMIN_PASSWORD: $ADMIN_PASSWORD/" docker-compose.yml

# 生成新的SECRET_KEY_BASE
SECRET_KEY=$(openssl rand -hex 64)
sed -i.bak "s/SECRET_KEY_BASE: .*/SECRET_KEY_BASE: $SECRET_KEY/" docker-compose.yml

print_message "启动临时HTTP服务器..."
# 启动nginx用于Let's Encrypt验证
docker-compose up -d nginx

# 等待nginx启动
sleep 10

print_message "申请Let's Encrypt证书..."
# 申请证书
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot/ \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

# 检查证书是否申请成功
if [[ ! -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]]; then
    print_error "证书申请失败，请检查域名DNS解析"
    exit 1
fi

print_message "证书申请成功！"

# 重启所有服务
print_message "启动完整服务..."
docker-compose down
docker-compose up -d

# 等待服务启动
print_message "等待服务启动完成..."
sleep 30

# 初始化数据库
print_message "初始化数据库..."
docker-compose exec -T zealot rails db:create db:migrate db:seed || true

# 创建证书自动续期脚本
print_message "设置证书自动续期..."
cat > renew-cert.sh << 'EOF'
#!/bin/bash

# Let's Encrypt证书自动续期脚本

cd "$(dirname "$0")"

echo "🔄 检查证书续期..."
docker-compose run --rm certbot renew

if [[ $? -eq 0 ]]; then
    echo "📋 重启Nginx以加载新证书..."
    docker-compose restart nginx
    echo "✅ 证书续期完成"
else
    echo "❌ 证书续期失败"
fi
EOF

chmod +x renew-cert.sh

# 设置定时任务提示
echo ""
print_message "部署完成！"
echo ""
echo "🎉 Zealot已成功部署并启用Let's Encrypt证书！"
echo ""
echo "📋 部署信息："
echo "   🌐 访问地址: https://$DOMAIN"
echo "   👤 管理员邮箱: admin@zealot.com"
echo "   🔐 管理员密码: $ADMIN_PASSWORD"
echo ""
echo "📅 重要提醒："
echo "   Let's Encrypt证书有效期90天，请设置自动续期："
echo "   sudo crontab -e"
echo "   添加: 0 3 * * * $(pwd)/renew-cert.sh >> $(pwd)/renew.log 2>&1"
echo ""
echo "🛠  常用命令："
echo "   查看服务状态: docker-compose ps"
echo "   查看日志: docker-compose logs -f"
echo "   重启服务: docker-compose restart"
echo "   手动续期证书: ./renew-cert.sh"
echo ""
print_message "部署脚本执行完成！"