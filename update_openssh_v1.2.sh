#!/bin/bash
clear
export LANG="en_US.UTF-8"

#脚本变量
CUR_PATH=$(cd `dirname $0`;echo `pwd`)
DATE=`date "+%Y%m%d"`
PREFIX="/usr/local"
SRC_PATH=$CUR_PATH/src
BAK_PATH=$CUR_PATH/bak
BUILD_PATH=$CUR_PATH/build
LOG_PATH=$CUR_PATH/log

#定义版本
DROPBEAR_VERSION="dropbear-2019.78"
ZLIB_VERSION="zlib-1.2.11"
OPENSSL_VERSION="openssl-1.1.1d"
OPENSSH_VERSION="openssh-8.2p1"


#下载地址
DROPBEAR_DOWNLOAD="https://matt.ucc.asn.au/dropbear/releases/$DROPBEAR_VERSION.tar.bz2"
ZLIB_DOWNLOAD="http://zlib.net/$ZLIB_VERSION.tar.gz" 
OPENSSL_DOWNLOAD="https://www.openssl.org/source/$OPENSSL_VERSION.tar.gz" 
OPENSSH_DOWNLOAD="https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/$OPENSSH_VERSION.tar.gz" 


#检查用户
if [ $(id -u) != 0 ]; then
echo -e "当前登陆用户为普通用户，必须使用Root用户运行脚本，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi

#使用说明
echo -e "\033[33m软件升级\033[0m"
#echo ""
#echo "脚本仅适用于RHEL和CentOS操作系统，支持4.x-7.x版本"
#echo "必须使用Root用户运行脚本，确保本机已配置好软件仓库"
#echo "企业生产环境中建议先临时安装Dropbear，再升级OpenSSH"
#echo "旧版本OpenSSH文件备份在/tmp/backup_$DATE/openssh"
echo ""

mkdir -p $SRC_PATH &>/dev/null
mkdir -p $BUILD_PATH &>/dev/null
mkdir -p $LOG_PATH &>/dev/null
#下载源码包
function GET_SRC(){
cd $SRC_PATH
[ ! -e $SRC_PATH/$DROPBEAR_VERSION.tar.bz2 ] && wget --no-check-certificate $DROPBEAR_DOWNLOAD || echo "$DROPBEAR_VERSION.tar.bz2 已存在"
[ ! -e $SRC_PATH/$ZLIB_VERSION.tar.gz ] && wget --no-check-certificate $ZLIB_DOWNLOAD || echo "$ZLIB_VERSION.tar.gz 已存在"
[ ! -e $SRC_PATH/$OPENSSL_VERSION.tar.gz ] && wget --no-check-certificate $OPENSSL_DOWNLOAD || echo "$OPENSSL_VERSION.tar.gz 已存在"
[ ! -e $SRC_PATH/$OPENSSH_VERSION.tar.gz ] && wget --no-check-certificate $OPENSSH_DOWNLOAD || echo "$OPENSSH_VERSION.tar.gz 已存在"

}

