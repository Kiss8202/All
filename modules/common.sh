#!/bin/bash
#
# Sing-Box Node Management Script - Common Functions
# 通用工具模块
#

# ============================================
# 颜色定义（如果尚未定义）
# ============================================
[[ -z "${COLOR_RED:-}" ]] && readonly COLOR_RED='\033[0;31m'
[[ -z "${COLOR_GREEN:-}" ]] && readonly COLOR_GREEN='\033[0;32m'
[[ -z "${COLOR_YELLOW:-}" ]] && readonly COLOR_YELLOW='\033[1;33m'
[[ -z "${COLOR_BLUE:-}" ]] && readonly COLOR_BLUE='\033[0;34m'
[[ -z "${COLOR_CYAN:-}" ]] && readonly COLOR_CYAN='\033[0;36m'
[[ -z "${COLOR_RESET:-}" ]] && readonly COLOR_RESET='\033[0m'

# ============================================
# 日志函数
# ============================================
log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

log_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${COLOR_BLUE}[DEBUG]${COLOR_RESET} $1"
}

# ============================================
# 系统检测函数
# ============================================

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检测操作系统类型
detect_os() {
    if [[ -f /etc/alpine-release ]]; then
        echo "alpine"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# 获取系统架构
get_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# ============================================
# 依赖管理
# ============================================

# 检查并安装依赖
check_and_install_dependencies() {
    local os_type=$(detect_os)
    local deps=("curl" "openssl" "jq")
    
    log_info "检查依赖..."
    
    case "$os_type" in
        alpine)
            for dep in "${deps[@]}"; do
                if ! command -v "$dep" &>/dev/null; then
                    log_info "安装 $dep..."
                    apk update && apk add "$dep"
                fi
            done
            # Alpine 需要额外安装一些包
            if ! command -v iptables &>/dev/null; then
                apk add iptables
            fi
            ;;
        debian)
            for dep in "${deps[@]}"; do
                if ! command -v "$dep" &>/dev/null; then
                    log_info "安装 $dep..."
                    apt-get update && apt-get install -y "$dep"
                fi
            done
            if ! command -v iptables &>/dev/null; then
                apt-get install -y iptables
            fi
            ;;
        *)
            log_warn "未知操作系统，请手动安装依赖: ${deps[*]}"
            ;;
    esac
    
    log_info "依赖检查完成"
}

# ============================================
# Sing-box 管理
# ============================================

# 检查 Sing-box 是否已安装
check_singbox_installed() {
    if command -v sing-box &>/dev/null; then
        return 0
    fi
    return 1
}

# 获取 Sing-box 版本
get_singbox_version() {
    if check_singbox_installed; then
        sing-box version | head -n 1 | awk '{print $3}'
    else
        echo "未安装"
    fi
}

