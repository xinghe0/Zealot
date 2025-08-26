#!/bin/bash

# 创建SSL证书目录
mkdir -p nginx/ssl

# 获取本机IP地址
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# 生成自签名SSL证书，支持localhost和本机IP
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/zealot.key \
    -out nginx/ssl/zealot.crt \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=Zealot/OU=IT/CN=zealot.local" \
    -addext "subjectAltName=DNS:localhost,DNS:*.localhost,DNS:zealot.local,IP:127.0.0.1,IP:${LOCAL_IP}"

echo "✅ SSL证书已生成到 nginx/ssl/ 目录"
echo "   - 证书文件: nginx/ssl/zealot.crt"
echo "   - 私钥文件: nginx/ssl/zealot.key"
echo "   - 支持的访问地址:"
echo "     * https://localhost"
echo "     * https://${LOCAL_IP}"
echo ""
echo "🔒 现在可以使用以上地址访问Zealot了"