# Sing-Box Node Management Script

一个模块化、安全、易用的 Sing-Box 节点管理脚本，支持 Reality 和 Hysteria2 协议。

## 特性

- ✅ **模块化设计** - 每个协议独立脚本，便于扩展
- ✅ **交互式配置** - 安装时可自定义端口和伪装域名
- ✅ **高安全性** - 使用最高安全等级的密码生成
- ✅ **双栈支持** - 自动生成 IPv4/IPv6 双节点链接
- ✅ **资源占用小** - 支持 Debian 和 Alpine 系统
- ✅ **易于管理** - 安装、卸载、查看、日志一站式管理
- ✅ **快捷命令** - 支持 `sb` 快捷命令快速启动

## 支持的协议

| 协议 | 类型 | 特点 |
|------|------|------|
| Reality | TCP | 最高安全性，抗检测 |
| Hysteria2 | UDP | 高性能，适合流媒体 |

## 快速开始

### 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kiss8202/All/main/main.sh)
```

### 安装快捷命令 (推荐)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kiss8202/All/main/install-sb.sh)
sb  # 启动管理脚本
```

### 手动运行

```bash
git clone https://github.com/Kiss8202/All.git
cd All
chmod +x main.sh
sudo ./main.sh
```

## 使用说明

### 主菜单

```
1. 安装节点        - 进入二级菜单选择协议
2. 查看节点信息    - 查看/删除节点
3. 重启服务        - 重启 Sing-box 服务
4. 查看日志        - 实时查看日志
5. 删除日志        - 清空日志文件
6. 卸载全部        - 完全卸载 Sing-box
0. 退出
```

### 安装节点

选择要安装的协议：
- Reality 协议 (TCP，最高安全性)
- Hysteria2 协议 (UDP，高性能)

安装时可以自定义：
- 端口 (默认: Reality 443 / Hysteria2 8443)
- 伪装域名 (默认: icloud.cdn-apple.com / bing.com)
- 是否启用混淆 (Hysteria2)

### 查看节点信息

- 查看节点详情和分享链接
- 删除单个节点 (确认提示已简化为 y/n)
- 删除全部节点 (确认提示已简化为 y/n)

## 目录结构

```
All/
├── main.sh              # 主菜单入口
├── install-sb.sh        # 安装 sb 快捷命令
├── modules/
│   ├── common.sh        # 通用工具函数
│   ├── reality.sh       # Reality 协议模块
│   └── hysteria2.sh     # Hysteria2 协议模块
├── config/
│   └── certs/           # 证书目录
├── logs/                # 日志目录
└── README.md            # 说明文档
```

## 系统要求

- Linux 系统 (Debian/Ubuntu/Alpine)
- Root 权限
- 支持 systemd

## 安全特性

- 🔐 32位随机 Base64 密码
- 🔐 32位随机 Hex 混淆密码
- 🔐 自动生成 UUID 和 Reality 密钥对
- 🔐 自签证书 (10年有效期)
- 🔐 配置文件权限 600

## 扩展协议

如需添加新协议，只需在 `modules/` 目录下创建新的协议脚本，实现以下标准接口：

```bash
protocol_install()       # 安装协议
protocol_uninstall()     # 卸载协议
protocol_status()        # 查看状态
protocol_show_info()     # 显示节点信息
```

## 许可证

MIT License

## 致谢

- [sing-box](https://github.com/SagerNet/sing-box) - 核心代理引擎
- [Hysteria2](https://v2.hysteria.network/) - 高性能代理协议
