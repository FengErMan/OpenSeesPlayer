# OpenSees 串行版 MinGW-w64 编译记录

> 目标：在 Windows 上用 MSYS2 MinGW-w64 从当前仓库源码编译标准 Tcl 串行版 `OpenSees.exe`。不编译 OpenSeesSP、OpenSeesMP 或 OpenSeesPy。
>
> 本记录根据同仓库 `OpenSees-编译全记录.md` 的既有经验，在当前工作区 `D:\feng\workspace\OpenSeesPlayer` 上重新执行和核实。执行日期：2026-11-17。

## 1. 当前仓库与目标

当前源码根目录：`D:\feng\workspace\OpenSeesPlayer`。使用 CMake 项目提供的 `OpenSees` target；构建目录单独放在 `build-mingw`，避免污染已有 `build`。

只构建串行版的关键选项为 `-DOPS_FINAL_TARGET=OpenSees`，构建时再显式指定 `--target OpenSees`。MPI 未找到不会妨碍本目标；不需要安装 MPI。

## 2. 已核实环境

| 组件 | 当前检测结果 |
|---|---|
| MSYS2 MinGW-w64 根目录 | `C:\msys64\mingw64` |
| GCC / G++ / GFortran | GNU 15.1.0，均可用 |
| CMake / Make | `C:\msys64\mingw64\bin\cmake.exe`；`mingw32-make.exe` 可用 |
| Tcl | MSYS2 Tcl 8.6，CMake 找到 `libtcl86.dll.a`，init 脚本位于 `lib/tcl8.6` |
| HDF5 | CMake 找到 1.14.6 |
| Eigen3 | CMake 找到 `include/eigen3` |
| BLAS / LAPACK | 均解析到 `libopenblas.dll.a` |
| MPI | 未检测到；与串行目标无关 |

依赖文件可在 MSYS2 **MSYS2 MinGW 64-bit** 终端检查：

```bash
ls /mingw64/include/tcl.h
ls /mingw64/include/hdf5.h
ls -d /mingw64/include/eigen3/Eigen
ls /mingw64/lib/libtcl86.dll.a
ls /mingw64/lib/libhdf5.dll.a
ls /mingw64/lib/libopenblas.dll.a
```

缺包时在 **MSYS2 MinGW 64-bit** 终端安装：

```bash
pacman -Syu
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-make mingw-w64-x86_64-tcl mingw-w64-x86_64-hdf5 mingw-w64-x86_64-eigen3 mingw-w64-x86_64-openblas
```

如果 `pacman -Syu` 更新后提示关闭终端，关闭并重新打开 MinGW 64-bit 终端，再执行安装命令。不要在 MSYS shell 使用其 `/usr/bin` 编译器配置此工程；应选 MinGW 64-bit 环境。

## 3. 当前源码改动

本次未改动项目源码或 CMakeLists。记录中的其他 OpenSees 源码副本曾需要处理 GNU 符号大小写和旧 tetgen 警告，但这些改动不能直接套用到当前工作区：当前顶层 GNU 分支没有记录中所说的 `.so` 后缀硬编码，而且应先以当前构建的实际诊断决定是否需要补丁。

构建专用生成物位于 `build-mingw`。如果先前构建失败后调整了编译器或生成器，删除并重建该目录（命令见第 6 节），不要复用不同工具链生成的 CMakeCache。

## 4. 推荐完整构建流程

以下命令均在 **Windows PowerShell** 执行。项目路径带空格时请始终加引号。

### 4.1 检查工具

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
where.exe gcc
where.exe g++
where.exe gfortran
where.exe cmake
where.exe mingw32-make
gcc --version
gfortran --version
cmake --version
```

`where.exe` 首项应指向 `C:\msys64\mingw64\bin`。项目包含 Fortran 源文件，`gfortran` 必须可用。

### 4.2 配置（MinGW Makefiles）

```powershell
Set-Location 'D:\feng\workspace\OpenSeesPlayer'
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
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

