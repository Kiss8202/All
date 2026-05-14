#!/bin/bash
#
# Sing-Box Node Management Script
# 主菜单入口脚本
# 支持协议: Reality, Hysteria2 (预留扩展接口)
#

set -euo pipefail

# 版本信息
readonly VERSION="1.0.0"
readonly GITHUB_RAW="https://raw.githubusercontent.com/Kiss8202/All/main"
readonly GITHUB_REPO="https://github.com/Kiss8202/All"

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# 检测脚本来源
detect_source() {
    if [[ -f "${BASH_SOURCE[0]}" ]] && [[ -d "$(dirname "${BASH_SOURCE[0]}")/modules" ]]; then
        # 本地运行
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        return 0
    else
        # 从网络运行，下载到临时目录
        return 1
    fi
}

# 安装脚本到临时目录
install_to_temp() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} 正在下载脚本..."
    
    # 下载主脚本
    curl -fsSL "${GITHUB_RAW}/main.sh" -o main.sh
    
    # 下载模块
    mkdir -p modules
    curl -fsSL "${GITHUB_RAW}/modules/common.sh" -o modules/common.sh
    curl -fsSL "${GITHUB_RAW}/modules/reality.sh" -o modules/reality.sh
    curl -fsSL "${GITHUB_RAW}/modules/hysteria2.sh" -o modules/hysteria2.sh
    
    # 创建目录
    mkdir -p config/certs logs
    
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} 脚本已准备就绪"
    
    # 运行脚本
    chmod +x main.sh
    exec ./main.sh
}

# 如果是网络运行，安装并执行
if ! detect_source; then
    install_to_temp
fi

# 路径配置
readonly PATH_MODULES="${SCRIPT_DIR}/modules"
readonly PATH_CONFIG="${SCRIPT_DIR}/config"
readonly PATH_LOGS="${SCRIPT_DIR}/logs"
readonly PATH_CONFIG_FILE="/usr/local/etc/sing-box/config.json"

# 加载通用模块
source "${PATH_MODULES}/common.sh"

# ============================================
# 主菜单显示
# ============================================
show_main_menu() {
    clear
    echo -e "${COLOR_CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           Sing-Box Node Management Script v${VERSION}           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    # 显示系统状态
    local singbox_status="未安装"
    if check_singbox_installed; then
        if systemctl is-active --quiet sing-box 2>/dev/null; then
            singbox_status="${COLOR_GREEN}运行中${COLOR_RESET}"
        else
            singbox_status="${COLOR_YELLOW}已停止${COLOR_RESET}"
        fi
    fi
    
    echo -e "  ${COLOR_BLUE}系统状态:${COLOR_RESET} Sing-box ${singbox_status}"
    echo ""
    
    echo -e "  ${COLOR_GREEN}1.${COLOR_RESET} 安装节点"
    echo -e "  ${COLOR_GREEN}2.${COLOR_RESET} 查看节点信息"
    echo -e "  ${COLOR_GREEN}3.${COLOR_RESET} 重启服务"
    echo -e "  ${COLOR_GREEN}4.${COLOR_RESET} 查看日志"
    echo -e "  ${COLOR_GREEN}5.${COLOR_RESET} 删除日志"
    echo -e "  ${COLOR_GREEN}6.${COLOR_RESET} 卸载全部"
    echo -e "  ${COLOR_GREEN}0.${COLOR_RESET} 退出"
    echo ""
    echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════════════${COLOR_RESET}"
}

