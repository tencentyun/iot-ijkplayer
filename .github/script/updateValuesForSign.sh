#!/bin/sh

# 检测操作系统类型
if [ "$(uname)" = "Darwin" ]; then
    # macOS (BSD sed)
    SED_INPLACE="sed -i ''"
else
    # Linux (GNU sed)
    SED_INPLACE="sed -i"
fi

# 检查必需的环境变量是否设置
if [ -z "$KEY_ID_OF_SIGN" ] || [ -z "$PASSWORD_OF_SIGN" ] || [ -z "$IOT_SONATYPE_USERNAME" ] || [ -z "$IOT_SONATYPE_PASSWORD" ]; then
    echo "错误：必需的环境变量未设置"
    echo "请设置以下环境变量："
    echo "  KEY_ID_OF_SIGN"
    echo "  PASSWORD_OF_SIGN" 
    echo "  IOT_SONATYPE_USERNAME"
    echo "  IOT_SONATYPE_PASSWORD"
    exit 1
fi

# 检查文件参数
if [ -z "$1" ]; then
    echo "错误：请指定要更新的文件路径"
    echo "用法: $0 <文件路径>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "错误：文件不存在: $1"
    exit 1
fi

# 转义特殊字符
key_id=$(printf '%s' "$KEY_ID_OF_SIGN" | sed 's/[\\&/]/\\&/g')
password=$(printf '%s' "$PASSWORD_OF_SIGN" | sed 's/[\\&/]/\\&/g')
maven_username=$(printf '%s' "$IOT_SONATYPE_USERNAME" | sed 's/[\\&/]/\\&/g')
maven_password=$(printf '%s' "$IOT_SONATYPE_PASSWORD" | sed 's/[\\&/]/\\&/g')

# 获取文件所在目录
file_dir=$(dirname "$1")
file_name=$(basename "$1")

# 切换到文件所在目录
cd "$file_dir" || exit 1
root_path=$(pwd)

# 使用平台兼容的sed命令
$SED_INPLACE "s#MY_KEY_ID#$key_id#g" "$file_name"
$SED_INPLACE "s#MY_PASSWORD#$password#g" "$file_name"
$SED_INPLACE "s#MY_KEY_RING_FILE#$root_path/secret.gpg#g" "$file_name"
$SED_INPLACE "s#MY_MAVEN_USERNAME#$maven_username#g" "$file_name"
$SED_INPLACE "s#MY_MAVEN_PASSWORD#$maven_password#g" "$file_name"

echo "文件更新完成: $1"
echo "替换内容："
echo "  MY_KEY_ID -> $KEY_ID_OF_SIGN"
echo "  MY_PASSWORD -> [已替换]"
echo "  MY_KEY_RING_FILE -> $root_path/secret.gpg"
echo "  MY_MAVEN_USERNAME -> $IOT_SONATYPE_USERNAME"
echo "  MY_KEY_RING_FILE -> $root_path/secret.gpg"
echo "  MY_MAVEN_PASSWORD -> [已替换]"