不要把 PowerShell 的反引号续行符复制到 MSYS2 Bash；Bash 应改用反斜杠 `\`，或将命令写成单行。`-G 'MinGW Makefiles'` 对应 `mingw32-make`，不可在该构建目录里改用 Ninja 或 Visual Studio 生成器。

### 4.3 编译串行目标

```powershell
cmake --build build-mingw --target OpenSees --parallel 8
```

可按机器内存调整 `--parallel 8`。如果内存不足，改成 `--parallel 2` 或 `--parallel 1`。也可以直接：

```powershell
mingw32-make -C build-mingw -j8 OpenSees
```

两种构建命令选一种即可。显式指定 target 可以避免误以为正在构建 MPI 或 Python 变体。

## 5. 当前工作区实际执行情况

已在 PowerShell 中运行上面的 CMake 配置命令，成功生成 `build-mingw`。CMake 识别到 GNU 15.1.0 的 C、C++、Fortran 编译器，找到 ZLIB、HDF5 1.14.6、Tcl 8.6、Eigen3，并确认 BLAS 与 LAPACK 使用 OpenBLAS。

随后执行 `cmake --build build-mingw --target OpenSees -j 8`。实际构建在等待工具返回时停止，未得到完整构建日志，因此**不能据此声称编译成功**。目前也未确认 `build-mingw/OpenSees.exe` 生成。应按第 4.3 节重新运行，直到命令退出码为 0，再按第 7 节检查产物。

输出中出现 `genmmd.f` 的 Fortran 2018 arithmetic IF 警告；这是旧式 Fortran 语法警告，当前片段未显示为错误。由于执行结果没有完整退出状态，仍需重跑构建确认后续错误。

## 6. 常见问题与定位

### 6.1 找错编译器

PowerShell：

```powershell
where.exe gcc
where.exe g++
where.exe gfortran
```

确认 MinGW-w64 的 `bin` 排在前面。CMake 首次配置会把编译器路径写进 `CMakeCache.txt`；更换工具链后要用全新构建目录。

### 6.2 清理失败的构建目录后重新配置

仅当确定 `build-mingw` 是本次生成目录时，在 **PowerShell** 执行：

```powershell
Remove-Item -LiteralPath 'build-mingw' -Recurse -Force
```

然后从第 4.2 节重新配置。不要误删仓库中已有的 `build`。

### 6.3 Windows 命令行长度

沿用既有编译记录，使用 `MinGW Makefiles` 和 `mingw32-make`；不要擅自换成 Ninja。大型源码树展开大量 include 参数时，Windows 命令行长度可能成为问题。

### 6.4 Fortran 链接符号错误

若最终链接报告诸如 `undefined reference to DGESV`、`PML_2D` 等符号，属于 C++/Fortran 符号命名约定差异的可能性较高。先保存完整链接错误、确认实际库符号，再针对当前仓库添加映射补丁；不要盲目复制其他源码副本中的汇编 alias 文件或链接组改动。

### 6.5 Tcl/HDF5 DLL 运行时缺失

编译链接成功后运行 `OpenSees.exe` 仍可能因 DLL 不在 `PATH` 而失败。将 `C:\msys64\mingw64\bin` 加入运行进程 PATH；使用 PowerShell 可临时设置：

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
```

## 7. 编译完成后的验证

PowerShell：

```powershell
Test-Path 'build-mingw\OpenSees.exe'
Get-Item 'build-mingw\OpenSees.exe' | Select-Object FullName,Length,LastWriteTime
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
& '.\build-mingw\OpenSees.exe' -version
```

若该版本不接受 `-version`，直接启动解释器查看 banner，按 `exit` 退出。也可使用项目示例 Tcl 文件做一次简单计算。运行失败时先检查 DLL 搜索路径，并区分“程序不存在”“缺 DLL”和 Tcl 脚本错误。

## 8. 产物和复现摘要

预期串行可执行文件：`D:\feng\workspace\OpenSeesPlayer\build-mingw\OpenSees.exe`。

