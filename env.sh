#!/bin/bash
# reporter 专用 R 环境激活脚本（不修改任何全局配置，仅影响当前 shell 会话）
# 用法：  source /data/InHousePackages/reporter/env.sh
# 之后在任意目录 library(reporter) 都会优先使用 reporter 私有包库。
#
# 本服务器实测通过 R_LIBS 环境变量激活不可靠（会被 R 启动流程忽略），
# 因此这里用 R_PROFILE_USER 指向项目 .Rprofile 来激活私有库（实测可靠）。
# 副作用：会覆盖用户自己的 ~/.Rprofile（本项目 .Rprofile 只做 .libPaths 前置，
# 如需个人配置，可改为在 ~/.Renviron 中另行设置）。

_RP_LIB="/data/InHousePackages/reporter/library"
_RP_PROFILE="/data/InHousePackages/reporter/.Rprofile"

# 可选：私有库路径自定义（reporter 的安装脚本也会优先读此变量）
export REPORTER_LIBRARY="${REPORTER_LIBRARY:-$_RP_LIB}"

# 激活方式：用户级 Rprofile 指向项目 .Rprofile（内含私有库前置逻辑）
export R_PROFILE_USER="${R_PROFILE_USER:-$_RP_PROFILE}"

echo "[reporter env] REPORTER_LIBRARY=$REPORTER_LIBRARY"
echo "[reporter env] R_PROFILE_USER=$R_PROFILE_USER"