#安装依赖包
function Yum_install(){
yum -y install gcc bzip2 wget make net-tools pam-devel perl
}
function Yum_download(){
#yum install yum-plugin-downloadonly -y
yum -y install --downloadonly --downloaddir=$SRC_PATH gcc bzip2 wget make net-tools pam-devel perl
}
function Rpm_install(){
#yum -y localinstall $SRC_PATH/*.rpm
rpm -Uvh $SRC_PATH/*.rpm
}

#安装Dropbear
function INSTALL_DROPBEAR() {

#解压源码包
echo "解压源码"
tar xjf $SRC_PATH/$DROPBEAR_VERSION.tar.bz2 -C $BUILD_PATH/
if [ -d $BUILD_PATH/$DROPBEAR_VERSION ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi
echo ""

#安装Dropbear
echo "编译安装Dropbear"
cd $BUILD_PATH/$DROPBEAR_VERSION
./configure --disable-zlib &>> $LOG_PATH/dropbear.log
if [ $? -eq 0 ];then
make &>> $LOG_PATH/dropbear.log
make install &>> $LOG_PATH/dropbear.log
else
echo -e "编译安装Dropbear失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi

#启动Dropbear
mkdir /etc/dropbear > /dev/null 2>&1
/usr/local/bin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
/usr/local/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbear -p 6666 > /dev/null 2>&1
netstat -lantp | grep -w "0.0.0.0:6666" > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "启动Dropbear服务成功" "\033[32m Success\033[0m"
echo ""
echo -e "服务监听本地端口6666" "\033[33m Warnning\033[0m"
else
echo -e "启动Dropbear服务失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 3
exit
fi
echo ""

}

#卸载dropbear
function UNINSTALL_DROPBEAR() {

ps aux | grep dropbear | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
find /usr/local/ -name dropbear* | xargs rm -rf > /dev/null 2>&1
rm -rf /etc/dropbear > /dev/null 2>&1
rm -rf /var/run/dropbear.pid > /dev/null 2>&1
ps aux | grep -w "/usr/local/sbin/dropbear" | grep -v grep > /dev/null 2>&1
if [ $? -ne 0 ];then
echo -e "卸载DropBear成功" "\033[32m Success\033[0m"
else
echo -e "卸载DropBear失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 3
exit
fi
echo ""
}

#升级OpenSSH
function OPENSSH() {

#创建备份目录
echo "创建备份目录 $BAK_PATH/backup_$DATE"
mkdir -p $BAK_PATH/backup_$DATE/openssh/usr/{bin,sbin} > /dev/null 2>&1
mkdir -p $BAK_PATH/backup_$DATE/openssh/etc/{init.d,pam.d,ssh} > /dev/null 2>&1
mkdir -p $BAK_PATH/backup_$DATE/openssh/usr/libexec/openssh > /dev/null 2>&1
mkdir -p $BAK_PATH/backup_$DATE/openssh/usr/share/man/{man1,man8} > /dev/null 2>&1


#解压源码包
echo "解压源码"
tar xzf $SRC_PATH/$ZLIB_VERSION.tar.gz  -C $BUILD_PATH/
tar xzf $SRC_PATH/$OPENSSL_VERSION.tar.gz  -C $BUILD_PATH/
tar xzf $SRC_PATH/$OPENSSH_VERSION.tar.gz  -C $BUILD_PATH/
if [ -d $BUILD_PATH/$ZLIB_VERSION ] && [ -d $BUILD_PATH/$OPENSSL_VERSION ] && [ -d $BUILD_PATH/$OPENSSH_VERSION ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi
echo ""

#安装Zlib
echo "编译安装Zlib"
cd $BUILD_PATH/$ZLIB_VERSION
./configure --prefix=$PREFIX/$ZLIB_VERSION &>> $LOG_PATH/zlib.log
if [ $? -eq 0 ];then
make &>> $LOG_PATH/zlib.log
make install &>> $LOG_PATH/zlib.log
else
echo -e "编译安装压缩库失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi

if [ -e $PREFIX/$ZLIB_VERSION/lib/libz.so ];then
echo "$PREFIX/$ZLIB_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
echo -e "编译安装压缩库成功" "\033[32m Success\033[0m"
else
echo -e "编译安装压缩库失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi
echo ""

#备份旧版OpenSSH
echo "备份OpenSSH..."
rpm -qa | grep -w "openssh-server" > /dev/null 2>&1
if [ $? -eq 0 ];then
cp /usr/bin/openssl $BAK_PATH/backup_$DATE/openssh/usr/bin > /dev/null 2>&1
cp /usr/bin/ssh* $BAK_PATH/backup_$DATE/openssh/usr/bin > /dev/null 2>&1
cp /usr/sbin/sshd $BAK_PATH/backup_$DATE/openssh/usr/sbin > /dev/null 2>&1
cp /etc/init.d/sshd $BAK_PATH/backup_$DATE/openssh/etc/init.d > /dev/null 2>&1
cp /etc/pam.d/sshd $BAK_PATH/backup_$DATE/openssh/etc/pam.d > /dev/null 2>&1
cp /etc/ssh/ssh* $BAK_PATH/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
cp /etc/ssh/sshd_config $BAK_PATH/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
cp /usr/share/man/man1/ssh* $BAK_PATH/backup_$DATE/openssh/usr/share/man/man1 > /dev/null 2>&1
cp /usr/share/man/man8/ssh* $BAK_PATH/backup_$DATE/openssh/usr/share/man/man8 > /dev/null 2>&1
cp /usr/libexec/openssh/ssh* $BAK_PATH/backup_$DATE/openssh/usr/libexec/openssh > /dev/null 2>&1
rpm -e --nodeps openssh-clients openssh-server openssh > /dev/null 2>&1
else
mv /usr/bin/ssh* $BAK_PATH/backup_$DATE/openssh/usr/bin > /dev/null 2>&1
mv /usr/sbin/sshd $BAK_PATH/backup_$DATE/openssh/usr/sbin > /dev/null 2>&1
mv /etc/init.d/sshd $BAK_PATH/backup_$DATE/openssh/etc/init.d > /dev/null 2>&1
mv /etc/pam.d/sshd $BAK_PATH/backup_$DATE/openssh/etc/pam.d > /dev/null 2>&1
mv /etc/ssh/ssh* $BAK_PATH/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
mv /etc/ssh/sshd_config $BAK_PATH/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
mv /usr/share/man/man1/ssh* $BAK_PATH/backup_$DATE/openssh/usr/share/man/man1 > /dev/null 2>&1
mv /usr/share/man/man8/ssh* $BAK_PATH/backup_$DATE/openssh/usr/share/man/man8 > /dev/null 2>&1
mv /usr/libexec/ssh* $BAK_PATH/backup_$DATE/openssh/usr/libexec > /dev/null 2>&1
fi

#安装OpenSSL
echo "编译安装OpenSSL"
cd $BUILD_PATH/$OPENSSL_VERSION
./config --prefix=$PREFIX/$OPENSSL_VERSION --openssldir=$PREFIX/$OPENSSL_VERSION/ssl -fPIC &>> $LOG_PATH/openssl.log
if [ $? -eq 0 ];then
make &>> $LOG_PATH/openssl.log
make install &>> $LOG_PATH/openssl.log
else
echo -e "编译安装OpenSSL失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi

if [ -e $PREFIX/$OPENSSL_VERSION/bin/openssl ];then
echo "$PREFIX/$OPENSSL_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
mv /usr/bin/openssl{,.bak}
ln -sfv $PREFIX/$OPENSSL_VERSION/bin/openssl /usr/bin/openssl
echo -e "编译安装OpenSSL成功" "\033[32m Success\033[0m"
fi
echo ""

#安装OpenSSH
echo "编译装OpenSSH"
cd $BUILD_PATH/$OPENSSH_VERSION
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-ssl-dir=$PREFIX/$OPENSSL_VERSION --with-zlib=$PREFIX/$ZLIB_VERSION --with-pam --with-md5-passwords &>> $LOG_PATH/openssh.log
if [ $? -eq 0 ];then
make &>> $LOG_PATH/openssh.log
make install &>> $LOG_PATH/openssh.log
else
echo -e "编译安装OpenSSH失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 3
exit
fi

if [ -e /usr/sbin/sshd ];then
echo -e "编译安装OpenSSH成功" "\033[32m Success\033[0m"
fi
echo ""

echo "配置并重启sshd"
#配置OpenSSH服务端（允许root登陆）
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sed -i 's/^GSSAPI/#GSSAPI/g' /etc/ssh/sshd_config
sed -i 's/^UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config

#启动OpenSSH
cp -rf $BUILD_PATH/$OPENSSH_VERSION/contrib/redhat/sshd.init /etc/init.d/sshd
cp -rf $BUILD_PATH/$OPENSSH_VERSION/contrib/redhat/sshd.pam /etc/pam.d/sshd
chmod +x /etc/init.d/sshd
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_dsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key
chkconfig --add sshd
chkconfig sshd on

service sshd restart > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "启动OpenSSH服务成功" "\033[32m Success\033[0m"
echo ""
ssh -V
else
echo -e "启动OpenSSH服务失败，三秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 3
exit
fi
echo ""

}


#脚本菜单
echo -e "=======依赖包相关============="
echo -e "\033[36m1: Yum安装依赖包\033[0m"
echo ""
echo -e "\033[36m2: Yum下载依赖包\033[0m"
echo ""
echo -e "\033[36m3: Rpm安装依赖包\033[0m"
echo ""
echo -e "=======OpenSSH源码下载========"
echo -e "\033[36m4: 下载源码\033[0m"
echo ""
echo -e "=======DropBear相关==========="
echo -e "\033[36m5: 安装DropBear\033[0m"
echo ""
echo -e "\033[36m6: 卸载DropBear\033[0m"
echo ""
echo -e "=======OpenSSH升级相关========"
echo -e "\033[36m7: 升级OpenSSH\033[0m"
echo ""
echo -e "\033[36m8: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车开始执行脚本: " SELECT
if [ "$SELECT" == "1" ];then
clear
Yum_install
fi
if [ "$SELECT" == "2" ];then
clear
Yum_download
fi
if [ "$SELECT" == "3" ];then
clear
Rpm_install
fi
if [ "$SELECT" == "4" ];then
clear
GET_SRC
fi
if [ "$SELECT" == "5" ];then
clear
INSTALL_DROPBEAR
fi
if [ "$SELECT" == "6" ];then
clear
UNINSTALL_DROPBEAR
fi
if [ "$SELECT" == "7" ];then
clear
OPENSSH
fi
if [ "$SELECT" == "8" ];then
echo ""
exit
fi
