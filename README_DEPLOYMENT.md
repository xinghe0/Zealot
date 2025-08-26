# Zealot 移动应用分发平台 - Docker部署版

这是一个完整配置的 Zealot 6.0.4 移动应用分发平台，包含 Docker Compose 部署配置和 HTTPS 支持。

## 🚀 快速部署

### 1. 克隆仓库
```bash
git clone <your-repo-url>
cd zealot-deployment
```

### 2. 启动服务
```bash
# 生成SSL证书（首次运行）
./generate-ssl.sh

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 3. 访问应用

- **本机访问**: https://localhost 或 https://192.168.203.6
- **其他设备访问**: https://你的IP地址
- **管理员账户**: 
  - 邮箱: `admin@zealot.com`
  - 密码: `ze@l0t`

## 📋 系统架构

- **Nginx**: 反向代理 + SSL终止 (端口 80/443)
- **Zealot**: Ruby on Rails 应用 (内部端口 80)
- **PostgreSQL**: 数据库 (端口 5432)

## 🔧 配置说明

### 环境变量
主要配置在 `docker-compose.yml` 中：

```yaml
environment:
  ZEALOT_DOMAIN: 192.168.203.6        # 你的IP地址
  ZEALOT_HTTPS: 'true'                # 启用HTTPS
  ZEALOT_ADMIN_EMAIL: admin@zealot.com
  ZEALOT_ADMIN_PASSWORD: ze@l0t
```

### SSL证书
- 自签名证书位于 `nginx/ssl/`
- 支持 localhost 和你的局域网IP
- 生产环境建议使用 Let's Encrypt

### 数据持久化
- 数据库: `./data/postgres/`
- 上传文件: `./data/uploads/`
- 备份文件: `./data/backup/`

## 🛠 常用命令

```bash
# 查看日志
docker-compose logs -f zealot
docker-compose logs -f nginx

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 更新SSL证书
./generate-ssl.sh
docker-compose restart nginx

# 备份数据
docker-compose exec postgres pg_dump -U zealot zealot > backup.sql

# 进入容器
docker-compose exec zealot bash
```

## 📱 功能特性

- ✅ iOS/Android 应用分发
- ✅ 多渠道管理
- ✅ 版本控制
- ✅ 用户权限管理
- ✅ WebHook 通知
- ✅ REST API + GraphQL
- ✅ 应用元信息解析
- ✅ 设备管理
- ✅ 二维码安装

## 🔐 安全配置

- HTTPS 强制启用
- 自签名SSL证书
- 数据库密码保护
- 文件上传限制
- 跨域请求控制

## 🐛 故障排除

### 服务无法启动
```bash
# 检查端口占用
lsof -i :80
lsof -i :443

# 检查Docker状态
docker-compose ps
docker-compose logs
```

### 证书问题
```bash
# 重新生成证书
rm -rf nginx/ssl/*
./generate-ssl.sh
docker-compose restart nginx
```

### 数据库问题
```bash
# 重置数据库
docker-compose down
rm -rf data/postgres
docker-compose up -d
docker-compose exec zealot rails db:create db:migrate db:seed
```

## 📞 支持

- [Zealot 官方文档](https://zealot.ews.im/)
- [GitHub Issues](https://github.com/tryzealot/zealot/issues)
- [Docker Hub](https://hub.docker.com/r/tryzealot/zealot)

## 📄 许可证

本项目基于 Zealot 开源项目，遵循相同的许可证条款。