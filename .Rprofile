# ---- reporter 专用包库自动挂载 ----
# 在本项目目录内启动 R / RStudio(reporter.Rproj) 时自动生效：
# 私有库排在公共库之前，同名包以私有库版本为准。
# 公共库 /data/softwares/R/library 保持只读、不受影响。
#
# 注意：OXM 私有库必须排在 /data/softwares/R/library 之前——
# 软件公共库里的 OXM 是 ggplot2 4.0 适配前的旧版（加载即报
# "ggplot_add not found"），新版 ggplot2 4.0.3 在 OXM 私有库中。
local({
  rp_lib  <- "/data/InHousePackages/reporter/library"
  oxm_lib <- "/data/InHousePackages/OXM/library"
  add <- character(0)
  if (dir.exists(oxm_lib) && !oxm_lib %in% .libPaths()) {
    add <- c(add, oxm_lib)
  }
  if (dir.exists(rp_lib) && !rp_lib %in% .libPaths()) {
    add <- c(add, rp_lib)
  }
  if (length(add)) {
    .libPaths(c(add, .libPaths()))
  }
})
