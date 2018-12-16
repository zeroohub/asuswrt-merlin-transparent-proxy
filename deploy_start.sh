#!/bin/bash

function detect_target () {
    if [[ "$target" == localhost ]]; then
        target=$target
    elif [[ "$target" =~ [-_.[:alnum:]]+@.+ ]]; then
        target=${BASH_REMATCH[0]}
    elif [[ "$target" =~ [a-zA-Z0-9_.]+ ]]; then
        # 域名
        target=${BASH_REMATCH[0]}
    else
        echo "\`\$target' variable must be provided in your's scripts before run scripts."
        echo 'e.g. target=localhost or target=root@123.123.123.123'
        echo 'or provide with arg, e.g. deploy_start root@123.123.123.123'
        exit
    fi
}

function extract_remote_script {
    awk "/^[[:space:]]*$*/,EOF" |tail -n +2
}

function deploy_start {
    detect_target

    local preinstall="$(echo "$self" |extract_remote_script "export -f $FUNCNAME")
$export_hooks
export target=$target
export targetip=$(echo $target |cut -d'@' -f2)
sudo=$sudo
_modifier=$USER
echo '***********************************************************'
echo Remote deploy scripts is started !!
echo '***********************************************************'
set -ue
"
    local deploy_script="$preinstall$(cat $0 |extract_remote_script $FUNCNAME)"

    if [ -z "$SSH_CLIENT$SSH_TTY" ]; then
        set -u
        # 检测是否存在 bash perl
        ssh $target 'bash --version' &>/dev/null

        if [ $? != 0 ]; then
            # echo "[0m[33mremote host missing bash & perl, try to install it...[0m"
            ssh $target 'opkg install bash perl'
        fi

        ssh $target bash <<< "$deploy_script"
        exit 0
    fi
}

export -f deploy_start

# if [ -z "$SSH_CLIENT$SSH_TTY" ]; then
#     sudo=sudo
# fi

if ! which perl &>/dev/null; then
    if grep -qs 'Ubuntu\|Mint\|Debian' /etc/issue; then
        apt-get install -y --no-install-recommends perl
    elif grep -qs CentOS /etc/redhat-release; then
        yum install -y perl
    fi
fi

function append () {
    sed '$a'"$*"
}

function prepend () {
    sed "1i$*"
}

function copy () {
    detect_target

    if [ "$__use_scp" ]; then
        __scp "$@"
        return $?
    fi

    # rsync only update older file.
    __rsync "$@" 2>/dev/null

    if [ $? != 0 ]; then
        # if rsync not exist, use scp
        __use_scp=true
        __scp "$@"
    fi
}

function __rsync () {
    local local_file remote_file remote_dir
    local_file=$1
    remote_file=$2
    remote_dir=$(dirname $remote_file)

    if [ ! -e "$local_file" ]; then
        echo "local file $local_file is missing ..."
        exit
    fi

    # -a 等价于: -rlptgoD, archive 模式:
    # -r --recursive,
    # -l --link, 拷贝符号链接自身, 这是没有使用 -a 的原因.
    # -p --perms 保留权限.
    # -t --times 保留修改时间.
    # -g --group 保留分组, 下面的三个选项当前 rsync 不需要.
    # -o --owner 保留 owner
    # -D 等价于: --devices --specials 保留设备文件,保留特殊文件.

    # 其他的一些选项

    # -L --copy-links
    # -P 等价于: --partial --progress
    # -v --verbose
    # -u --update, 保留比 source 新的文件, 仅仅拷贝老的文件.
    # -h --human-readable, 输出人类可读的格式信息.

    # --rsh=ssh 这是默认你省略.

    # --rsync-path 这个命令的本意是, 用来指定远程服务器的 rsync 的路径, 例如: –rsync-path=/usr/local/bin/rsync
    # 因为字符串在 shell 下被运行, 所以它可以是任何合法的命令或脚本.
    # --exclude '.*~'

    rsync -htpPvr -z -L -u --rsync-path="mkdir -p $remote_dir && rsync" "$local_file" $target:"$remote_file" "${@:3}"
}

