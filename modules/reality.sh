#!/bin/bash
#
# Sing-Box Node Management Script - Reality Protocol Module
# Reality 协议模块
#

# 协议配置
readonly REALITY_TAG="vless-reality-in"

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
    
    # 询问端口配置
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}端口配置${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  默认端口: ${COLOR_YELLOW}443${COLOR_RESET}"
    read -rp "  请输入端口 (直接回车使用默认 443): " REALITY_PORT_INPUT
    
    # 如果用户输入了端口，使用用户输入的，否则使用默认值
    local final_port="${REALITY_PORT_INPUT:-443}"
    
    # 验证端口
    if ! [[ "$final_port" =~ ^[0-9]+$ ]] || [ "$final_port" -lt 1 ] || [ "$final_port" -gt 65535 ]; then
        log_error "端口无效，使用默认端口 443"
        final_port=443
    fi
    
    # 检查端口是否可用
    if ! check_port_available "$final_port"; then
        log_warn "端口 $final_port 已被占用，尝试查找可用端口..."
        local new_port=$(get_available_port $((final_port + 1)) 65535)
        if [[ -z "$new_port" ]]; then
            log_error "未找到可用端口"
            return 1
        fi
        final_port=$new_port
        log_info "使用端口: $final_port"
    fi
    
    # 询问伪装域名配置
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}伪装域名配置${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  默认伪装域名: ${COLOR_YELLOW}icloud.cdn-apple.com${COLOR_RESET}"
    echo -e "  ${COLOR_BLUE}推荐使用支持 TLS 1.3 的域名${COLOR_RESET}"
    read -rp "  请输入伪装域名 (直接回车使用默认): " REALITY_SNI_INPUT
    
    # 如果用户输入了伪装域名，使用用户输入的，否则使用默认值
    local final_sni="${REALITY_SNI_INPUT:-icloud.cdn-apple.com}"
    
    if [[ -z "$final_sni" ]]; then
        log_error "伪装域名不能为空，使用默认值 icloud.cdn-apple.com"
        final_sni="icloud.cdn-apple.com"
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}配置确认${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  端口: ${COLOR_YELLOW}$final_port${COLOR_RESET}"
    echo -e "  伪装域名: ${COLOR_YELLOW}$final_sni${COLOR_RESET}"
    echo ""
    read -rp "  确认安装? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消安装"
        return 0
    fi
    
    # 创建 inbound 配置
    local inbound_config=$(cat << EOF
{
    "type": "vless",
    "tag": "${REALITY_TAG}",
    "listen": "::",
    "listen_port": ${final_port},
    "users": [
        {
            "uuid": "${uuid}",
            "flow": "xtls-rprx-vision"
        }
    ],
    "tls": {
        "enabled": true,
        "server_name": "${final_sni}",
        "reality": {
            "enabled": true,
            "handshake": {
                "server": "${final_sni}",
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
    open_port "$final_port" "tcp"
    
    # 保存节点信息
    save_reality_info "$uuid" "$public_key" "$short_id" "$final_port" "$final_sni"
    
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
    
    # 检查是否安装
    if ! is_protocol_installed "reality"; then
        log_warn "Reality 协议未安装"
        return 1
    fi
    
    # 获取端口信息
    local port=$(jq -r '.inbounds[] | select(.tag=="vless-reality-in") | .listen_port' "$PATH_CONFIG_FILE" 2>/dev/null || echo "443")
    
    # 移除 inbound 配置 - 传协议名而不是tag
    remove_inbound_from_config "reality"
    
    # 关闭防火墙端口
    close_port "$port" "tcp"
    
    # 删除节点信息
    delete_protocol_info "reality"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Reality 协议已卸载"
}

# ============================================
# 保存 Reality 节点信息
# ============================================
save_reality_info() {
    local uuid=$1
    local public_key=$2
    local short_id=$3
    local port=$4
    local sni=$5
    
    mkdir -p "$PATH_CONFIG"
    
    cat > "$PATH_CONFIG/reality_info.json" << EOF
{
    "uuid": "$uuid",
    "public_key": "$public_key",
    "short_id": "$short_id",
    "port": $port,
    "sni": "$sni"
}
EOF
    
    log_info "节点信息已保存"
}

# ============================================
# Reality 节点信息显示
# ============================================
reality_show_info() {
    local ipv4=$1
    local ipv6=$2
    
    if [[ ! -f "$PATH_CONFIG/reality_info.json" ]]; then
        log_warn "未找到 Reality 节点信息"
        return 1
    fi
    
    local uuid=$(jq -r '.uuid' "$PATH_CONFIG/reality_info.json")
    local public_key=$(jq -r '.public_key' "$PATH_CONFIG/reality_info.json")
    local short_id=$(jq -r '.short_id' "$PATH_CONFIG/reality_info.json")
    local port=$(jq -r '.port' "$PATH_CONFIG/reality_info.json")
    local sni=$(jq -r '.sni' "$PATH_CONFIG/reality_info.json")
    
    echo -e "  ${COLOR_GREEN}端口:${COLOR_RESET} $port"
    echo -e "  ${COLOR_GREEN}UUID:${COLOR_RESET} $uuid"
    echo -e "  ${COLOR_GREEN}Public Key:${COLOR_RESET} $public_key"
    echo -e "  ${COLOR_GREEN}Short ID:${COLOR_RESET} $short_id"
    echo -e "  ${COLOR_GREEN}伪装域名:${COLOR_RESET} $sni"
    echo ""
    
    # 生成节点链接
    echo -e "  ${COLOR_CYAN}节点链接:${COLOR_RESET}"
    echo ""
    
    # IPv4 链接
    if [[ -n "$ipv4" && "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local ipv4_link="vless://${uuid}@${ipv4}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pb=${public_key}&sid=${short_id}&type=tcp&headless=tcp#Reality-${ipv4}"
        echo -e "  ${COLOR_YELLOW}IPv4:${COLOR_RESET}"
        echo -e "  $ipv4_link"
        echo ""
    fi
    
    # IPv6 链接
    if [[ -n "$ipv6" ]]; then
        local ipv6_link="vless://${uuid}@${ipv6}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pb=${public_key}&sid=${short_id}&type=tcp&headless=tcp#Reality-${ipv6}"
        echo -e "  ${COLOR_YELLOW}IPv6:${COLOR_RESET}"
        echo -e "  $ipv6_link"
        echo ""
    fi
    
    echo -e "  ${COLOR_BLUE}提示: 复制上方链接到客户端导入使用${COLOR_RESET}"
}
