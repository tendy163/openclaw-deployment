# OpenClaw 自动化部署脚本

针对 OpenCloudOS 9.4 服务器的完整部署解决方案。基于已验证服务器环境优化，部署时间从70分钟优化至45分钟。

## 🎯 已验证服务器环境

- **操作系统**: OpenCloudOS 9.4 (内核 6.6.117)
- **Python环境**: Python 3.11.6, FastAPI 0.135.2, Uvicorn 0.42.0
- **系统资源**: 7.4GB 内存, 172GB 磁盘空间
- **权限配置**: sudo免密, 关键目录可写
- **网络连接**: GitHub/Tushare Pro 可达

## 🚀 快速开始

### 前提条件
1. 服务器 IP: `134.175.176.7`
2. 用户名: `devuser`
3. 密码: `DevPass123!`
4. SSH 端口: `22`

### 部署步骤

```bash
# 1. 下载部署脚本
git clone https://github.com/tendy163/openclaw-deployment.git
cd openclaw-deployment

# 2. 授予执行权限
chmod +x deploy.sh

# 3. 执行部署
./deploy.sh
```

### 预期输出
部署脚本将自动完成以下步骤：
1. ✅ 环境验证（跳过已安装的Python/FastAPI）
2. ✅ Supervisor安装与配置
3. ✅ 端口映射配置（9000/8080/8443）
4. ✅ openclaw代码克隆
5. ✅ 服务启动与验证
6. ✅ 防火墙规则配置

## 🔧 部署架构

### 端口映射（避让已有服务）
| 服务 | 原端口 | 新端口 | 原因 |
|------|--------|--------|------|
| FastAPI | 8000 | 9000 | 避免潜在冲突 |
| HTTP代理 | 80 | 8080 | 80端口未监听 |
| HTTPS代理 | 443 | 8443 | 443端口未监听 |
| 监控端口 | 8888 | 9001 | 8888已被占用 |

### 服务管理
- **Supervisor**: 进程管理，自动重启
- **systemd**: Supervisor系统服务
- **iptables**: 防火墙规则

### 部署目录结构
```
/opt/openclaw/
├── backend/     # FastAPI后端代码
├── frontend/    # 前端代码（可选）
├── scripts/     # 管理脚本
└── logs/        # 日志文件
```

## 📊 部署时间线

| 阶段 | 时间 | 说明 |
|------|------|------|
| 环境验证 | 2分钟 | 检查Python/FastAPI（已预装） |
| Supervisor安装 | 5分钟 | yum安装和配置 |
| openclaw部署 | 20分钟 | 代码克隆和依赖安装 |
| 端口配置 | 5分钟 | 调整端口映射 |
| 服务启动 | 5分钟 | Supervisor启动服务 |
| 验证测试 | 8分钟 | API连通性和功能验证 |
| **总计** | **45分钟** | **比原计划节省25分钟** |

## 🛡️ 安全配置

### 防火墙规则
```bash
# 开放必要端口
iptables -A INPUT -p tcp --dport 9000 -j ACCEPT  # FastAPI
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT  # HTTP代理
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT  # HTTPS代理
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH（保持开放）
```

### 服务隔离
- 使用`devuser`非root用户运行服务
- Supervisor配置用户限制
- 日志轮转和监控

## 🔍 部署验证

部署完成后执行验证：

```bash
# 1. 检查服务状态
sudo supervisorctl status openclaw

# 2. 验证端口监听
sudo ss -tuln | grep -E ':(9000|8080|8443)'

# 3. API健康检查
curl http://localhost:9000/health

# 4. Tushare Pro连通性
curl -X POST http://localhost:9000/api/v1/tushare/test
```

## 🚨 故障排除

### 常见问题

#### 1. SSH连接失败
```bash
# 检查网络连接
ping 134.175.176.7

# 检查SSH服务
ssh -v devuser@134.175.176.7
```

#### 2. Supervisor安装失败
```bash
# 手动安装
sudo yum install -y supervisor
sudo systemctl enable supervisor
sudo systemctl start supervisor
```

#### 3. 端口冲突
修改 `deploy.sh` 中的端口配置：
```bash
FASTAPI_PORT=9000      # 可改为其他可用端口
HTTP_PORT=8080
HTTPS_PORT=8443
```

#### 4. openclaw代码拉取失败
```bash
# 手动克隆
cd /opt
sudo rm -rf openclaw
sudo git clone https://github.com/xg-ai/openclaw.git
```

## 🔄 后续自动化

### GitHub Actions 配置示例
```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Server
        uses: appleboy/ssh-action@v0.1.4
        with:
          host: 134.175.176.7
          username: devuser
          password: DevPass123!
          script: |
            cd /opt/openclaw-deployment
            git pull
            ./deploy.sh --update
```

### 更新部署
```bash
# 仅更新代码，不重新配置环境
./deploy.sh --update
```

## 📞 支持与维护

- **技术负责人**: 小马（后端开发专家）
- **测试负责人**: 小策（测试开发工程师）
- **部署时间**: 45分钟（优化后）
- **技术支持**: 实时监控部署过程

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件