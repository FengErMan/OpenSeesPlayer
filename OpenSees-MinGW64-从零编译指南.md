# OpenSees 串行版：MinGW-w64 从零编译指南

> 按本工作区实际成功构建过程编写。目标仅为 Windows Tcl 串行版 `OpenSees.exe`。本次完整构建退出码为 0，Tcl 单杆静力小算例通过。
> 实测工具链：MSYS2 MinGW-w64，GCC/G++/GFortran 15.1.0，CMake 4.0.2；依赖为 Tcl 8.6、HDF5 1.14.6、Eigen3、OpenBLAS。源码 banner 显示 OpenSees 3.8.0 64-Bit。


## 快速定位：终端、目录和命令

| 阶段 | 使用终端 | 执行时所在目录 | 命令/动作 |
|---|---|---|---|
| 安装 MSYS2 包 | MSYS2 MinGW 64-bit（Bash） | 任意目录 | `pacman -Syu`，然后 `pacman -S --needed ...`（见第 2.2 节） |
| 检查头文件和库 | MSYS2 MinGW 64-bit（Bash） | 任意目录 | `ls /mingw64/include/...`、`ls /mingw64/lib/...`（见第 2.3 节） |
| 进入源码目录 | Windows PowerShell | 任意目录 | `Set-Location 'D:\feng\workspace\OpenSeesPlayer'` |
| CMake 配置 | Windows PowerShell | 源码根目录 `D:\feng\workspace\OpenSeesPlayer` | `cmake -S . -B build-mingw ...`（见第 4.3 节） |
| 编译串行程序 | Windows PowerShell | 源码根目录 `D:\feng\workspace\OpenSeesPlayer` | `cmake --build build-mingw --target OpenSees --parallel 8`（见第 4.4 节） |
| Tcl 验收 | Windows PowerShell | 源码根目录 `D:\feng\workspace\OpenSeesPlayer` | `& '.\build-mingw\OpenSees.exe' '.\build-mingw\smoke_truss.tcl'`（见第 5 节） |

**最重要的路径规则：**第 4.3、4.4、5 节的命令都从源码根目录执行。开始前在 PowerShell 运行下面两行；之后不要 `cd` 进 `build-mingw` 再照抄这些命令：

```powershell
Set-Location 'D:\feng\workspace\OpenSeesPlayer'
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
```

CMake 会自动在源码根目录下创建 `build-mingw`，不要手动进入该目录编译。
## 1. 目标与目录

- 源码：`D:\feng\workspace\OpenSeesPlayer`
- 构建目录：`D:\feng\workspace\OpenSeesPlayer\build-mingw`
- 目标：`OpenSees`，标准 Tcl 串行版
- 产物：`build-mingw\OpenSees.exe`
- 不构建：OpenSeesSP、OpenSeesMP、OpenSeesPy

串行版不需要 MPI。配置和构建时都显式选择 `OpenSees`，不要误改成其他 target。

## 2. 安装 MSYS2 与依赖

### 2.1 使用哪个终端

从开始菜单打开 **MSYS2 MinGW 64-bit**（有的版本显示为 **MSYS2 MINGW64**）。不要用 MSYS2 MSYS 终端里的 `/usr/bin` 工具链。本指南后续配置、构建和运行命令统一在 **Windows PowerShell** 执行。

### 2.2 MSYS2 MinGW 64-bit 终端（Bash）中安装

```bash
pacman -Syu
```

若更新过程要求关闭终端，关闭后重新打开 MSYS2 MinGW 64-bit，再运行：

```bash
pacman -Syu
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-make mingw-w64-x86_64-tcl mingw-w64-x86_64-hdf5 mingw-w64-x86_64-eigen3 mingw-w64-x86_64-openblas
```

`toolchain` 包提供 GCC、G++、GFortran。项目包含 Fortran 源文件，所以 `gfortran` 是必需的。

### 2.3 MSYS2 MinGW 64-bit 终端中检查文件

```bash
which gcc g++ gfortran cmake mingw32-make
ls /mingw64/include/tcl.h
ls /mingw64/include/hdf5.h
ls -d /mingw64/include/eigen3/Eigen
ls /mingw64/lib/libtcl86.dll.a
ls /mingw64/lib/libhdf5.dll.a
ls /mingw64/lib/libopenblas.dll.a
```

这些文件均应存在。MSYS2 安装根目录如果不是 `C:\msys64`，下文命令中的路径也要同步修改。

## 3. 必需的 MinGW 源码适配

