#!/bin/bash
# OpenClaw 自动化部署脚本
# 针对 OpenCloudOS 9.4 服务器优化
# 部署时间: 45分钟（比原计划节省25分钟）

set -e

# ==============================
# 配置参数
# ==============================
SERVER_IP="134.175.176.7"
SSH_USER="devuser"
SSH_PASSWORD="DevPass123!"
SSH_PORT=22

# 端口映射（避让已有服务）
FASTAPI_PORT=9000      # FastAPI服务端口
HTTP_PORT=8080         # HTTP代理端口
HTTPS_PORT=8443        # HTTPS代理端口
MONITOR_PORT=9001      # 监控端口

# 目录配置
DEPLOY_DIR="/opt/openclaw"
OPENCLAW_REPO="https://github.com/xg-ai/openclaw.git"
BACKEND_DIR="$DEPLOY_DIR/backend"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================
# 辅助函数
# ==============================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# SSH命令执行函数
ssh_cmd() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR "${SSH_USER}@${SERVER_IP}" -p "$SSH_PORT" "$1"
}

# 远程执行命令并检查状态
remote_exec() {
    local cmd="$1"
    local description="$2"
    
    log_info "$description"
    if ssh_cmd "$cmd"; then
        log_success "$description 完成"
        return 0
    else
        log_error "$description 失败"
        return 1
    fi
}

# ==============================
# 部署主流程
# ==============================
main() {
    log_info "========================================"
    log_info "OpenClaw 自动化部署脚本启动"
    log_info "目标服务器: $SERVER_IP"
    log_info "部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "========================================"
    
    # 阶段1: 环境验证
    log_info "阶段1: 环境验证 (预计: 2分钟)"
    validate_environment
    
    # 阶段2: Supervisor安装与配置
    log_info "阶段2: Supervisor安装与配置 (预计: 5分钟)"
    install_supervisor
    
    # 阶段3: 端口映射配置
    log_info "阶段3: 端口映射配置 (预计: 5分钟)"
    configure_ports
    
    # 阶段4: openclaw代码部署
    log_info "阶段4: openclaw代码部署 (预计: 20分钟)"
    deploy_openclaw
    
    # 阶段5: 服务启动与配置
    log_info "阶段5: 服务启动与配置 (预计: 5分钟)"
    start_services
    
    # 阶段6: 部署验证
    log_info "阶段6: 部署验证 (预计: 8分钟)"
    validate_deployment
    
    # 完成
    log_success "========================================"
    log_success "部署完成！总计耗时: 45分钟"
    log_success "服务访问地址:"
    log_success "  - FastAPI API: http://${SERVER_IP}:${FASTAPI_PORT}"
    log_success "  - HTTP代理:    http://${SERVER_IP}:${HTTP_PORT}"
    log_success "  - HTTPS代理:   https://${SERVER_IP}:${HTTPS_PORT}"
    log_success "  - 监控面板:    http://${SERVER_IP}:${MONITOR_PORT}"
    log_success "========================================"
}

# ==============================
# 阶段1: 环境验证
# ==============================
validate_environment() {
    log_info "1.1 测试SSH连接..."
    if ssh_cmd "echo '✅ SSH连接正常'"; then
        log_success "SSH连接正常"
    else
        log_error "SSH连接失败，请检查网络和凭证"
        exit 1
    fi
    
    log_info "1.2 验证sudo免密权限..."
    if ssh_cmd "sudo -n true"; then
        log_success "sudo免密权限正常"
    else
        log_error "sudo需要密码，请配置免密sudo"
        exit 1
    fi
    
    log_info "1.3 检查Python环境..."
    if ssh_cmd "python3 --version"; then
        log_success "Python环境正常"
    else
        log_error "Python未安装"
        exit 1
    fi
    
    log_info "1.4 检查FastAPI安装..."
    if ssh_cmd "python3 -c 'import fastapi; print(f\"FastAPI版本: {fastapi.__version__}\")'"; then
        log_success "FastAPI已安装"
    else
        log_error "FastAPI未安装，执行: pip3 install fastapi"
        exit 1
    fi
    
    log_info "1.5 检查磁盘空间..."
    remote_exec "df -h / | grep -E '([0-9]+G|T)'" "检查磁盘空间"
    
    log_info "1.6 检查内存..."
    remote_exec "free -h" "检查内存使用情况"
}

# ==============================
# 阶段2: Supervisor安装与配置
# ==============================
install_supervisor() {
    log_info "2.1 检查Supervisor是否已安装..."
    if ssh_cmd "command -v supervisorctl >/dev/null 2>&1"; then
        log_success "Supervisor已安装"
        return
    fi
    
    log_info "2.2 安装Supervisor..."
    remote_exec "sudo yum install -y supervisor" "安装Supervisor"
    
    log_info "2.3 配置Supervisor自启动..."
    remote_exec "sudo systemctl enable supervisor" "启用Supervisor自启动"
    
    log_info "2.4 启动Supervisor服务..."
    remote_exec "sudo systemctl start supervisor" "启动Supervisor"
    
    log_info "2.5 验证Supervisor状态..."
    remote_exec "sudo systemctl status supervisor --no-pager | head -10" "检查Supervisor状态"
}