# ============================================
# 安装节点二级菜单
# ============================================
show_install_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                     选择要安装的协议                         ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${COLOR_RESET}"
        
        # 检测 Sing-box 安装状态
        if ! check_singbox_installed; then
            echo -e "  ${COLOR_YELLOW}Sing-box 未安装，将自动安装${COLOR_RESET}"
        else
            echo -e "  ${COLOR_GREEN}Sing-box 已安装${COLOR_RESET}"
        fi
        echo ""
        
        # 显示可用协议（动态加载）
        local idx=1
        local protocol_list=()
        
        # Reality 协议
        if is_protocol_installed "reality"; then
            echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Reality 协议 ${COLOR_GREEN}[已安装]${COLOR_RESET}"
        else
            echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Reality 协议 (TCP协议，最高安全性)"
        fi
        protocol_list+=("reality")
        ((idx++))
        
        # Hysteria2 协议
        if is_protocol_installed "hysteria2"; then
            echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Hysteria2 协议 ${COLOR_GREEN}[已安装]${COLOR_RESET}"
        else
            echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Hysteria2 协议 (UDP协议，高性能)"
        fi
        protocol_list+=("hysteria2")
        ((idx++))
        
        echo ""
        echo -e "  ${COLOR_YELLOW}0.${COLOR_RESET} 返回主菜单"
        echo ""
        echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════════════${COLOR_RESET}"
        
        read -rp "  请选择: " choice
        
        case "$choice" in
            1)
                install_protocol "reality"
                ;;
            2)
                install_protocol "hysteria2"
                ;;
            0)
                return
                ;;
            *)
                echo -e "${COLOR_RED}  无效选择，请重试${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ============================================
# 安装指定协议
# ============================================
install_protocol() {
    local protocol=$1
    
    # 检查 root 权限
    check_root
    
    # 加载对应协议模块并安装
    case "$protocol" in
        reality)
            source "${PATH_MODULES}/reality.sh"
            reality_install
            ;;
        hysteria2)
            source "${PATH_MODULES}/hysteria2.sh"
            hysteria2_install
            ;;
        *)
            log_error "未知协议: $protocol"
            return 1
            ;;
    esac
    
    log_info "安装完成！"
    read -rp "按回车键继续..."
}

# ============================================
# 查看节点信息菜单
# ============================================
show_node_info_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                       节点信息管理                           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${COLOR_RESET}"
        
        # 显示已安装的协议
        local has_node=false
        local idx=1
        
        if is_protocol_installed "reality"; then
            echo -e "  ${COLOR_GREEN}${idx}. Reality${COLOR_RESET}    端口: $(get_protocol_port "reality")"
            has_node=true
            ((idx++))
        fi
        
        if is_protocol_installed "hysteria2"; then
            echo -e "  ${COLOR_GREEN}${idx}. Hysteria2${COLOR_RESET}  端口: $(get_protocol_port "hysteria2")"
            has_node=true
            ((idx++))
        fi
        
        if [[ "$has_node" == false ]]; then
            echo -e "  ${COLOR_YELLOW}暂无已安装的节点${COLOR_RESET}"
        fi
        
        echo ""
        echo -e "  ${COLOR_GREEN}1.${COLOR_RESET} 查看节点详情"
        echo -e "  ${COLOR_GREEN}2.${COLOR_RESET} 删除单个节点"
        echo -e "  ${COLOR_GREEN}3.${COLOR_RESET} 删除全部节点"
        echo -e "  ${COLOR_YELLOW}0.${COLOR_RESET} 返回主菜单"
        echo ""
        echo -e "${COLOR_CYAN}══════════════════════════════════════════════════════════════${COLOR_RESET}"
        
        read -rp "  请选择: " choice
        
        case "$choice" in
            1)
                show_node_details
                ;;
            2)
                show_delete_single_menu
                ;;
            3)
                delete_all_nodes
                ;;
            0)
                return
                ;;
            *)
                echo -e "${COLOR_RED}  无效选择${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ============================================
# 查看节点详情
# ============================================
show_node_details() {
    clear
    echo -e "${COLOR_CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        节点连接信息                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    # 获取 IP 信息
    local ipv4=$(get_ipv4)
    local ipv6=$(get_ipv6)
    
    # Reality 节点信息
    if is_protocol_installed "reality"; then
        source "${PATH_MODULES}/reality.sh"
        echo -e "${COLOR_GREEN}【Reality 节点】${COLOR_RESET}"
        reality_show_info "$ipv4" "$ipv6"
        echo ""
    fi
    
    # Hysteria2 节点信息
    if is_protocol_installed "hysteria2"; then
        source "${PATH_MODULES}/hysteria2.sh"
        echo -e "${COLOR_GREEN}【Hysteria2 节点】${COLOR_RESET}"
        hysteria2_show_info "$ipv4" "$ipv6"
        echo ""
    fi
    
    read -rp "按回车键继续..."
}