本仓库 C++ 代码引用 Intel Fortran 风格的大写外部符号，如 `DGESV`、`PML_2D`、`DSAUPD`。MinGW gfortran 和 OpenBLAS/ARPACK 导出小写加下划线形式，如 `dgesv_`、`pml_2d_`、`dsaupd_`。若没有适配，前面大量 C/C++/Fortran 文件会编译成功，但最后链接会因 `undefined reference` 失败。

当前工作树中必须有以下修改：

1. `OTHER/symbol_alias.S`：为 LAPACK/BLAS、ARPACK、OpenSees Fortran 例程提供 29 个大写到小写加下划线符号的尾跳转别名。
2. 顶层 `CMakeLists.txt`：在定义 `OpenSeesLIB` 附近，当 `WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU"` 时启用 ASM 并建立静态库 `OPS_SymbolAlias`。
3. 顶层 `CMakeLists.txt`：在 `target_link_libraries(OpenSees ...)` 后，在同一条件下通过 `-Wl,--start-group OpenSeesLIB OPS_SymbolAlias -Wl,--end-group` 联接两库；它们互相引用，需让 GNU ld 循环解析。

从本工作区复制源码时这些修改已经在工作树中。若是从未修改的原始仓库单独开始，请将本次提供的 `OTHER/symbol_alias.S` 和对应 CMake 条件适配一并带过去。适配仅作用于 Windows + GNU，不要把 GNU 链接选项用于 MSVC。

另外，`OTHER/tetgen1.4.3/CMakeLists.txt` 对 GNU 编译器加入 `-fpermissive`，以兼容 GCC 13+ 对 tetgen 1.4.3 老式指针转换的严格诊断。原始仓库若未包含此项，在 `add_library(tet STATIC tetgen.cxx predicates.cxx)` 后添加：

```cmake
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  target_compile_options(tet PRIVATE -fpermissive)
endif()
```

## 4. PowerShell 从干净构建目录编译

### 4.1 进入源码目录并设置 PATH

在 **Windows PowerShell** 中：

```powershell
Set-Location 'D:\feng\workspace\OpenSeesPlayer'
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
```

确认工具来自同一套 MinGW-w64：

```powershell
where.exe gcc
where.exe g++
where.exe gfortran
where.exe cmake
where.exe mingw32-make
gcc --version
g++ --version
gfortran --version
cmake --version
```

`where.exe` 的首个结果应在 `C:\msys64\mingw64\bin` 下。

### 4.2 第一次配置前清理（可选）

首次构建且没有 `build-mingw` 目录时跳过。如果该目录曾用其他编译器或生成器配置过，确认没有构建正在运行，再在 **PowerShell** 清理它：

```powershell
if (Test-Path -LiteralPath 'build-mingw') {
  Remove-Item -LiteralPath 'build-mingw' -Recurse -Force
}
```

此命令只删除专用的 `build-mingw`，不要删除仓库已有的 `build`。

### 4.3 CMake 配置（PowerShell）

```powershell
cmake -S . -B build-mingw -G 'MinGW Makefiles' `
  -DCMAKE_C_COMPILER='C:/msys64/mingw64/bin/gcc.exe' `
  -DCMAKE_CXX_COMPILER='C:/msys64/mingw64/bin/g++.exe' `
  -DCMAKE_Fortran_COMPILER='C:/msys64/mingw64/bin/gfortran.exe' `
  -DCMAKE_BUILD_TYPE=Release `
  -DOPS_FINAL_TARGET=OpenSees `
  -DCMAKE_PREFIX_PATH='C:/msys64/mingw64' `
  -DTCL_INCLUDE_DIR='C:/msys64/mingw64/include' `
  -DTCL_LIBRARY='C:/msys64/mingw64/lib/libtcl86.dll.a' `
  -DHDF5_ROOT='C:/msys64/mingw64' `
  -DEigen3_INCLUDE_DIR='C:/msys64/mingw64/include/eigen3'
```

成功标志：显示 `Configuring done`、`Generating done`。若显示 MPI 未找到，对串行版属正常现象。不要在这一步切换到 Ninja 或 Visual Studio 生成器。PowerShell 使用反引号续行；若改在 Bash 执行，需改为 Bash 语法。

### 4.4 编译唯一目标（PowerShell）

```powershell
cmake --build build-mingw --target OpenSees --parallel 8
```

成功标志：命令退出码为 0，输出末尾显示 `[100%] Built target OpenSees`。内存较小时可将并行数调为 2 或 1。只运行一条构建命令，不要并行启动多个 make 进程。

本次构建过程曾遇到 Windows 终端长时间构建的问题；构建期间不要关闭 PowerShell，也不要把“进度在增长”当成成功。等待命令返回并确认退出码为 0。