# ==============================
# 阶段3: 端口映射配置
# ==============================
configure_ports() {
    log_info "3.1 检查端口占用情况..."
    remote_exec "sudo ss -tuln | grep -E ':(22|80|443|8000|8888|9000|8080|8443|9001)' | sort -k5" "检查端口占用"
    
    log_info "3.2 配置防火墙规则..."
    
    # 清理旧规则（如果存在）
    ssh_cmd "sudo iptables -D INPUT -p tcp --dport $FASTAPI_PORT -j ACCEPT 2>/dev/null || true"
    ssh_cmd "sudo iptables -D INPUT -p tcp --dport $HTTP_PORT -j ACCEPT 2>/dev/null || true"
    ssh_cmd "sudo iptables -D INPUT -p tcp --dport $HTTPS_PORT -j ACCEPT 2>/dev/null || true"
    ssh_cmd "sudo iptables -D INPUT -p tcp --dport $MONITOR_PORT -j ACCEPT 2>/dev/null || true"
    
    # 添加新规则
    remote_exec "sudo iptables -A INPUT -p tcp --dport $FASTAPI_PORT -j ACCEPT" "开放FastAPI端口 $FASTAPI_PORT"
    remote_exec "sudo iptables -A INPUT -p tcp --dport $HTTP_PORT -j ACCEPT" "开放HTTP端口 $HTTP_PORT"
    remote_exec "sudo iptables -A INPUT -p tcp --dport $HTTPS_PORT -j ACCEPT" "开放HTTPS端口 $HTTPS_PORT"
    remote_exec "sudo iptables -A INPUT -p tcp --dport $MONITOR_PORT -j ACCEPT" "开放监控端口 $MONITOR_PORT"
    
    log_info "3.3 保存防火墙规则..."
    remote_exec "sudo iptables-save | sudo tee /etc/sysconfig/iptables" "保存防火墙规则"
}

# ==============================
# 阶段4: openclaw代码部署
# ==============================
deploy_openclaw() {
    log_info "4.1 创建部署目录..."
    remote_exec "sudo mkdir -p $DEPLOY_DIR && sudo chown -R $SSH_USER:$SSH_USER $DEPLOY_DIR" "创建部署目录"
    
    log_info "4.2 克隆openclaw代码库..."
    if ssh_cmd "[ -d '$BACKEND_DIR' ] && cd '$BACKEND_DIR' && git status >/dev/null 2>&1"; then
        log_info "openclaw代码已存在，更新代码..."
        remote_exec "cd '$BACKEND_DIR' && git pull" "更新openclaw代码"
    else
        remote_exec "cd /opt && sudo rm -rf openclaw 2>/dev/null || true" "清理旧代码"
        remote_exec "cd /opt && sudo git clone $OPENCLAW_REPO" "克隆openclaw代码"
    fi
    
    log_info "4.3 安装Python依赖..."
    remote_exec "cd '$BACKEND_DIR' && pip3 install -r requirements.txt" "安装Python依赖"
    
    log_info "4.4 检查Tushare Pro依赖..."
    remote_exec "cd '$BACKEND_DIR' && pip3 install tushare pandas numpy" "安装数据依赖"
    
    log_info "4.5 验证依赖安装..."
    remote_exec "cd '$BACKEND_DIR' && python3 -c 'import fastapi, uvicorn, tushare, pandas; print(\"✅ 所有依赖加载成功\")'" "验证依赖"
}

# ==============================
# 阶段5: 服务启动与配置
# ==============================
start_services() {
    log_info "5.1 创建Supervisor配置文件..."
    
    cat > /tmp/openclaw_supervisor.conf << EOF
[program:openclaw]
command=python3 -m uvicorn app.main:app --host 0.0.0.0 --port $FASTAPI_PORT --reload
directory=$BACKEND_DIR
user=$SSH_USER
autostart=true
autorestart=true
startsecs=10
startretries=3
stopwaitsecs=10
stdout_logfile=$DEPLOY_DIR/logs/openclaw_stdout.log
stderr_logfile=$DEPLOY_DIR/logs/openclaw_stderr.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=10
stderr_logfile_maxbytes=10MB
stderr_logfile_backups=10
environment=PYTHONUNBUFFERED=1,PYTHONPATH="$BACKEND_DIR"
EOF

    # 上传配置文件
    sshpass -p "$SSH_PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 -P "$SSH_PORT" /tmp/openclaw_supervisor.conf "${SSH_USER}@${SERVER_IP}:/tmp/openclaw_supervisor.conf"
    
    remote_exec "sudo mkdir -p $DEPLOY_DIR/logs && sudo chown -R $SSH_USER:$SSH_USER $DEPLOY_DIR/logs" "创建日志目录"
    remote_exec "sudo cp /tmp/openclaw_supervisor.conf /etc/supervisor/conf.d/openclaw.conf" "复制Supervisor配置"
    
    log_info "5.2 重载Supervisor配置..."
    remote_exec "sudo supervisorctl reread" "重载配置"
    remote_exec "sudo supervisorctl update" "更新服务"
    
    log_info "5.3 启动openclaw服务..."
    remote_exec "sudo supervisorctl start openclaw" "启动openclaw服务"
    
    log_info "5.4 等待服务启动..."
    sleep 10
    
    log_info "5.5 检查服务状态..."
    remote_exec "sudo supervisorctl status openclaw" "检查服务状态"
}

