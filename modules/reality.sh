#!/bin/bash
#
# Sing-Box Node Management Script - Reality Protocol Module
# Reality 协议模块
#

# 协议配置
readonly REALITY_TAG="vless-reality-in"
readonly REALITY_PORT=443
readonly REALITY_SNI="icloud.cdn-apple.com"

# ============================================
# Reality 协议安装
# ============================================
reality_install() {
    log_info "开始安装 Reality 协议..."
    
    # 检查是否已安装
    if is_protocol_installed "reality"; then
        log_warn "Reality 协议已安装，如需重新安装请先卸载"
        return 1
    fi
    
    # 初始化配置
    init_main_config
    
    # 生成配置参数
    local uuid=$(generate_uuid)
    local keypair=$(generate_reality_keypair)
    local private_key=$(echo "$keypair" | grep "PrivateKey:" | awk '{print $2}')
    local public_key=$(echo "$keypair" | grep "PublicKey:" | awk '{print $2}')
    local short_id=$(generate_short_id 8)
    
    # 检查端口
    if ! check_port_available "$REALITY_PORT"; then
        log_warn "端口 $REALITY_PORT 已被占用，尝试查找可用端口..."
        local new_port=$(get_available_port 443 500)
        if [[ -z "$new_port" ]]; then
            log_error "未找到可用端口"
            return 1
        fi
        log_info "使用端口: $new_port"
    fi
    
    # 创建 inbound 配置
    local inbound_config=$(cat << EOF
{
    "type": "vless",
    "tag": "${REALITY_TAG}",
    "listen": "::",
    "listen_port": ${REALITY_PORT},
    "users": [
        {
            "uuid": "${uuid}",
            "flow": "xtls-rprx-vision"
        }
    ],
    "tls": {
        "enabled": true,
        "server_name": "${REALITY_SNI}",
        "reality": {
            "enabled": true,
            "handshake": {
                "server": "${REALITY_SNI}",
                "server_port": 443
            },
            "private_key": "${private_key}",
            "short_id": ["${short_id}"]
        }
    }
}
EOF
)
    
    # 添加到配置文件
    add_inbound_to_config "$inbound_config"
    
    # 开放防火墙端口
    open_port "$REALITY_PORT" "tcp"
    
    # 保存节点信息
    save_reality_info "$uuid" "$public_key" "$short_id" "$REALITY_PORT"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Reality 协议安装完成"
    
    # 显示连接信息
    local ipv4=$(get_ipv4)
    local ipv6=$(get_ipv6)
    reality_show_info "$ipv4" "$ipv6"
}

# ============================================
# Reality 协议卸载
# ============================================
reality_uninstall() {
    log_info "正在卸载 Reality 协议..."
    
    # 从配置文件移除
    remove_inbound_from_config "reality"
    
    # 关闭防火墙端口
    local port=$(get_protocol_port "reality")
    if [[ -n "$port" ]]; then
        close_port "$port" "tcp"
    fi
    
    # 删除节点信息文件
    rm -f "/usr/local/etc/sing-box/reality.info"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Reality 协议已卸载"
}

# ============================================
# Reality 状态查看
# ============================================
reality_status() {
    if is_protocol_installed "reality"; then
        local port=$(get_protocol_port "reality")
        echo -e "${COLOR_GREEN}Reality 协议已安装${COLOR_RESET} (端口: $port)"
        return 0
    else
        echo -e "${COLOR_YELLOW}Reality 协议未安装${COLOR_RESET}"
        return 1
    fi
}

# ============================================
# 保存 Reality 节点信息
# ============================================
save_reality_info() {
    local uuid=$1
    local public_key=$2
    local short_id=$3
    local port=$4
    
    cat > "/usr/local/etc/sing-box/reality.info" << EOF
UUID=${uuid}
PUBLIC_KEY=${public_key}
SHORT_ID=${short_id}
PORT=${port}
SNI=${REALITY_SNI}
EOF
    
    chmod 600 "/usr/local/etc/sing-box/reality.info"
}

# ============================================
# 读取 Reality 节点信息
# ============================================
read_reality_info() {
    local info_file="/usr/local/etc/sing-box/reality.info"
    if [[ -f "$info_file" ]]; then
        source "$info_file"
        echo "UUID=${UUID}"
        echo "PUBLIC_KEY=${PUBLIC_KEY}"
        echo "SHORT_ID=${SHORT_ID}"
        echo "PORT=${PORT}"
        echo "SNI=${SNI}"
    fi
}

# ============================================
# 显示 Reality 节点信息
# ============================================
reality_show_info() {
    local ipv4=$1
    local ipv6=$2
    
    # 读取节点信息
    local info=$(read_reality_info)
    if [[ -z "$info" ]]; then
        log_error "无法读取 Reality 节点信息"
        return 1
    fi
    
    eval "$info"
    
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_GREEN}协议类型:${COLOR_RESET} VLESS + Reality"
    echo -e "${COLOR_GREEN}端口:${COLOR_RESET} ${PORT}"
    echo -e "${COLOR_GREEN}UUID:${COLOR_RESET} ${UUID}"
    echo -e "${COLOR_GREEN}Public Key:${COLOR_RESET} ${PUBLIC_KEY}"
    echo -e "${COLOR_GREEN}Short ID:${COLOR_RESET} ${SHORT_ID}"
    echo -e "${COLOR_GREEN}SNI:${COLOR_RESET} ${SNI}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    
    # 生成分享链接
    echo -e "${COLOR_YELLOW}【分享链接】${COLOR_RESET}"
    
    # IPv4 链接
    if [[ -n "$ipv4" ]]; then
        local link_v4="vless://${UUID}@${ipv4}:${PORT}?security=reality&sni=${SNI}&fp=firefox&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&flow=xtls-rprx-vision#Reality-IPv4"
        echo -e "${COLOR_GREEN}IPv4:${COLOR_RESET}"
        echo "$link_v4"
        echo ""
    fi
    
    # IPv6 链接
    if [[ -n "$ipv6" ]]; then
        local link_v6="vless://${UUID}@[${ipv6}]:${PORT}?security=reality&sni=${SNI}&fp=firefox&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&flow=xtls-rprx-vision#Reality-IPv6"
        echo -e "${COLOR_GREEN}IPv6:${COLOR_RESET}"
        echo "$link_v6"
        echo ""
    fi
    
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

# ============================================
# 生成 Reality 配置片段
# ============================================
reality_generate_config() {
    local uuid=$(generate_uuid)
    local keypair=$(generate_reality_keypair)
    local private_key=$(echo "$keypair" | grep "PrivateKey:" | awk '{print $2}')
    local short_id=$(generate_short_id 8)
    
    cat << EOF
{
    "type": "vless",
    "tag": "${REALITY_TAG}",
    "listen": "::",
    "listen_port": ${REALITY_PORT},
    "users": [
        {
            "uuid": "${uuid}",
            "flow": "xtls-rprx-vision"
        }
    ],
    "tls": {
        "enabled": true,
        "server_name": "${REALITY_SNI}",
        "reality": {
            "enabled": true,
            "handshake": {
                "server": "${REALITY_SNI}",
                "server_port": 443
            },
            "private_key": "${private_key}",
            "short_id": ["${short_id}"]
        }
    }
}
EOF
}