# ============================================
# 删除单个节点菜单
# ============================================
show_delete_single_menu() {
    clear
    echo -e "${COLOR_CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      选择要删除的节点                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    local idx=1
    local protocol_list=()
    
    if is_protocol_installed "reality"; then
        echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Reality 协议"
        protocol_list+=("reality")
        ((idx++))
    fi
    
    if is_protocol_installed "hysteria2"; then
        echo -e "  ${COLOR_GREEN}${idx}.${COLOR_RESET} Hysteria2 协议"
        protocol_list+=("hysteria2")
        ((idx++))
    fi
    
    if [[ ${#protocol_list[@]} -eq 0 ]]; then
        echo -e "  ${COLOR_YELLOW}没有可删除的节点${COLOR_RESET}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "  ${COLOR_YELLOW}0.${COLOR_RESET} 取消"
    echo ""
    
    read -rp "  请选择要删除的节点: " choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    local idx_choice=$((choice - 1))
    if [[ $idx_choice -ge 0 && $idx_choice -lt ${#protocol_list[@]} ]]; then
        local protocol="${protocol_list[$idx_choice]}"
        
        read -rp "  确认删除 ${protocol} 节点? (Y/n): " confirm
        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            case "$protocol" in
                reality)
                    source "${PATH_MODULES}/reality.sh"
                    reality_uninstall
                    ;;
                hysteria2)
                    source "${PATH_MODULES}/hysteria2.sh"
                    hysteria2_uninstall
                    ;;
            esac
            log_info "${protocol} 节点已删除"
        fi
    else
        log_error "无效选择"
    fi
    
    read -rp "按回车键继续..."
}

# ============================================
# 删除全部节点
# ============================================
delete_all_nodes() {
    clear
    echo -e "${COLOR_RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  警告：删除全部节点                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    echo -e "  ${COLOR_YELLOW}此操作将删除所有节点配置，不可恢复！${COLOR_RESET}"
    echo ""
    
    read -rp "  确认删除全部节点? (Y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        # 停止服务
        stop_service
        
        # 删除配置文件
        rm -f "$PATH_CONFIG_FILE"
        
        # 删除证书
        rm -rf "${PATH_CONFIG}/certs"
        
        # 删除协议信息
        rm -f "${PATH_CONFIG}"/*_info.json
        
        log_info "所有节点已删除"
        
        # 重启服务（如果还有其他配置）
        if [[ -f "$PATH_CONFIG_FILE" ]]; then
            systemctl restart sing-box
        fi
    else
        log_info "已取消删除操作"
    fi
    
    read -rp "按回车键继续..."
}

# ============================================
# 重启服务
# ============================================
restart_service() {
    log_info "正在重启 Sing-box 服务..."
    
    # 检测系统类型
    local os_type=$(detect_os)
    local success=false
    
    case "$os_type" in
        alpine)
            # Alpine 使用 OpenRC
            if command -v rc-service &>/dev/null; then
                rc-service sing-box restart 2>/dev/null && success=true
            fi
            # 如果 OpenRC 失败，尝试手动重启
            if [[ "$success" != true ]]; then
                pkill -9 sing-box 2>/dev/null || true
                sleep 1
                nohup /usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json > /dev/null 2>&1 &
                sleep 2
                if pgrep -x sing-box > /dev/null; then
                    success=true
                fi
            fi
            ;;
        debian|redhat)
            # Debian/Ubuntu 使用 systemd
            systemctl restart sing-box 2>/dev/null && success=true
            ;;
        *)
            # 其他系统，尝试 systemctl
            systemctl restart sing-box 2>/dev/null && success=true
            ;;
    esac
    
    if [[ "$success" == true ]]; then
        log_info "服务重启成功"
    else
        log_error "服务重启失败"
    fi
    
    read -rp "按回车键继续..."
}

# ============================================
# 查看日志
# ============================================
view_logs() {
    clear
    echo -e "${COLOR_CYAN}按 Ctrl+C 退出日志查看${COLOR_RESET}"
    echo ""
    
    if command -v journalctl &>/dev/null; then
        journalctl -u sing-box -f --no-pager
    else
        tail -f "${PATH_LOGS}/sing-box.log" 2>/dev/null || log_error "日志文件不存在"
    fi
}

# ============================================
# 删除日志
# ============================================
delete_logs() {
    log_info "正在删除日志..."
    
    # 清空 journalctl 日志
    if command -v journalctl &>/dev/null; then
        journalctl --rotate --vacuum-time=1s 2>/dev/null || true
    fi
    
    # 删除本地日志文件
    rm -f "${PATH_LOGS}"/*.log
    
    log_info "日志已删除"
    read -rp "按回车键继续..."
}

# ============================================
# 卸载全部
# ============================================
uninstall_all() {
    clear
    echo -e "${COLOR_RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  ⚠️  警告：完全卸载                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    
    echo -e "  ${COLOR_YELLOW}此操作将完全删除所有文件！${COLOR_RESET}"
    echo ""
    echo -e "  将删除："
    echo -e "    - Sing-box 程序文件"
    echo -e "    - Sing-box 配置文件"
    echo -e "    - 所有证书"
    echo -e "    - sb 快捷命令"
    echo -e "    - 脚本相关的所有文件夹"
    echo ""
    
    read -rp "  确认完全卸载? (Y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        log_info "正在完全卸载..."
        
        # 检测系统类型
        local os_type=$(detect_os)
        
        # 停止并禁用服务 - 根据系统类型选择正确的方式
        case "$os_type" in
            alpine)
                # Alpine 使用 OpenRC 或直接 kill 进程
                if command -v rc-service &>/dev/null; then
                    rc-service sing-box stop 2>/dev/null || true
                    rc-update del sing-box default 2>/dev/null || true
                fi
                # 强制 kill 任何 sing-box 进程
                pkill -9 sing-box 2>/dev/null || true
                # 删除 OpenRC init script
                rm -f /etc/init.d/sing-box
                ;;
            debian|redhat)
                # Debian/Ubuntu 使用 systemd
                systemctl stop sing-box 2>/dev/null || true
                systemctl disable sing-box 2>/dev/null || true
                # 删除 systemd 服务文件
                rm -f /etc/systemd/system/sing-box.service
                systemctl daemon-reload
                ;;
            *)
                # 其他系统，尝试通用方法
                systemctl stop sing-box 2>/dev/null || true
                pkill -9 sing-box 2>/dev/null || true
                ;;
        esac
        
        # 删除二进制文件
        rm -f /usr/local/bin/sing-box
        
        # 删除 sb 快捷命令
        rm -f /usr/local/bin/sb
        
        # 删除配置文件
        rm -rf /usr/local/etc/sing-box
        rm -rf /usr/local/sing-box-node
        
        # 删除脚本相关的临时目录和配置
        rm -rf "${PATH_CONFIG}"
        rm -rf "${PATH_LOGS}"
        
        # 删除当前脚本（如果是本地运行）
        if [[ -f "${BASH_SOURCE[0]}" ]] && [[ -d "$(dirname "${BASH_SOURCE[0]}")/modules" ]]; then
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [[ "$script_dir" != "/" && "$script_dir" != "/usr" && "$script_dir" != "/etc" ]]; then
                rm -rf "$script_dir"
            fi
        fi
        
        log_info "已完全卸载！系统恢复到安装前状态！"
    else
        log_info "已取消卸载操作"
    fi
    
    read -rp "按回车键继续..."
}

# ============================================
# 主函数
# ============================================
main() {
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_RED}请使用 root 权限运行此脚本${COLOR_RESET}"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "${PATH_CONFIG}/certs" "${PATH_LOGS}"
    
    # 安装依赖（进入菜单前）
    log_info "正在检查并安装依赖..."
    check_and_install_dependencies
    
    # 主循环
    while true; do
        show_main_menu
        read -rp "  请选择: " choice
        
        case "$choice" in
            1)
                # 菜单1 - 先检测 sing-box 是否安装
                if ! check_singbox_installed; then
                    log_warn "Sing-box 未安装，现在开始安装..."
                    install_singbox
                fi
                show_install_menu
                ;;
            2)
                show_node_info_menu
                ;;
            3)
                restart_service
                ;;
            4)
                view_logs
                ;;
            5)
                delete_logs
                ;;
            6)
                uninstall_all
                ;;
            0)
                echo -e "${COLOR_GREEN}感谢使用，再见！${COLOR_RESET}"
                exit 0
                ;;
            *)
                echo -e "${COLOR_RED}  无效选择，请重试${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# 运行主函数
main "$@"
