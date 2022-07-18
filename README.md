![author](https://img.shields.io/badge/author-Hayden-blueviolet.svg)
![license](https://img.shields.io/github/license/ghl1024/ansible-offline-install.svg)
![last commit](https://img.shields.io/github/last-commit/ghl1024/ansible-offline-install.svg)
![issues](https://img.shields.io/github/issues/ghl1024/ansible-offline-install.svg)
![stars](https://img.shields.io/github/stars/ghl1024/ansible-offline-install.svg)
![forks](https://img.shields.io/github/forks/ghl1024/ansible-offline-install.svg)

> 两种安装方式在生产环境的CentOS7系统中已验证通过，适用于**内网离线**或者**外网在线**安装，前提是系统自带或者干净的python环境。

# :smile:安装方式一

```bash
cd /tmp
git clone https://github.com/ghl1024/ansible-offline-install.git
cd ansible-offline-install/ansible
sh install.sh
```

# :smiley:安装方式二

```bash
cd /tmp
wget -c https://github.com/ghl1024/ansible-offline-install/releases/download/V1/ansible-offline-install.tar.gz
tar xf ansible-offline-install.tar.gz
cd ansible
sh install.sh
```
