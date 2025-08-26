# Zealot + Let's Encrypt 部署指南

本指南将帮助您在生产环境中部署Zealot，并配置免费的Let's Encrypt SSL证书。

## 🔐 Let's Encrypt 简介

Let's Encrypt是一个免费、自动化、开放的证书颁发机构（CA），提供：

- ✅ **完全免费** - 永久免费的SSL证书
- ✅ **自动化** - 支持自动申请和续期
- ✅ **广泛信任** - 被所有主流浏览器信任
- ✅ **90天有效期** - 鼓励自动化管理

## 🚀 快速部署

### 前提条件

1. **服务器要求**：
   - Ubuntu 18.04+ / CentOS 7+ / macOS
   - Docker 和 Docker Compose 已安装
   - 拥有一个域名并指向服务器IP

2. **域名配置**：
   ```bash
   # 确保域名已正确解析到服务器IP
   nslookup your-domain.com
   ```

3. **防火墙设置**：
   ```bash
   # 开放必要端口
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 5432/tcp  # 如果需要外部数据库访问
   ```

### 一键部署

```bash
# 运行完整部署脚本
./deploy-with-letsencrypt.sh
```

脚本将自动完成：
- ✅ 环境检查
- ✅ 配置收集（域名、邮箱等）
- ✅ Let's Encrypt证书申请
- ✅ 服务启动
- ✅ 数据库初始化
- ✅ 自动续期脚本创建

### 手动部署

如果需要更多控制，可以分步执行：

#### 1. 准备配置文件

```bash
# 复制Let's Encrypt配置
cp docker-compose.letsencrypt.yml docker-compose.yml
cp nginx/nginx.letsencrypt.conf nginx/nginx.conf

# 替换域名（请替换your-domain.com）
sed -i 's/your-domain.com/zealot.yourdomain.com/g' docker-compose.yml
sed -i 's/your-domain.com/zealot.yourdomain.com/g' nginx/nginx.conf
```

#### 2. 创建目录结构

```bash
mkdir -p certbot/{www,conf}
mkdir -p data/{postgres,uploads,backup}
mkdir -p nginx/ssl
```

#### 3. 申请SSL证书

```bash
# 启动临时HTTP服务
docker-compose up -d nginx

# 申请证书
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot/ \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email \
    -d zealot.yourdomain.com
```

#### 4. 启动完整服务

```bash
# 重启所有服务
docker-compose down
docker-compose up -d

# 初始化数据库
docker-compose exec zealot rails db:create db:migrate db:seed
```

## 🔄 证书自动续期

Let's Encrypt证书有效期为90天，需要定期续期：

### 1. 手动续期

```bash
# 使用提供的脚本
./renew-cert.sh

# 或者直接使用docker-compose
docker-compose run --rm certbot renew
docker-compose restart nginx
```

### 2. 自动续期（推荐）

```bash
# 编辑系统定时任务
sudo crontab -e

# 添加以下行（每天凌晨3点检查续期）
0 3 * * * /path/to/your/zealot/renew-cert.sh >> /path/to/your/zealot/renew.log 2>&1
```

### 3. 检查续期状态

```bash
# 查看证书有效期
docker-compose run --rm certbot certificates

# 测试续期（不实际续期）
docker-compose run --rm certbot renew --dry-run
```

## 📋 配置文件说明

### docker-compose.letsencrypt.yml

包含Let's Encrypt专用配置：
- `certbot` 服务用于证书管理
- 挂载 `certbot/www` 用于ACME验证
- 挂载 `certbot/conf` 存储证书文件

### nginx.letsencrypt.conf

包含Let's Encrypt专用Nginx配置：
- HTTP服务器处理ACME验证
- HTTPS服务器使用Let's Encrypt证书
- 安全头配置
- 自动重定向HTTP到HTTPS

## 🛠 故障排除

### 证书申请失败

```bash
# 检查域名解析
nslookup your-domain.com

# 检查80端口是否可访问
curl -I http://your-domain.com/.well-known/acme-challenge/test

# 查看详细错误日志
docker-compose logs certbot
```

### 证书过期

```bash
# 强制续期
docker-compose run --rm certbot renew --force-renewal

# 重启服务
docker-compose restart nginx
```

### 服务无法启动

```bash
# 检查配置文件语法
docker-compose config

# 查看详细日志
docker-compose logs -f nginx
docker-compose logs -f zealot
```

## 🔒 安全最佳实践

### 1. SSL配置优化

- 使用TLS 1.2和1.3
- 配置强加密套件
- 启用HSTS
- 添加安全响应头

### 2. 防火墙配置

```bash
# Ubuntu/Debian
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 3. 定期备份

```bash
# 数据库备份
docker-compose exec postgres pg_dump -U zealot zealot > backup_$(date +%Y%m%d).sql

# 证书备份
tar -czf certbot_backup_$(date +%Y%m%d).tar.gz certbot/conf/
```

## 📊 监控和维护

### 1. 健康检查

```bash
# 检查服务状态
docker-compose ps

# 检查SSL证书状态
openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

### 2. 日志监控

```bash
# 实时查看日志
docker-compose logs -f --tail=100

# 查看特定服务日志
docker-compose logs nginx
docker-compose logs zealot
docker-compose logs certbot
```

### 3. 性能优化

```bash
# 查看资源使用情况
docker stats

# 优化数据库
docker-compose exec postgres psql -U zealot -d zealot -c "VACUUM ANALYZE;"
```

## 🎯 生产环境建议

1. **使用专用服务器** - 避免与其他服务共用
2. **定期备份** - 数据库和上传文件
3. **监控告警** - 设置证书过期提醒
4. **安全更新** - 定期更新Docker镜像
5. **访问日志** - 启用详细的访问日志记录

## 📞 技术支持

如果遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查 [Zealot官方文档](https://zealot.ews.im/)
3. 查看 [Let's Encrypt文档](https://letsencrypt.org/docs/)
4. 在GitHub提交Issue

---

🎉 现在您的Zealot已经配置了免费的Let's Encrypt SSL证书，可以安全地在生产环境中使用了！