最短复现命令（**PowerShell**，首次构建前先执行配置命令）：

```powershell
Set-Location 'D:\feng\workspace\OpenSeesPlayer'
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake -S . -B build-mingw -G 'MinGW Makefiles' -DCMAKE_C_COMPILER='C:/msys64/mingw64/bin/gcc.exe' -DCMAKE_CXX_COMPILER='C:/msys64/mingw64/bin/g++.exe' -DCMAKE_Fortran_COMPILER='C:/msys64/mingw64/bin/gfortran.exe' -DCMAKE_BUILD_TYPE=Release -DOPS_FINAL_TARGET=OpenSees -DCMAKE_PREFIX_PATH='C:/msys64/mingw64' -DTCL_INCLUDE_DIR='C:/msys64/mingw64/include' -DTCL_LIBRARY='C:/msys64/mingw64/lib/libtcl86.dll.a' -DHDF5_ROOT='C:/msys64/mingw64' -DEigen3_INCLUDE_DIR='C:/msys64/mingw64/include/eigen3'
cmake --build build-mingw --target OpenSees --parallel 8
```

## 9. 本工作区最终构建与 Tcl 验证结果（2026-11-17）

### 9.1 首次链接失败及修复

完整编译首次在最终链接失败，诊断为 OpenSees 的 C++ 代码引用大写 Fortran/LAPACK 符号（如 `DGESV`、`PML_2D`、`DSAUPD`），而当前 MinGW gfortran/OpenBLAS 提供小写加下划线符号（如 `dgesv_`、`pml_2d_`、`dsaupd_`）。

为当前仓库添加如下适配：

- 在 `OTHER/symbol_alias.S` 中为 OpenBLAS/LAPACK、ARPACK 和 OpenSees Fortran 例程添加 29 个大写到小写下划线符号的尾跳转别名。
- 在顶层 `CMakeLists.txt` 的 GNU/Windows 分支启用 ASM，并构建静态库 `OPS_SymbolAlias`。
- 将 `OpenSeesLIB` 与别名库放进 GNU ld `--start-group/--end-group`，解决两库相互引用。

这些修改仅在 `WIN32` 且 C++ 编译器为 GNU 时生效；其他平台和编译器不受此条件分支影响。

### 9.2 最终构建证据

重新配置后执行：

```powershell
cmake --build build-mingw --target OpenSees --parallel 8
```

结果：`BUILD_EXIT=0`，输出包含 `[100%] Built target OpenSees`。可执行文件为：

```text
D:\feng\workspace\OpenSeesPlayer\build-mingw\OpenSees.exe
```

本次源码版本启动 banner 显示 **OpenSees 3.8.0 64-Bit**（仓库当前版本与先前记录的 3.7.1 不同）。构建日志保存在 `build-mingw-final.log`。

### 9.3 Tcl 静力小算例

实际算例脚本位于 `build-mingw/smoke_truss.tcl`。它建立长度 1、截面积 1、弹性模量 1000 的单根杆，固定节点 1，在节点 2 施加轴向荷载 10。理论位移为 `PL/AE = 10*1/(1000*1) = 0.01`。

运行命令（PowerShell）：

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
& '.\build-mingw\OpenSees.exe' '.\build-mingw\smoke_truss.tcl'
```

实际输出：

```text
ANALYZE_STATUS=0
NODE2_DISP=0.01000000000000000021
TCL_SMOKE_TEST_PASSED
TCL_EXIT=0
```

分析成功、位移与理论值一致，且程序退出码为 0。至此串行版构建与 Tcl 计算验证均通过。

### 9.4 后续增量重编译

源码或 CMake 改动后，在 **PowerShell** 中执行：

```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake --build build-mingw --target OpenSees --parallel 8
```

若需要从干净状态复现，先确认没有 `cmake`/`mingw32-make` 编译进程正在使用 `build-mingw`，再仅删除本次构建目录并按第 4.2 节重新配置。不要删除仓库原有的 `build` 目录。