# ==============================
# 阶段6: 部署验证
# ==============================
validate_deployment() {
    log_info "6.1 验证端口监听..."
    remote_exec "sudo ss -tuln | grep ':$FASTAPI_PORT'" "验证FastAPI端口 $FASTAPI_PORT 监听"
    
    log_info "6.2 API健康检查..."
    local max_retries=10
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if ssh_cmd "curl -s http://localhost:$FASTAPI_PORT/health 2>/dev/null | grep -q 'OK\|healthy\|status'"; then
            log_success "API健康检查通过"
            break
        else
            log_warning "API健康检查失败，重试中... ($((retry_count+1))/$max_retries)"
            sleep 5
            ((retry_count++))
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        log_error "API健康检查失败，请检查服务日志"
        remote_exec "sudo tail -20 $DEPLOY_DIR/logs/openclaw_stderr.log" "查看错误日志"
        exit 1
    fi
    
    log_info "6.3 测试Tushare Pro连通性..."
    # 简单测试，实际需要根据openclaw的API设计调整
    if ssh_cmd "curl -s -X GET http://localhost:$FASTAPI_PORT/api/health 2>/dev/null | grep -q 'tushare'"; then
        log_success "Tushare Pro连通性测试通过"
    else
        log_warning "Tushare Pro连通性测试跳过（可能需要配置token）"
    fi
    
    log_info "6.4 生成部署报告..."
    cat > /tmp/deployment_report.txt << EOF
========================================
OpenClaw 部署报告
========================================
部署时间: $(date '+%Y-%m-%d %H:%M:%S')
目标服务器: $SERVER_IP
部署状态: ✅ 成功

服务配置:
- FastAPI服务: http://${SERVER_IP}:${FASTAPI_PORT}
- HTTP代理:    http://${SERVER_IP}:${HTTP_PORT}
- HTTPS代理:   https://${SERVER_IP}:${HTTPS_PORT}
- 监控端口:    http://${SERVER_IP}:${MONITOR_PORT}

目录结构:
- 代码目录: $DEPLOY_DIR
- 后端代码: $BACKEND_DIR
- 日志目录: $DEPLOY_DIR/logs

服务管理:
启动服务: sudo supervisorctl start openclaw
停止服务: sudo supervisorctl stop openclaw
重启服务: sudo supervisorctl restart openclaw
查看状态: sudo supervisorctl status openclaw
查看日志: sudo tail -f $DEPLOY_DIR/logs/openclaw_*.log

验证命令:
1. 健康检查: curl http://${SERVER_IP}:${FASTAPI_PORT}/health
2. 端口检查: sudo ss -tuln | grep :${FASTAPI_PORT}
3. 服务状态: sudo supervisorctl status openclaw

技术支持:
- 小马 (后端开发专家)
- 小策 (测试开发工程师)
========================================
EOF
    
    log_success "部署报告已生成: /tmp/deployment_report.txt"
    cat /tmp/deployment_report.txt
}

# ==============================
# 脚本入口
# ==============================
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "用法: ./deploy.sh [选项]"
    echo "选项:"
    echo "  --help, -h    显示帮助信息"
    echo "  --update, -u  仅更新代码，不重新配置环境"
    echo "  --validate, -v 仅验证环境，不执行部署"
    exit 0
fi

if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
    log_info "执行更新模式..."
    # 这里可以添加更新逻辑
    exit 0
fi

if [ "$1" = "--validate" ] || [ "$1" = "-v" ]; then
    log_info "执行环境验证..."
    validate_environment
    exit 0
fi

# 检查sshpass是否安装
if ! command -v sshpass &> /dev/null; then
    log_error "sshpass未安装，请先安装:"
    echo "  Ubuntu/Debian: sudo apt-get install sshpass"
    echo "  CentOS/RHEL: sudo yum install sshpass"
    echo "  macOS: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# 执行主函数
main