## 5. Tcl 小算例验收

算例是一根长度 `L=1`、截面积 `A=1`、弹性模量 `E=1000` 的轴向杆，节点 1 固定，节点 2 受轴力 `P=10`。理论位移为 `PL/AE = 0.01`。

### 5.1 在 PowerShell 创建 Tcl 文件

```powershell
@'
wipe
model BasicBuilder -ndm 1 -ndf 1
node 1 0.0
node 2 1.0
fix 1 1
uniaxialMaterial Elastic 1 1000.0
element truss 1 1 2 1.0 1
pattern Plain 1 Linear {
    load 2 10.0
}
constraints Plain
numberer RCM
system BandGeneral
test NormDispIncr 1.0e-12 10
algorithm Linear
integrator LoadControl 1.0
analysis Static
set ok [analyze 1]
set u [nodeDisp 2 1]
puts "ANALYZE_STATUS=$ok"
puts "NODE2_DISP=$u"
if {$ok != 0 || abs($u - 0.01) > 1.0e-8} {
    puts stderr "TCL_SMOKE_TEST_FAILED"
    exit 1
}
puts "TCL_SMOKE_TEST_PASSED"
exit
'@ | Set-Content -LiteralPath 'build-mingw\smoke_truss.tcl' -Encoding ascii
```

### 5.2 在 PowerShell 运行并检查

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
& '.\build-mingw\OpenSees.exe' '.\build-mingw\smoke_truss.tcl'
$LASTEXITCODE
```

通过条件：输出有 `ANALYZE_STATUS=0`、节点位移约为 `0.01`、`TCL_SMOKE_TEST_PASSED`，且 `$LASTEXITCODE` 是 `0`。这样可同时确认程序启动、Tcl 解释器、静力分析和结果数值。

## 6. 本工作区的实际成功结果

本次首次最终链接失败，错误集中在大写 Fortran/LAPACK 符号未定义。加入别名汇编与 GNU 静态库链接组后，重新配置和构建：

```text
BUILD_EXIT=0
[100%] Built target OpenSees
```

产物 `build-mingw\OpenSees.exe` 为 35,339,951 字节。实际 Tcl 输出：

```text
ANALYZE_STATUS=0
NODE2_DISP=             0.01000000000000000021
TCL_SMOKE_TEST_PASSED
TCL_EXIT=0
```

构建日志为 `build-mingw-final.log`，脚本为 `build-mingw\smoke_truss.tcl`。

## 7. 常见问题

### CMake 找不到 Tcl、HDF5、Eigen3 或 OpenBLAS

确认安装的是 `mingw-w64-x86_64-*` 包，PowerShell PATH 前部有 `C:\msys64\mingw64\bin`，并核对第 2.3 节文件路径。不要将 `C:\msys64\usr\bin` 放到 MinGW 路径之前。

### 最终链接报 `undefined reference to DGESV`、`PML_2D` 或 `DSAUPD`

检查 `OTHER/symbol_alias.S` 和顶层 CMake 的 GNU/Windows 链接组是否存在。应用补丁后清理专用 `build-mingw` 并从第 4.3 节重新配置，避免旧缓存。

### 运行时报 Tcl、HDF5、OpenBLAS DLL 缺失

在 PowerShell 临时加入运行时路径：

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
```

### CMake 提示生成器与缓存不一致

不要在同一个构建目录切换编译器或生成器。按第 4.2 节只清理 `build-mingw`，再重新配置。

## 8. 后续增量编译

源码修改后，在 **PowerShell**：

```powershell
Set-Location 'D:\feng\workspace\OpenSeesPlayer'
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake --build build-mingw --target OpenSees --parallel 8
```

要复核运行结果时，重新执行第 5 节 Tcl 小算例。

## 9. 修改说明与代码注释索引

为便于从本仓库复现并审阅本次平台适配，源码注释已改为说明“为什么改、适用范围和要解决的错误”，新增/调整位置如下。

### 9.1 顶层 `CMakeLists.txt`

在 `add_library(OpenSeesLIB EXCLUDE_FROM_ALL)` 后新增 Windows + GNU 条件块：

```cmake
if(WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  enable_language(ASM)
  add_library(OPS_SymbolAlias STATIC ${OPS_BUNDLED_DIR}/symbol_alias.S)
  set_target_properties(OPS_SymbolAlias PROPERTIES LINKER_LANGUAGE CXX)
endif()
```

这里启用 GNU 汇编器并编译别名 shim。新增的源码注释标记为 `[MinGW fix, 2026-11-17]`，解释 gfortran/OpenBLAS 符号名差异以及静态库的互相引用。