function __scp () {
    local local_file remote_file remote_dir
    local_file=$1
    remote_file=$2
    remote_dir=$(dirname $remote_file)

    if [ ! -e "$local_file" ]; then
        echo "local file $local_file is missing ..."
        exit
    fi

    ssh $target mkdir -p $remote_dir
    scp -r "$local_file" $target:"$remote_file" "${@:3}"
}


function reboot_task () {
    local exist_crontab=$(/usr/bin/crontab -l)
    if ! echo "$exist_crontab" |fgrep -qs -e "$*"; then
        echo "$exist_crontab" |append "@reboot $*" |/usr/bin/crontab -
    fi
    $*
}

function systemd () {
    local service=$1
    cat > /etc/systemd/system/$1.service
    systemctl daemon-reload
    systemctl start $service
    systemctl enable $service
    systemctl status $service
}

function backup () {
    mv $* $*_bak-$(date '+%Y-%m-%d_%H:%M')
}

function daemon () {
    local name=$1
    local command=$2

    getent passwd $name || useradd $name -s /sbin/nologin

    cat <<HEREDOC > /etc/systemd/system/$name.service
     [Unit]
     Description=$name Service
     After=network.target

     [Service]
     Type=simple
     User=$name
     ExecStart=$command
     ExecReload=/bin/kill -USR1 \$MAINPID
     Restart=on-abort
     LimitNOFILE=51200
     LimitCORE=infinity
     LimitNPROC=51200
     Environment=LD_LIBRARY_PATH=/usr/lib64

     [Install]
     WantedBy=multi-user.target
HEREDOC
    systemctl daemon-reload
    systemctl start $name
    systemctl enable $name
    systemctl status $name

    # 停止和关闭的命令如下:
    # systemctl stop shadowsocks
    # systemctl disable shadowsocks
}

function daemon1 () {
    local package_name=$1
    local command=$2
    set +u
    local path=$3
    set -u

    if ! which killall &>/dev/null; then
        if grep -qs CentOS /etc/redhat-release; then
            # Centos 需要 psmisc 来安装 killall
            yum install -y psmisc
        fi
    fi

    [ -e /etc/rc.func ] && backup /etc/rc.func
    curl https://raw.githubusercontent.com/zw963/deployment_bash/master/rc.func -o /etc/rc.func

    cat <<HEREDOC |tee /etc/init.d/$package_name
#!/bin/sh

ENABLED=yes
PROCS=${command%% *}
ARGS="${command#* }"
PREARGS=""
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${path+:}${path}

. /etc/rc.func
HEREDOC

    $sudo chmod +x /etc/init.d/$package_name
    /etc/init.d/$package_name start
}

function rc_local () {
    local conf=/etc/rc.local

    fgrep -qs "$*" $conf || echo "$*" >> $conf
    chmod +x $conf && $*
}

function clone () {
    git clone --depth=5 "$@"
}

function wait () {
    echo "Waiting $* to exit ..."
    while pgrep "^$*\$" &>/dev/null; do
        echo -n '.'
        sleep 0.3
    done
    echo "$* is terminated."
}

function append_file () {
    local content regexp file
    file=$1

    if [ "$#" == 2 ]; then
        content=$2
    elif [ "$#" == 1 ]; then
        content=$(cat /dev/stdin) # 从管道内读取所有内容.
    fi
    local line_number=$(echo "$content" |wc -l)

    if [ "$line_number" == "1" ]; then
        regexp=$(echo "$content" |regexp_escape)
        set +e
        grep -s -e "^\\s*${regexp}\\s*" "$file"
    else
        set +e
        match_multiline "$content" "$(cat $file)"
    fi

    if ! [ $? == 0 ]; then
        # echo -e "\n#= Add by ${_modifier-$USER} =#" >> "$file"
        if [ -e "$file" ] && [ "$(tail -c 1 $file)" == "" ]; then
            echo -e "$content" >> "$file"
        else
            echo -e "\n$content" >> "$file"
        fi
        echo "[0m[33mAppend \`$content' into $file[0m"
    fi
}

