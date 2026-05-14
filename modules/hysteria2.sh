#!/bin/bash
#
# Sing-Box Node Management Script - Hysteria2 Protocol Module
# Hysteria2 协议模块
#

# 协议配置
readonly HYSTERIA2_TAG="hysteria2-in"
readonly HYSTERIA2_PORT=8443
readonly HYSTERIA2_MASQUERADE="https://bing.com"

# ============================================
# Hysteria2 协议安装
# ============================================
hysteria2_install() {
    log_info "开始安装 Hysteria2 协议..."
    
    # 检查是否已安装
    if is_protocol_installed "hysteria2"; then
        log_warn "Hysteria2 协议已安装，如需重新安装请先卸载"
        return 1
    fi
    
    # 初始化配置
    init_main_config
    
    # 生成配置参数
    local password=$(generate_secure_password)
    local obfs_password=$(generate_obfs_password)
    
    # 检查端口
    local port=$HYSTERIA2_PORT
    if ! check_port_available "$port"; then
        log_warn "端口 $port 已被占用，尝试查找可用端口..."
        port=$(get_available_port 8443 100)
        if [[ -z "$port" ]]; then
            log_error "未找到可用端口"
            return 1
        fi
        log_info "使用端口: $port"
    fi
    
    # 创建自签证书
    local cert_info=$(create_self_signed_cert "/usr/local/etc/sing-box/certs" "bing.com" 3650)
    local cert_file=$(echo "$cert_info" | cut -d':' -f1)
    local key_file=$(echo "$cert_info" | cut -d':' -f2)
    
    # 创建 inbound 配置
    local inbound_config=$(cat << EOF
{
    "type": "hysteria2",
    "tag": "${HYSTERIA2_TAG}",
    "listen": "::",
    "listen_port": ${port},
    "users": [
        {
            "password": "${password}"
        }
    ],
    "masquerade": "${HYSTERIA2_MASQUERADE}",
    "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "${cert_file}",
        "key_path": "${key_file}"
    },
    "obfs": {
        "type": "salamander",
        "salamander": {
            "password": "${obfs_password}"
        }
    }
}
EOF
)
    
    # 添加到配置文件
    add_inbound_to_config "$inbound_config"
    
    # 开放防火墙端口
    open_port "$port" "udp"
    
    # 保存节点信息
    save_hysteria2_info "$password" "$obfs_password" "$port" "$cert_file" "$key_file"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Hysteria2 协议安装完成"
    
    # 显示连接信息
    local ipv4=$(get_ipv4)
    local ipv6=$(get_ipv6)
    hysteria2_show_info "$ipv4" "$ipv6"
}

# ============================================
# Hysteria2 协议卸载
# ============================================
hysteria2_uninstall() {
    log_info "正在卸载 Hysteria2 协议..."
    
    # 从配置文件移除
    remove_inbound_from_config "hysteria2"
    
    # 关闭防火墙端口
    local port=$(get_protocol_port "hysteria2")
    if [[ -n "$port" ]]; then
        close_port "$port" "udp"
    fi
    
    # 删除节点信息文件
    rm -f "/usr/local/etc/sing-box/hysteria2.info"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Hysteria2 协议已卸载"
}

# ============================================
# Hysteria2 状态查看
# ============================================
hysteria2_status() {
    if is_protocol_installed "hysteria2"; then
        local port=$(get_protocol_port "hysteria2")
        echo -e "${COLOR_GREEN}Hysteria2 协议已安装${COLOR_RESET} (端口: $port)"
        return 0
    else
        echo -e "${COLOR_YELLOW}Hysteria2 协议未安装${COLOR_RESET}"
        return 1
    fi
}

