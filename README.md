# ansible-offline-install

**简体中文** | [English](README.en.md)

![license](https://img.shields.io/github/license/ghl1024/ansible-offline-install.svg)
![last commit](https://img.shields.io/github/last-commit/ghl1024/ansible-offline-install.svg)
![issues](https://img.shields.io/github/issues/ghl1024/ansible-offline-install.svg)
![stars](https://img.shields.io/github/stars/ghl1024/ansible-offline-install.svg)
![forks](https://img.shields.io/github/forks/ghl1024/ansible-offline-install.svg)
[![CI](https://github.com/ghl1024/ansible-offline-install/actions/workflows/ci.yml/badge.svg)](https://github.com/ghl1024/ansible-offline-install/actions/workflows/ci.yml)

**内网服务器上不了外网，也能一键装好 Ansible。**
本项目把 Ansible 打成一个离线安装包：拷到内网机器上，运行一条命令就装好，全程不需要网络。

## 📖 目录

1. [🎯 这是干什么的](#1-这是干什么的)
2. [🧭 开始之前：先确认你的服务器信息](#2-开始之前先确认你的服务器信息)
3. [🚀 三步安装（新手路线）](#3-三步安装新手路线)
4. [❓ 常见问题（先看这里）](#4-常见问题先看这里)
5. [📚 名词解释（看不懂术语时看这里）](#5-名词解释看不懂术语时看这里)
6. [🛠️ 进阶用法](#6-进阶用法)
7. [🗂️ 仓库结构](#7-仓库结构)
8. [🗺️ 路线图](#8-路线图)
9. [📄 许可证](#9-许可证)

## 🌐 开源地址

本项目同时发布在四个平台，内容一致，国内用户从镜像下载离线包通常更快：

| 平台 | 地址 | 说明 |
| --- | --- | --- |
| GitHub | https://github.com/ghl1024/ansible-offline-install | 主仓库，开发与 Release 发布地 |
| Gitee | https://gitee.com/ghl1024/ansible-offline-install | 国内镜像，Release 自动同步 |
| GitCode | https://gitcode.com/haydenguo/ansible-offline-install | 国内镜像 |
| CNB | https://cnb.cool/ghl1024/ansible-offline-install | 国内镜像 |

## 1. 这是干什么的

很多公司、机房的服务器不允许连接外网（俗称「气隙环境」），这时直接在服务器上
`pip install ansible` 一定会失败，因为它要去网上下载。

这个项目的办法很简单，分三步：

1. 先在一台**能上网**的电脑上，把安装需要的全部文件打包成一个压缩包
   （或者直接下载本项目已经打好并测试过的包，见下面「三步安装」）；
2. 把这个包拷进内网（U 盘、跳板机、内网文件服务器，都行）；
3. 在内网服务器上运行包里的安装脚本，把 Ansible 装进一个**独立文件夹**，
   不动系统原有的环境，删掉文件夹就能卸载干净。

## 2. 开始之前：先确认你的服务器信息

在你的服务器上运行下面三条命令，记下结果，选包的时候要用：

```bash
cat /etc/os-release     # 看系统：Rocky Linux 9 / Ubuntu 24.04 / Debian 12 等
uname -m                # 看 CPU 架构：显示 x86_64 或 aarch64（aarch64 就是 ARM64）
python3 --version       # 看 Python 版本：需要 3.11 或以上
```

支持的系统（要安装 Ansible 的那台机器，业内叫「控制节点」）：

| 系统 | Python |
| --- | --- |
| EL 9 系列：Rocky Linux 9 / AlmaLinux 9 / RHEL 9 / CentOS Stream 9 | 3.11（`python3.11` 包） |
| Ubuntu 24.04 | 3.12（系统自带） |
| Ubuntu 22.04 | 3.11（系统源自带） |
| Debian 12 | 3.11（系统自带） |

其他说明：

- **不需要 root**：普通用户也可以安装（装到你的家目录里）；用 root 安装则全机器可用。
- 被管理的那些机器（目标节点）不需要任何准备，它们只要有 SSH 和任意版本的 Python 就行，
  这是 Ansible 本身的规矩，和本项目无关。

## 3. 三步安装（新手路线）

### 第一步：下载适合你机器的离线包

到本项目的 [Releases 页面](https://github.com/ghl1024/ansible-offline-install/releases)
下载。Release 里的包由 GitHub Actions 在真实机器（包括 ARM64）上自动构建并完成
安装测试。文件名长这样，每一段都有含义：

```
ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz
└────────────┬───────────┘ └┬┘ └─┬───┘ └──┬──┘
          版本 2.0.0       系统   架构    Python 版本
```

对照你第一步查到的信息选包：

| 你的服务器 | 下载这个包 |
| --- | --- |
| Rocky / Alma / RHEL / CentOS Stream 9，x86_64 | `...-el9-x86_64-py311.tar.gz` |
| Rocky / Alma / RHEL / CentOS Stream 9，ARM64 | `...-el9-aarch64-py311.tar.gz` |
| Ubuntu 24.04，x86_64 | `...-ubuntu2404-x86_64-py312.tar.gz` |
| Ubuntu 24.04，ARM64 | `...-ubuntu2404-aarch64-py312.tar.gz` |
| Ubuntu 22.04，x86_64 | `...-ubuntu2204-x86_64-py311.tar.gz` |
| Ubuntu 22.04，ARM64 | `...-ubuntu2204-aarch64-py311.tar.gz` |
| Debian 12，x86_64 | `...-debian12-x86_64-py311.tar.gz` |
| Debian 12，ARM64 | `...-debian12-aarch64-py311.tar.gz` |

上面四个系统的现成包都有（x86_64 与 ARM64 各一份），直接下载即可；
只有想换 Ansible 版本、或增减随包 collections 时，才需要自己打包（见下面「自己打包」一节）。

如果 Release 里同时提供了同名的 `.sha256` 文件，可以一起下载用来校验文件
在传输中没有损坏（可选步骤）：

```bash
sha256sum -c ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz.sha256
# 显示 OK 就是文件完好
```

### 第二步：把包拷到内网服务器并解压

用 U 盘、跳板机或内网文件服务器把 `.tar.gz` 文件拷到服务器上，然后解压：

```bash
tar xf ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz
cd ansible-offline-install-2.0.0-bundle
```

### 第三步：运行安装，并确认成功

```bash
bash install.sh
```

脚本会用中文逐行打印进度，最后自动做一次验证。看到类似下面的输出，
出现 `"ping": "pong"` 就说明装好了：

```
[ansible-offline] 正在验证安装
localhost | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
[ansible-offline] 完成。Ansible 已就绪，全程离线。
```

再试一下 `ansible --version`，能打印版本号就可以开始写你的第一个 playbook 了。

## 4. 常见问题（先看这里）

**Q：运行 `ansible` 时提示 command not found？**
A：普通用户安装时命令被链接到 `~/.local/bin`，这个目录可能还没加进 PATH。
执行一次 `export PATH="$HOME/.local/bin:$PATH"` 再试，或者重新打开一个终端窗口。

**Q：脚本报错「未找到 python3」或「需要 Python >= 3.11」？**
A：按你的系统装一下 Python 即可，不影响其他东西：

- EL 9：`sudo dnf install -y python3.11 python3.11-venv`（没有 venv 子包时装 `python3.11-devel`）
- Ubuntu 22.04 / Debian 12：`sudo apt install -y python3.11 python3.11-venv`（Ubuntu 22.04 用 `python3.11-venv`）
- Ubuntu 24.04 自带 Python 3.12，一般不会报这个错。

**Q：脚本报错「未找到 wheelhouse」？**
A：几乎都是因为只拷了 `install.sh` 一个文件，或者没有在解压出来的文件夹里运行。
请把完整的 `.tar.gz` 解压后，进入 `ansible-offline-install-2.0.0-bundle` 文件夹再运行。
`wheelhouse` 就是包里存放全部安装文件的文件夹，缺了它就没法离线安装。

**Q：CentOS 7 能不能用？**
A：不能。CentOS 7 已在 2024 年停止维护，自带的 Python 版本也太老，
新版 Ansible 装不上。请把系统换成 EL 9 系列（如 Rocky Linux 9）。
本项目最早的版本就是给 CentOS 7 做的，后来整体重构，不再支持。

**Q：会不会把系统原有的 Python 搞坏？**
A：不会。Ansible 全部装进独立文件夹（root 安装在 `/opt/ansible-offline`，
普通用户在 `~/ansible-offline`），只是把 `ansible` 等命令做了链接。
系统 Python 和其他程序完全不受影响。

**Q：包里自带的 collections 我不想装？**
A：运行 `INSTALL_COLLECTIONS=0 bash install.sh` 即可跳过。
collection 是 Ansible 的插件包，默认附带了两个最常用的。

**Q：脚本能显示英文吗？**
A：可以，`bash install.sh --lang en`。两个脚本都支持（默认中文）。

**Q：怎么卸载？**
A：删掉安装目录和命令链接即可，没有残留：

```bash
# root 安装的：
rm -rf /opt/ansible-offline /usr/local/bin/ansible*
# 普通用户安装的：
rm -rf ~/ansible-offline ~/.local/bin/ansible*
```

## 5. 名词解释（看不懂术语时看这里）

- **离线包**：把安装需要的全部文件提前打包好的一个压缩文件，拿到没网的机器上也能安装。
- **wheel**：Python 的预制安装包格式，好比 Windows 里的安装程序，装的时候不用现场编译，快且稳。
- **venv（虚拟环境）**：一个独立的文件夹，专门放这一套 Ansible，和系统环境互不干扰，删除文件夹即彻底卸载。
- **collection**：Ansible 的插件包，用来扩展功能，比如管理防火墙、云厂商的模块。本项目默认附带 `ansible.posix` 和 `community.general` 两个最常用的。

## 6. 进阶用法

### 离线安装 collections（已随包自带）

从 Releases 下载的离线包里已经包含 `ansible.posix` 和 `community.general`
（含它们的依赖），运行 `install.sh` 时会自动装好，无需任何额外操作。
`collections-requirements.yml` 记录了清单细节；想增减 collection 名单，
改这个文件后按下面一节自己打包即可。

### 自己打包（想换版本或增减 collections 时）

在一台**能上网**、且系统 / CPU 架构 / Python 版本与离线机**一致**的机器上，
克隆本仓库后运行：

```bash
bash scripts/make-offline-bundle.sh
```

产物在仓库的 `dist/` 目录下：`ansible-offline-install-2.0.0-bundle.tar.gz` 和它的
`.sha256` 校验文件。拷到离线机上按「三步安装」的第二、三步操作即可。

可选项（环境变量）：

- `WITH_COLLECTIONS=0`：只打包 Ansible 本体，不带 collections，包更小。
- `PYTHON_BIN=python3.11`：指定用哪个 Python 打包（系统里有多个 Python 时）。
- 想换 Ansible 版本：改 `requirements.txt` 里 `ansible-core` 的版本号再打包。

### 固定版本

`requirements.txt` 锁定了 `ansible-core==2.18.19`（最后一个支持 Python 3.11 的
2.18 系列版本），保证每台机器装出来的环境完全一致、可复现。

## 7. 仓库结构

按「你会用到的顺序」排列：

1. 🚀 `install.sh` — 离线机上运行的安装脚本，普通用户只需要这一个（中文界面，`--lang en` 切英文）
2. 📦 `scripts/make-offline-bundle.sh` — 联网机上打包的构建脚本，自己打离线包时用
3. 📌 `requirements.txt` — ansible-core 版本锁定
4. 🧩 `collections-requirements.yml` — 随包附带的 collections 清单
5. 🤖 `.github/workflows/ci.yml` — CI：脚本检查 + 8 种系统/架构组合的安装测试
6. 🚢 `.github/workflows/release.yml` — 发版：8 个目标的离线包自动构建、实测与发布
7. 📝 `CHANGELOG.md` — 版本更新记录
8. 📄 `LICENSE` — MIT 许可证

## 8. 路线图

- [x] Galaxy collections 随包离线安装
- [x] CI：脚本检查 + EL 9、Ubuntu 24.04 / 22.04、Debian 12 容器安装测试，覆盖 x86_64 与 ARM64
- [x] Release 离线包覆盖 x86_64 与 ARM64，由 GitHub Actions 在原生 ARM64 机器上自动构建、实测并发布

遇到问题或有需求，欢迎到
[Issues](https://github.com/ghl1024/ansible-offline-install/issues) 里留言，尽量附上
你的系统版本（`cat /etc/os-release` 的输出）和报错截图或文字。

## 9. 许可证

MIT License。见 [LICENSE](LICENSE)。
