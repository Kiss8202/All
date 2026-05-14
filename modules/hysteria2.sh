#!/bin/bash
#
# Sing-Box Node Management Script - Hysteria2 Protocol Module
# Hysteria2 协议模块
#

# 协议配置
readonly HY2_TAG="hysteria2-in"

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
    local password=$(generate_password 32)
    local obfs_password=$(generate_obfs_password)
    
    # 询问端口配置
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}端口配置${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  默认端口: ${COLOR_YELLOW}8443${COLOR_RESET}"
    read -rp "  请输入端口 (直接回车使用默认 8443): " HY2_PORT_INPUT
    
    # 如果用户输入了端口，使用用户输入的，否则使用默认值
    local final_port="${HY2_PORT_INPUT:-8443}"
    
    # 验证端口
    if ! [[ "$final_port" =~ ^[0-9]+$ ]] || [ "$final_port" -lt 1 ] || [ "$final_port" -gt 65535 ]; then
        log_error "端口无效，使用默认端口 8443"
        final_port=8443
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
    echo -e "  默认伪装域名: ${COLOR_YELLOW}bing.com${COLOR_RESET}"
    echo -e "  ${COLOR_BLUE}伪装域名用于 HTTP/3 流量混淆${COLOR_RESET}"
    read -rp "  请输入伪装域名 (直接回车使用默认): " HY2_SNI_INPUT
    
    # 如果用户输入了伪装域名，使用用户输入的，否则使用默认值
    local final_sni="${HY2_SNI_INPUT:-bing.com}"
    
    if [[ -z "$final_sni" ]]; then
        log_error "伪装域名不能为空，使用默认值 bing.com"
        final_sni="bing.com"
    fi
    
    # 询问是否启用混淆
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}混淆配置${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  混淆可以进一步增强流量隐蔽性"
    read -rp "  是否启用混淆? (y/N): " enable_obfs
    
    local obfs_config=""
    if [[ "$enable_obfs" =~ ^[Yy]$ ]]; then
        obfs_config=$(cat << EOF
,
"obfs": {
    "type": "salamander",
    "salamander": {
        "password": "${obfs_password}"
    }
}
EOF
)
        log_info "混淆已启用，混淆密码: $obfs_password"
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}配置确认${COLOR_RESET}"
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  端口: ${COLOR_YELLOW}$final_port${COLOR_RESET}"
    echo -e "  伪装域名: ${COLOR_YELLOW}$final_sni${COLOR_RESET}"
    echo -e "  混淆: ${COLOR_YELLOW}$([[ "$enable_obfs" =~ ^[Yy]$ ]] && echo "启用" || echo "禁用")${COLOR_RESET}"
    echo ""
    read -rp "  确认安装? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消安装"
        return 0
    fi
    
    # 创建 inbound 配置
    local inbound_config=$(cat << EOF
{
    "type": "hysteria2",
    "tag": "${HY2_TAG}",
    "listen": "::",
    "listen_port": ${final_port},
    "users": [
        {
            "password": "${password}"
        }
    ],
    "masquerade": "https://${final_sni}",
    "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "${PATH_CONFIG}/certs/cert.pem",
        "key_path": "${PATH_CONFIG}/certs/private.key"
    }${obfs_config}
}
EOF
)
    
    # 创建证书
    create_selfsigned_cert
    
    # 添加到配置文件
    add_inbound_to_config "$inbound_config"
    
    # 开放防火墙端口
    open_port "$final_port" "udp"
    
    # 保存节点信息
    save_hysteria2_info "$password" "$obfs_password" "$final_port" "$final_sni" "$([[ "$enable_obfs" =~ ^[Yy]$ ]] && echo "yes" || echo "no")"
    
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
    
    # 检查是否安装
    if ! is_protocol_installed "hysteria2"; then
        log_warn "Hysteria2 协议未安装"
        return 1
    fi
    
    # 获取端口信息
    local port=$(jq -r '.inbounds[] | select(.tag=="hysteria2-in") | .listen_port' "$PATH_CONFIG_FILE" 2>/dev/null || echo "8443")
    
    # 移除 inbound 配置 - 传协议名而不是tag
    remove_inbound_from_config "hysteria2"
    
    # 关闭防火墙端口
    close_port "$port" "udp"
    
    # 删除节点信息
    delete_protocol_info "hysteria2"
    
    # 重启服务
    systemctl restart sing-box
    
    log_info "Hysteria2 协议已卸载"
}

# ============================================
# 保存 Hysteria2 节点信息
# ============================================
save_hysteria2_info() {
    local password=$1
    local obfs_password=$2
    local port=$3
    local sni=$4
    local obfs_enabled=$5
    
    mkdir -p "$PATH_CONFIG"
    
    cat > "$PATH_CONFIG/hysteria2_info.json" << EOF
{
    "password": "$password",
    "obfs_password": "$obfs_password",
    "port": $port,
    "sni": "$sni",
    "obfs_enabled": "$obfs_enabled"
}
EOF
    
    log_info "节点信息已保存"
}

# ============================================
# Hysteria2 节点信息显示
# ============================================
hysteria2_show_info() {
    local ipv4=$1
    local ipv6=$2
    
    if [[ ! -f "$PATH_CONFIG/hysteria2_info.json" ]]; then
        log_warn "未找到 Hysteria2 节点信息"
        return 1
    fi
    
    local password=$(jq -r '.password' "$PATH_CONFIG/hysteria2_info.json")
    local obfs_password=$(jq -r '.obfs_password' "$PATH_CONFIG/hysteria2_info.json")
    local port=$(jq -r '.port' "$PATH_CONFIG/hysteria2_info.json")
    local sni=$(jq -r '.sni' "$PATH_CONFIG/hysteria2_info.json")
    local obfs_enabled=$(jq -r '.obfs_enabled' "$PATH_CONFIG/hysteria2_info.json")
    
    echo -e "  ${COLOR_GREEN}端口:${COLOR_RESET} $port"
    echo -e "  ${COLOR_GREEN}密码:${COLOR_RESET} $password"
    echo -e "  ${COLOR_GREEN}伪装域名:${COLOR_RESET} $sni"
    if [[ "$obfs_enabled" == "yes" ]]; then
        echo -e "  ${COLOR_GREEN}混淆密码:${COLOR_RESET} $obfs_password"
    fi
    echo ""
    
    # 生成节点链接
    echo -e "  ${COLOR_CYAN}节点链接:${COLOR_RESET}"
    echo ""
    
    # 构建混淆参数
    local obfs_param=""
    if [[ "$obfs_enabled" == "yes" ]]; then
        obfs_param="&obfs=salamander&obfs-password=$obfs_password"
    fi
    
    # IPv4 链接
    if [[ -n "$ipv4" && "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local ipv4_link="hysteria2://${password}@${ipv4}:${port}?sni=${sni}&insecure=0${obfs_param}#Hysteria2-${ipv4}"
        echo -e "  ${COLOR_YELLOW}IPv4:${COLOR_RESET}"
        echo -e "  $ipv4_link"
        echo ""
    fi
    
    # IPv6 链接
    if [[ -n "$ipv6" ]]; then
        local ipv6_link="hysteria2://${password}@${ipv6}:${port}?sni=${sni}&insecure=0${obfs_param}#Hysteria2-${ipv6}"
        echo -e "  ${COLOR_YELLOW}IPv6:${COLOR_RESET}"
        echo -e "  $ipv6_link"
        echo ""
    fi
    
    echo -e "  ${COLOR_BLUE}提示: 复制上方链接到客户端导入使用${COLOR_RESET}"
}