在 `target_link_libraries(OpenSees ...)` 之后新增：

```cmake
if(WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  target_link_libraries(OpenSees
    -Wl,--start-group OpenSeesLIB OPS_SymbolAlias -Wl,--end-group)
endif()
```

链接组前的 `[MinGW fix]` 注释说明 GNU ld 必须反复扫描两个静态库，否则最终链接仍会报 Fortran 符号未定义。这两个条件块仅在 Windows + GNU 时执行。

### 9.2 `OTHER/symbol_alias.S`

新增的汇编 shim 使用尾跳转将大写符号转到 gfortran 的小写下划线实现。参数寄存器和调用栈保持不变，因此无需在汇编中重写各 Fortran 函数参数。映射分为三组，便于查找：

- LAPACK/BLAS：`DGBSV`、`DGESV`、`DPOTRF` 等 15 个符号；
- ARPACK：`DSAUPD`、`DSEUPD`；
- OpenSees 自带 Fortran 例程：PML、Steel、Drain、Dodd-Restrepo 等 12 个符号。

完整映射以此文件为准，不要只复制文档中的部分示例。

### 9.3 `OTHER/tetgen1.4.3/CMakeLists.txt`

给 `tet` target 增加 `-fpermissive`，并把代码注释标记为 `[MinGW/GCC compatibility, 2026-11-17]`。该选项只作用于 bundled tetgen，避免 GCC 13+ 将旧指针到整数转换诊断为错误；没有修改 tetgen C++ 源码，也不影响其他 target 的编译选项。

## 10. 从未修改的原始源码开始时的补丁顺序

如果你的代码目录没有上述适配，按以下顺序操作后再配置 CMake：

1. 新建 `OTHER/symbol_alias.S`，内容从当前工作区同名文件完整复制。
2. 在顶层 `CMakeLists.txt` 中找到 `add_library(OpenSeesLIB EXCLUDE_FROM_ALL)`，紧接着插入第 9.1 节第一个条件块。
3. 找到 `target_link_libraries(OpenSees ...)` 的闭括号，在其后插入第 9.1 节第二个条件块。
4. 在 `OTHER/tetgen1.4.3/CMakeLists.txt` 的 `add_library(tet STATIC tetgen.cxx predicates.cxx)` 后插入第 3 节 `-fpermissive` 条件块。
5. 检查补丁内容和文件保存后，再按第 4 节配置。若已经生成过 CMake cache，清理专用 `build-mingw` 后重新配置。

该补丁已在当前仓库完成真实编译和 Tcl 算例验证；独立项目目录中重新套用时请保持源代码版本和依赖的 ABI 一致。

## 11. 命令终端速查

| 操作 | 终端 | 关键命令 |
|---|---|---|
| 更新 MSYS2 和安装包 | MSYS2 MinGW 64-bit（Bash） | `pacman -Syu`、`pacman -S --needed ...` |
| 检查 `/mingw64` 头文件和库 | MSYS2 MinGW 64-bit（Bash） | `which`、`ls /mingw64/...` |
| 设置 Windows PATH、CMake 配置 | Windows PowerShell | `$env:Path = ...`、`cmake -S ...` |
| 编译串行 target | Windows PowerShell | `cmake --build build-mingw --target OpenSees --parallel 8` |
| 建立及执行 Tcl 算例 | Windows PowerShell | `Set-Content`、`& .\build-mingw\OpenSees.exe ...` |

PowerShell 中的反引号是行续接符；不要原样复制到 MSYS2 Bash。Bash 使用反斜杠续行，且路径风格应相应调整。


### 命令执行路径补充

- MSYS2 软件包安装和 `/mingw64` 文件检查：在 **MSYS2 MinGW 64-bit（Bash）**终端执行，工作目录任意。
- CMake 配置、OpenSees 编译、Tcl 算例脚本创建及运行：在 **Windows PowerShell** 执行，先进入源码根目录 `D:\feng\workspace\OpenSeesPlayer`。
- PowerShell 进入目录命令：`Set-Location 'D:\feng\workspace\OpenSeesPlayer'`。
- 配置命令使用 `cmake -S . -B build-mingw ...`；因此 `.` 必须是源码根目录。编译命令 `cmake --build build-mingw --target OpenSees --parallel 8` 也从源码根目录执行，不要先切换到 `build-mingw`。
- 完整逐条命令及 Tcl 验收命令请见《OpenSees-MinGW64-从零编译指南.md》的“快速定位”和第 4、5 节。