function prepend_file () {
    local content regexp file
    file=$1

    if [ "$#" == 2 ]; then
        content=$2
    elif [ "$#" == 1 ]; then
        content=$(cat /dev/stdin) # 从管道内读取所有内容.
    fi
    local line_number=$(echo "$content" |wc -l)

    if [ "$line_number" == "1" ]; then
        regexp=$(echo "$content" |regexp_escape)
        set +e
        grep "^\\s*${regexp}\\s*" "$file"
    else
        set +e
        match_multiline "$content" "$(cat $file)"
    fi

    if ! [ $? == 0 ]; then
        content_escaped=$(echo "$content" |replace_escape)
        sed -i 1i"$content_escaped" "$file"
        echo "[0m[33mPrepend \`$content' into $file[0m"
    fi
}

# 转义一个字符串中的所有 grep 元字符.
function regexp_escape () {
    sed -e 's/[]\/$*.^|[]/\\&/g'
}

# 这是支持 replace string 存在换行, 以及各种元字符的版本.
# 详细信息,  读这个答案: https://stackoverflow.com/a/29613573/749774
function replace_escape() {
    IFS= read -d '' -r <<< "$(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g')"
    printf %s "${REPLY%$'\n'}"
}

# 这个是保留 & 作为之前的匹配内容的版本.
function replace_escape1() {
    IFS= read -d '' -r <<< "$(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[/\]/\\&/g; s/\n/\\&/g')"
    printf %s "${REPLY%$'\n'}"
}


function match_multiline() {
    local regex content
    # 将 regexp 的换行符 换为一个不可见字符.
    # 注意: 这里 $1 已经是一个 regex
    regex=$(echo "$1" |tr '\n' '\a')

    # 文本内容也将 换行符 换为一个不可见字符.
    content=$(echo "$2"|tr '\n' '\a')

    # 多行匹配, 选择文本匹配, 而不是正则.
    echo "$content" |fgrep -qs -e "$regex"
}

function perl_replace() {
    local regexp replace file content
    regexp=$1
    # 注意 replace 当中的特殊变量, 例如, $& $1 $2 的手动转义.
    # 写完一定测试一下，perl 变量引用: http://www.perlmonks.org/?node_id=353259
    replace=$2
    escaped_replace=$(echo "$replace" |sed 's#"#\\"#g')

    perl -i -ne "s$regexp$replaceg; print \$_; unless ($& eq \"\") {print STDERR \"\`\033[0;33m$&\033[0m' is replace with \`\033[0;33m${escaped_replace}\033[0m'\n\"};" "${@:3}"
}

# 为了支持多行匹配，使用 perl 正则, 比 sed 好用一百倍！
function replace_multiline () {
    local regexp replace file content
    regexp=$1
    replace=$2
    file=$3

    perl_replace "$regexp" "$replace" -0 "$file"
}

function replace () {
    local regexp replace file content
    regexp=$1
    replace=$2
    file=$3

    perl_replace "$regexp" "$replace" "$file"
}

function replace_regex () {
    local regexp="$1"
    local replace="$2"
    local file=$3

    replace_multiline "$regexp" "$replace" "$file"
}

function replace_string () {
    # 转化输入的字符串为 literal 形式
    local regexp="\\Q$1\\E"
    local replace="$2"
    local file=$3

    replace_multiline "$regexp" "$replace" "$file"
}