# 安装 Sing-box
install_singbox() {
    local arch=$(get_arch)
    local install_dir="/usr/local/bin"
    local config_dir="/usr/local/etc/sing-box"
    
    log_info "正在安装 Sing-box..."
    
    # 创建目录
    mkdir -p "$install_dir" "$config_dir"
    
    # 获取最新版本 - 使用多种方式
    local tag_name=""
    local version=""
    log_info "获取 Sing-box 最新版本..."
    
    # 方式1: GitHub API
    if [[ -z "$tag_name" ]]; then
        tag_name=$(curl -fsSL --connect-timeout 10 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" 2>/dev/null | grep -o '"tag_name": "v[^"]*"' | head -1 | awk -F'"' '{print $4}' || true)
    fi
    
    # 方式2: 使用固定版本（如果API失败）
    if [[ -z "$tag_name" ]]; then
        log_warn "无法获取最新版本，使用备用版本 v1.12.12"
        tag_name="v1.12.12"
    fi
    
    # 文件名里用不带 v 的版本号
    version=${tag_name#v}
    
    # 修复架构名称 (Sing-box 使用 amd64 而非 x86_64)
    local sb_arch="$arch"
    if [[ "$sb_arch" == "x86_64" ]]; then
        sb_arch="amd64"
    elif [[ "$sb_arch" == "aarch64" ]]; then
        sb_arch="arm64"
    fi
    
    log_info "正在下载 Sing-box $tag_name ($sb_arch)..."
    
    # 下载地址列表（多个备用）
    local download_urls=(
        "https://github.com/SagerNet/sing-box/releases/download/${tag_name}/sing-box-${version}-linux-${sb_arch}.tar.gz"
        "https://download.fastgit.org/SagerNet/sing-box/releases/download/${tag_name}/sing-box-${version}-linux-${sb_arch}.tar.gz"
        "https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/${tag_name}/sing-box-${version}-linux-${sb_arch}.tar.gz"
    )
    
    # 下载并安装
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    local downloaded=false
    for url in "${download_urls[@]}"; do
        log_info "尝试从 $url 下载..."
        if curl -fsSL --max-time 60 --connect-timeout 10 "$url" -o sing-box.tar.gz 2>/dev/null; then
            downloaded=true
            break
        fi
        log_warn "下载失败，尝试下一个源..."
    done
    
    if [[ "$downloaded" == false ]]; then
        log_error "所有下载源都失败了，请检查网络连接或手动安装"
        log_info "手动安装方式: "
        log_info "1. 访问 https://github.com/SagerNet/sing-box/releases"
        log_info "2. 下载最新版本并解压"
        log_info "3. 将 sing-box 放到 /usr/local/bin/"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # 解压和安装
    log_info "正在解压..."
    if tar -xzf sing-box.tar.gz; then
        mv sing-box-*/sing-box "$install_dir/"
        chmod +x "$install_dir/sing-box"
        
        # 验证安装
        if ! sing-box version > /dev/null 2>&1; then
            log_error "Sing-box 安装验证失败"
            rm -rf "$tmp_dir"
            exit 1
        fi
        
        # 创建服务文件
        create_systemd_service
        
        log_info "Sing-box $tag_name 安装成功"
    else
        log_error "文件解压失败"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    rm -rf "$tmp_dir"
    cd - > /dev/null
}

# 创建 systemd 服务文件
create_systemd_service() {
    local service_file="/etc/systemd/system/sing-box.service"
    
    cat > "$service_file" << 'EOF'
[Unit]
Description=Sing-Box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    
    log_info "Systemd 服务已创建"
}

# ============================================
# 网络工具
# ============================================

# 获取 IPv4 地址
get_ipv4() {
    local ipv4
    ipv4=$(curl -s4 --connect-timeout 5 https://api.ip.sb/ip 2>/dev/null || \
           curl -s4 --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null || \
           curl -s4 --connect-timeout 5 https://ip.sb 2>/dev/null)
    echo "$ipv4"
}

# 获取 IPv6 地址
get_ipv6() {
    local ipv6
    ipv6=$(curl -s6 --connect-timeout 5 https://api.ip.sb/ip 2>/dev/null || \
           curl -s6 --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null || \
           curl -s6 --connect-timeout 5 https://ip.sb 2>/dev/null)
    echo "$ipv6"
}

# 检查端口是否可用
check_port_available() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 1
    fi
    return 0
}

# 获取可用端口
get_available_port() {
    local start_port=${1:-10000}
    local end_port=${2:-65535}
    
    for port in $(seq "$start_port" "$end_port"); do
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    log_error "未找到可用端口"
    return 1
}

# ============================================
# 密码和密钥生成（最高安全等级）
# ============================================

# 生成 UUID
generate_uuid() {
    if check_singbox_installed; then
        sing-box generate uuid
    else
        # 备用方案
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        uuidgen 2>/dev/null || \
        openssl rand -hex 16 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/'
    fi
}

# 生成 Reality 密钥对
generate_reality_keypair() {
    if check_singbox_installed; then
        sing-box generate reality-keypair
    else
        log_error "Sing-box 未安装，无法生成 Reality 密钥"
        return 1
    fi
}

# 生成高强度密码（32位 Base64）
generate_secure_password() {
    if check_singbox_installed; then
        sing-box generate rand 32 --base64
    else
        # 备用方案
        openssl rand -base64 32 | tr -d '=+/' | cut -c1-32
    fi
}

# 生成混淆密码（32位 Hex）
generate_obfs_password() {
    if check_singbox_installed; then
        sing-box generate rand 32 --hex
    else
        # 备用方案
        openssl rand -hex 32
    fi
}

# 生成 Short ID（8-16位 Hex）
generate_short_id() {
    local length=${1:-8}
    if check_singbox_installed; then
        sing-box generate rand "$length" --hex
    else
        openssl rand -hex "$length"
    fi
}

# ============================================
# 证书管理
# ============================================

# 创建自签证书
create_self_signed_cert() {
    local cert_dir="${1:-/usr/local/etc/sing-box/certs}"
    local domain="${2:-bing.com}"
    local days="${3:-3650}"
    
    mkdir -p "$cert_dir"
    
    local key_file="${cert_dir}/private.key"
    local cert_file="${cert_dir}/cert.pem"
    
    # 生成 EC 密钥和证书
    openssl ecparam -genkey -name prime256v1 -out "$key_file" 2>/dev/null
    openssl req -new -x509 -days "$days" -key "$key_file" -out "$cert_file" \
        -subj "/CN=${domain}" 2>/dev/null
    
    # 设置权限
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    echo "${cert_file}:${key_file}"
}

# ============================================
# 配置文件管理
# ============================================

# 初始化主配置文件
init_main_config() {
    local config_file="${1:-/usr/local/etc/sing-box/config.json}"
    local config_dir=$(dirname "$config_file")
    
    mkdir -p "$config_dir"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "inbounds": [],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF
        chmod 600 "$config_file"
        log_info "主配置文件已创建"
    fi
}

# 读取配置文件
read_config() {
    local config_file="${1:-/usr/local/etc/sing-box/config.json}"
    if [[ -f "$config_file" ]]; then
        cat "$config_file"
    else
        echo "{}"
    fi
}

# 写入配置文件
write_config() {
    local config=$1
    local config_file="${2:-/usr/local/etc/sing-box/config.json}"
    
    echo "$config" | jq . > "$config_file"
    chmod 600 "$config_file"
}

# ============================================
# 协议管理
# ============================================

# 检查协议是否已安装
is_protocol_installed() {
    local protocol=$1
    local config_file="/usr/local/etc/sing-box/config.json"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # 检查配置文件中是否存在该协议的 inbound
    local tag=$(get_protocol_tag "$protocol")
    if jq -e ".inbounds[] | select(.tag == \"${tag}\")" "$config_file" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# 获取协议标签
get_protocol_tag() {
    local protocol=$1
    case "$protocol" in
        reality)
            echo "vless-reality-in"
            ;;
        hysteria2)
            echo "hysteria2-in"
            ;;
        *)
            echo "${protocol}-in"
            ;;
    esac
}

# 获取协议端口
get_protocol_port() {
    local protocol=$1
    local config_file="/usr/local/etc/sing-box/config.json"
    local tag=$(get_protocol_tag "$protocol")
    
    if [[ -f "$config_file" ]]; then
        jq -r ".inbounds[] | select(.tag == \"${tag}\") | .listen_port" "$config_file" 2>/dev/null
    fi
}

# 添加 inbound 到配置文件
add_inbound_to_config() {
    local inbound_config=$1
    local config_file="${2:-/usr/local/etc/sing-box/config.json}"
    
    local current_config=$(read_config "$config_file")
    local new_config=$(echo "$current_config" | jq ".inbounds += [$inbound_config]")
    
    write_config "$new_config" "$config_file"
}

# 从配置文件移除 inbound
remove_inbound_from_config() {
    local protocol=$1
    local config_file="${2:-/usr/local/etc/sing-box/config.json}"
    local tag=$(get_protocol_tag "$protocol")
    
    local current_config=$(read_config "$config_file")
    local new_config=$(echo "$current_config" | jq "del(.inbounds[] | select(.tag == \"${tag}\"))")
    
    write_config "$new_config" "$config_file"
}

# ============================================
# 订阅链接生成
# ============================================

# URL 编码
url_encode() {
    local string="$1"
    local encoded=""
    local pos c o
    
    for (( pos=0; pos<${#string}; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9])
                encoded+="$c"
                ;;
            *)
                printf -v o '%%%02x' "'$c"
                encoded+="$o"
                ;;
        esac
    done
    echo "$encoded"
}

# 生成 Base64 订阅
generate_subscription() {
    local links=($@)
    local combined=""
    
    for link in "${links[@]}"; do
        combined+="${link}\n"
    done
    
    echo -e "$combined" | base64 -w 0
}

# ============================================
# 防火墙管理
# ============================================

# 开放端口
open_port() {
    local port=$1
    local protocol=${2:-tcp}
    
    if command -v iptables &>/dev/null; then
        iptables -I INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null || true
        
        # 保存规则
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi
    
    log_info "端口 ${port}/${protocol} 已开放"
}

# 关闭端口
close_port() {
    local port=$1
    local protocol=${2:-tcp}
    
    if command -v iptables &>/dev/null; then
        iptables -D INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null || true
    fi
}

# ============================================
# BBR 优化
# ============================================

# 启用 BBR
enable_bbr() {
    local sysctl_conf="/etc/sysctl.conf"
    
    # 检查是否已启用
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        log_info "BBR 已启用"
        return 0
    fi
    
    # 添加 BBR 配置
    cat >> "$sysctl_conf" << 'EOF'

# BBR 优化
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    
    # 应用配置
    sysctl -p
    
    # 验证
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        log_info "BBR 启用成功"
    else
        log_warn "BBR 启用失败，可能需要更新内核"
    fi
}

# ============================================
# 系统优化
# ============================================

# 系统优化
system_optimize() {
    log_info "正在优化系统..."
    
    # 启用 BBR
    enable_bbr
    
    # 文件描述符限制
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
EOF
    
    log_info "系统优化完成"
}