# ============================================
# 保存 Hysteria2 节点信息
# ============================================
save_hysteria2_info() {
    local password=$1
    local obfs_password=$2
    local port=$3
    local cert_file=$4
    local key_file=$5
    
    cat > "/usr/local/etc/sing-box/hysteria2.info" << EOF
PASSWORD=${password}
OBFS_PASSWORD=${obfs_password}
PORT=${port}
CERT_FILE=${cert_file}
KEY_FILE=${key_file}
MASQUERADE=${HYSTERIA2_MASQUERADE}
EOF
    
    chmod 600 "/usr/local/etc/sing-box/hysteria2.info"
}

# ============================================
# 读取 Hysteria2 节点信息
# ============================================
read_hysteria2_info() {
    local info_file="/usr/local/etc/sing-box/hysteria2.info"
    if [[ -f "$info_file" ]]; then
        source "$info_file"
        echo "PASSWORD=${PASSWORD}"
        echo "OBFS_PASSWORD=${OBFS_PASSWORD}"
        echo "PORT=${PORT}"
        echo "CERT_FILE=${CERT_FILE}"
        echo "KEY_FILE=${KEY_FILE}"
        echo "MASQUERADE=${MASQUERADE}"
    fi
}

# ============================================
# 显示 Hysteria2 节点信息
# ============================================
hysteria2_show_info() {
    local ipv4=$1
    local ipv6=$2
    
    # 读取节点信息
    local info=$(read_hysteria2_info)
    if [[ -z "$info" ]]; then
        log_error "无法读取 Hysteria2 节点信息"
        return 1
    fi
    
    eval "$info"
    
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_GREEN}协议类型:${COLOR_RESET} Hysteria2"
    echo -e "${COLOR_GREEN}端口:${COLOR_RESET} ${PORT}"
    echo -e "${COLOR_GREEN}密码:${COLOR_RESET} ${PASSWORD}"
    echo -e "${COLOR_GREEN}混淆密码:${COLOR_RESET} ${OBFS_PASSWORD}"
    echo -e "${COLOR_GREEN}ALPN:${COLOR_RESET} h3"
    echo -e "${COLOR_GREEN}伪装:${COLOR_RESET} ${MASQUERADE}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    
    # 生成分享链接
    echo -e "${COLOR_YELLOW}【分享链接】${COLOR_RESET}"
    
    # IPv4 链接
    if [[ -n "$ipv4" ]]; then
        local link_v4="hysteria2://${PASSWORD}@${ipv4}:${PORT}?sni=bing.com&alpn=h3&obfs=salamander&obfs-password=${OBFS_PASSWORD}#Hysteria2-IPv4"
        echo -e "${COLOR_GREEN}IPv4:${COLOR_RESET}"
        echo "$link_v4"
        echo ""
    fi
    
    # IPv6 链接
    if [[ -n "$ipv6" ]]; then
        local link_v6="hysteria2://${PASSWORD}@[${ipv6}]:${PORT}?sni=bing.com&alpn=h3&obfs=salamander&obfs-password=${OBFS_PASSWORD}#Hysteria2-IPv6"
        echo -e "${COLOR_GREEN}IPv6:${COLOR_RESET}"
        echo "$link_v6"
        echo ""
    fi
    
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

# ============================================
# 生成 Hysteria2 配置片段
# ============================================
hysteria2_generate_config() {
    local password=$(generate_secure_password)
    local obfs_password=$(generate_obfs_password)
    local port=$HYSTERIA2_PORT
    local cert_dir="/usr/local/etc/sing-box/certs"
    
    cat << EOF
{
    "type": "hysteria2",
    "tag": "${HYSTERIA2_TAG}",
    "listen": "::",
    "listen_port": ${port},
    "users": [
        {
            "password": "${password}"
        }
    ],
    "masquerade": "${HYSTERIA2_MASQUERADE}",
    "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "${cert_dir}/cert.pem",
        "key_path": "${cert_dir}/private.key"
    },
    "obfs": {
        "type": "salamander",
        "salamander": {
            "password": "${obfs_password}"
        }
    }
}
EOF
}