function update_config () {
    local config_key=$1
    local config_value=$2
    local config_file=$3
    local delimiter=${4-=}
    local regexp="^\\s*$(echo "$config_key" |regexp_escape)\b"
    local matched_line matched_line_regexp old_value old_value_regexp replaced_line group

    # only if config key exist, update it.
    if matched_line=$(grep -s "$regexp" $config_file|tail -n1) && test -n "$matched_line"; then
        matched_line_regexp=$(echo "$matched_line" |regexp_escape)
        old_value=$(echo  "$matched_line" |tail -n1|cut -d"$delimiter" -f2)

        if [[ "$old_value" =~ \"(.*)\" ]]; then
            [ "${BASH_REMATCH[1]}" ] && group="${BASH_REMATCH[1]}"
            set +ue
            replaced_line=$(echo $matched_line |sed -e "s/${old_value}/\"${group}${group+ }$config_value\"/")
            set -ue
        else
            replaced_line=$(echo $matched_line |sed -e "s/${old_value}/& $config_value/")
        fi

        regexp="^${matched_line_regexp}$"
        replace="\n#= &\n#= Above config-default value is replaced by following config value. $(date '+%Y-%m-%d %H:%M:%S') by ${_modifier-$USER}\n$replaced_line"
        replace "$regexp" "$replace" "$config_file"
        # echo "Append \`$config_value' to \`$old_value' for $config_file $matched_line"
    fi
}

function configure () {
    set +u
    if [ ! "$1" ]; then
        echo 'Need one argument to sign this package. e.g. package name.'
        exit
    fi

    ./configure --build=x86_64-linux-gnu \
                --prefix=/usr \
                --exec-prefix=/usr \
                '--bindir=$(prefix)/bin' \
                '--sbindir=$(prefix)/sbin' \
                '--libdir=$(prefix)/lib64' \
                '--libexecdir=$(prefix)/lib64/$1' \
                '--includedir=$(prefix)/include' \
                '--datadir=$(prefix)/share/$1' \
                '--mandir=$(prefix)/share/man' \
                '--infodir=$(prefix)/share/info' \
                --localstatedir=/var \
                '--sysconfdir=/etc/$1' \
                ${@:2}
}

function wget () {
    local url=$1
    local file=$(basename $url)
    command wget --no-check-certificate -c $url -O $file
}

function curl () {
    command curl -sS -L "$@"
}

function download_and_extract () {
    local ext=$( basename "$1" |rev|cut -d'.' -f1|rev)
    local name=$(basename "$1" |rev|cut -d'.' -f2-|rev |sed 's#.tar$##')
    local dest="${2-$name}"
    mkdir -p $dest
    case $ext in
        gz|tgz)
            curl "$1" |tar -zxvf - -C "$dest" --strip-components=1
            ;;
        bz2)
            curl "$1" |tar -jxvf - -C "$dest" --strip-components=1
            ;;
        xz|txz)
            curl "$1" |tar -Jxvf - -C "$dest" --strip-components=1
            ;;
        lzma)
            curl "$1" |tar --lzma -xvf - -C "$dest" --strip-components=1
            ;;
        zip)
            local fullname=$(basename $1)

            temp_dir=$(mktemp -d) &&
                curl -o $temp_dir/$fullname "$1" &&
                unzip $temp_dir/"$fullname" -d "$temp_dir" &&
                rm "$temp_dir/$fullname" &&
                shopt -s dotglob &&
                local f=("$temp_dir"/*) &&
                if (( ${#f[@]} == 1 )) && [[ -d "${f[0]}" ]] ; then
                    mv "$temp_dir"/*/* "$dest"
                else
                    mv "$temp_dir"/* "$dest"
                fi && rmdir "$temp_dir"/* "$temp_dir"
    esac

}

function diff () {
    command diff -q "$@" >/dev/null
}

function sshkeygen () {
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
}

function expose_port () {
    for port in "$@"; do
        if grep -qs 'Ubuntu\|Mint\|Debian' /etc/issue; then
            # systemctl status ufw
            # ufw 中, 允许端口 1098, ufw allow 1098
            # rc.local "iptables -I INPUT -p tcp --dport $port -j ACCEPT"
            # rc.local "iptables -I INPUT -p udp --dport $port -j ACCEPT"
            echo 'no need install iptables'
        elif grep -qs CentOS /etc/redhat-release; then
            if which firewall-cmd &>/dev/null; then
                firewall-cmd --zone=public --add-port=$port/tcp --permanent
                firewall-cmd --zone=public --add-port=$port/udp --permanent
                firewall-cmd --reload   # 这个只在 --permanent 参数存在时, 才需要
                # firewall-cmd --zone=public --list-ports
            fi
        elif grep -qs openSUSE /etc/issue; then
            yast firewall services add tcpport=$port zone=EXT
        fi
    done
}

function package () {
    local install installed
    # for Ubuntu build-essential
    # for centos yum groupinstall "Development Tools"
    local compile_tools='gcc autoconf automake make libtool bzip2 unzip patch wget curl perl'
    local basic_tools='mlocate git tree'

    if grep -qs 'Ubuntu\|Mint\|Debian' /etc/issue; then
        $sudo apt-get update
        install="$sudo apt-get install -y --no-install-recommends"
    elif grep -qs CentOS /etc/redhat-release; then
        # if Want get centos version, use 'rpm -q centos-release'.
        install="$sudo yum install -y"
    elif grep -qs openSUSE /etc/issue; then
        install="$sudo zypper -n --gpg-auto-import-keys in --no-recommends"
    fi

    installed=

    centos_debian_map_list="
zlib-devel zlib1g-dev
openssl-devel libssl-dev
libffi-devel libffi-dev
readline-devel libreadline-dev
libyaml-devel libyaml-dev
ncurses-devel libncurses5-dev
gdbm-devel libgdbm-dev
sqlite-devel libsqlite3-dev
gmp-devel libgmp-dev
pcre-devel libpcre3-dev
libsodium-devel libsodium-dev
udns-devel libudns-dev
libev-devel libev-dev
libevent-devel libevent-dev
mbedtls-devel libmbedtls-dev
c-ares-devel libc-ares-dev
"
    case_statement=""


    OLDIFS="$IFS" && IFS=$'\n'
    for map in $centos_debian_map_list; do
        case_statement="${case_statement}
${map% *})
  installed=\"\$installed ${map#* }\"
  ;;"
    done
    IFS="$OLDIFS"

    if grep -qs 'Ubuntu\|Mint\|Debian' /etc/issue; then
        basic_tools="$basic_tools"
        for i in "$@"; do
            eval "
case \"$i\" in
  ${case_statement}
compile-tools)
    installed=\"\$installed $compile_tools g++ xz-utils pkg-config\"
    ;;
 *)
    installed=\"\$installed $i\"
esac
"
        done
    elif grep -qs CentOS /etc/redhat-release; then
        basic_tools="$basic_tools yum-cron yum-utils epel-release"
        for i in "$@"; do
            case "$i" in
                compile-tools)
                    installed="$installed $compile_tools gcc-c++ xz pkgconfig"
                    ;;
                apache2-utils)
                    installed="$installed httpd-tools"
                    ;;
                *)
                    installed="$installed $i"
            esac
        done
    elif grep -qs openSUSE /etc/issue; then
        basic_tools="$basic_tools"
        for i in "$@"; do
            case "$i" in
                sqlite-devel)
                    installed="$installed sqlite3-devel"
                    ;;
                openssl-devel)
                    installed="$installed libopenssl-devel"
                    ;;
                compile-tools)
                    installed="$installed $compile_tools gcc-c++ xz pkg-config"
                    ;;
                gmp-devel)
                    installed="$installed libgmp-devel"
                    ;;
                *)
                    installed="$installed $i"
            esac
        done
    fi

    for i in $basic_tools; do
        $install $i
    done

    for i in $installed; do
        $install $i
    done
}

# for use with asuswrt merlin only.
function add_service {
    [ -e /jffs/scripts/$1 ] || echo '#!/bin/sh' > /jffs/scripts/$1
    chmod +x /jffs/scripts/$1
    fgrep -qs -e "$2" /jffs/scripts/$1 || echo "$2" >> /jffs/scripts/$1
}


# only support define a bash variable, bash array variable not supported.
function __export () {
    local name=$(echo "$*" |cut -d'=' -f1)
    local value=$(echo "$*" |cut -d'=' -f2-)
    local escaped_value=$(echo "$value" |sed 's#\([\$"\`]\)#\\\1#g')

    eval 'builtin export $name="$value"'
    export_hooks="$export_hooks builtin export $name=\"$escaped_value\""
}

alias export=__export

function export_variable () {
    eval 'builtin export $*'
    export_hooks="$export_hooks
 builtin export $*"
}

function export_function () {
    eval 'builtin export -f $*'
    new_function=$(type dockerinit |tail -n +2)
    export_hooks="$export_hooks
$new_function
builtin export -f $*"
}
