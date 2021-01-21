> 两种安装方式都在生产环境中的CentOS7系统验证通过，适用于**内网离线**或者**外网在线**安装，前提是系统自带或者干净的python环境。

# :smile:安装方式一

```
cd /tmp
git clone https://github.com/ghl1024/ansible-offline-install.git
cd ansible-offline-install/ansible
sh install.sh
```

# :smiley:安装方式二

```
cd /tmp
wget -c https://github.com/ghl1024/ansible-offline-install/releases/download/V1/ansible-offline-install.tar.gz
tar xf ansible-offline-install.tar.gz
cd ansible
sh install.sh
```
