# ROS2 HELLO\_ROS2 项目搭建完整教程

本教程将从零搭建 ROS2 基础项目 **HELLO\_ROS2**，适配 ROS2 Jazzy 版本。完整覆盖工作空间创建、Python/C\+\+ 标准化功能包创建、自定义节点开发、通用 CMake 编译工具封装、C\+\+ 包编译配置以及 CLion 高效编译环境适配，搭建一套标准化、可复用、高性能的 ROS2 开发工程模板。

## 一、创建项目工作空间目录

创建顶层项目文件夹 `HELLO_ROS2` 及源码子目录 `src`，并进入源码目录，为后续创建功能包做准备。

```bash
mkdir -p HELLO_ROS2/src && cd HELLO_ROS2/src
```

## 二、创建 Python / C\+\+ 标准化功能包

在工作空间 `src` 目录下，分别创建遵循 ROS2 官方规范的 Python、C\+\+ 功能包，工具自动生成基础目录、配置文件与默认节点模板。

### 2\.1 创建 Python 功能包（py\_pkg）

```bash
cd src
ros2 pkg create --build-type ament_python \
  --license Apache-2.0 \
  --node-name py_node \
  --maintainer-name "lzw1231" \
  --maintainer-email "lzw1231@sina.com" \
  --description "A Python ROS2 node" \
  py_pkg
```

### 2\.2 创建 C\+\+ 功能包（cxx\_pkg）

```bash
ros2 pkg create --build-type ament_cmake \
  --license Apache-2.0 \
  --node-name cxx_node \
  --dependencies rclcpp \
  --maintainer-name "lzw1231" \
  --maintainer-email "lzw1231@sina.com" \
  --description "A C++ ROS2 node" \
  cxx_pkg

# 返回工作空间根目录
cd ..
```

## 三、编写自定义 ROS2 节点业务代码

替换功能包默认生成的节点代码，实现节点初始化、动态获取节点名称、日志打印基础功能，完成最简可用 ROS2 节点开发。

### 3\.1 Python 节点

**文件路径**：`HELLO_ROS2/src/py_pkg/py_pkg/py_node.py`

```python
import rclpy
from rclpy.node import Node

class MyNode(Node):
    def __init__(self):
        super().__init__('py_node')

def main(args=None):
    # 初始化ROS2上下文
    rclpy.init(args=args)
    # 实例化自定义节点
    node = MyNode()
    
    # 动态获取节点名称并打印日志
    node_name = node.get_name()
    node.get_logger().info(f'{node_name}: Hello, ROS2!')
    
    # 保持节点运行
    rclpy.spin(node)
    # 销毁节点、关闭ROS2上下文
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
```

### 3\.2 C\+\+ 节点

**文件路径**：`HELLO_ROS2/src/cxx_pkg/src/cxx_node.cpp`

```cpp
#include <rclcpp/rclcpp.hpp>
#include <string>

int main(int argc, char * argv[])
{
    // 初始化ROS2上下文
    rclcpp::init(argc, argv);    
    
    // 创建节点实例
    auto node = std::make_shared<rclcpp::Node>("cxx_node");
    
    // 动态获取节点名称并打印日志
    std::string node_name_actual = node->get_name();
    RCLCPP_INFO(node->get_logger(), "Node %s: Hello, ROS2!", node_name_actual.c_str());
    
    // 循环阻塞节点
    rclcpp::spin(node);
    // 关闭ROS2上下文
    rclcpp::shutdown();
    return 0;
}
```

## 四、封装通用 CMake 编译工具

在工作空间根目录创建 `cmake` 公共配置目录，封装通用编译脚本，统一全局编译标准、依赖链接、安装规则，避免多节点重复编写 CMake 代码，适配批量开发。

### 4\.1 创建 cmake 目录

```bash
mkdir -p cmake
```

### 4\.2 通用编译配置脚本 ros2\_cxx\_setup\.cmake

**文件路径**：`HELLO_ROS2/cmake/ros2_cpp_setup.cmake`

```cmake
# ============================================================================
# ros2_cpp_setup.cmake
# 为 ROS2 C++ 包提供通用编译配置：
#   - 设置 C23 / C++26 标准和编译器警告
#   - 集成 ament_cmake 核心能力
#   - 配置测试 lint 依赖
#   - 封装 add_cxx_node 通用节点编译函数
# ============================================================================

# 防止配置文件重复包含
if (__ADD_CXX_NODE_INCLUDED)
    message(STATUS "[ros2_cpp_setup.cmake] 已经包含过，跳过重复包含")
    return()
endif ()
set(__ADD_CXX_NODE_INCLUDED TRUE)

# ----------------------------------------------------------------------------
# 1. 全局编译标准与编译器警告配置
# ----------------------------------------------------------------------------
set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 为GCC/Clang编译器开启严格警告检测
if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif ()

# ----------------------------------------------------------------------------
# 2. 引入ROS2核心编译依赖
# ----------------------------------------------------------------------------
find_package(ament_cmake REQUIRED)

# ----------------------------------------------------------------------------
# 3. 测试模块配置（仅测试模式生效）
# ----------------------------------------------------------------------------
if (BUILD_TESTING)
    find_package(ament_lint_auto REQUIRED)
    # 跳过版权与代码格式检测
    set(ament_cmake_copyright_FOUND TRUE)
    set(ament_cmake_cpplint_FOUND TRUE)
    ament_lint_auto_find_test_dependencies()
endif ()

# ----------------------------------------------------------------------------
# 4. 通用节点编译函数封装
# 用法：ros2_cpp_setup(<节点名> DEPENDS 依赖1 依赖2 ...)
# 说明：调用前需提前find_package引入对应依赖包
# ----------------------------------------------------------------------------
function(ros2_cpp_setup NODE_NAME)
    cmake_parse_arguments(NODE "" "" "DEPENDS" ${ARGN})

    # 定义节点源码文件路径
    set(SOURCE_FILE src/${NODE_NAME}.cpp)
    # 生成可执行文件
    add_executable(${NODE_NAME} ${SOURCE_FILE})

    # 传递节点名称宏定义
    target_compile_definitions(${NODE_NAME} PRIVATE NODE_NAME="${NODE_NAME}")

    # 配置头文件搜索路径
    target_include_directories(${NODE_NAME} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include/${PROJECT_NAME}>
    )

    # 绑定C/C++编译标准
    target_compile_features(${NODE_NAME} PUBLIC
            c_std_${CMAKE_C_STANDARD}
            cxx_std_${CMAKE_CXX_STANDARD}
    )

    # 链接自定义依赖包
    if (NODE_DEPENDS)
        ament_target_dependencies(${NODE_NAME} ${NODE_DEPENDS})
    endif ()

    # 配置节点安装路径
    install(TARGETS ${NODE_NAME} DESTINATION lib/${PROJECT_NAME})
endfunction()
```

## 五、配置 C\+\+ 功能包 CMakeLists\.txt

完全替换 cxx\_pkg 默认编译配置文件，引入全局通用 CMake 工具，标准化 C\+\+ 功能包编译流程。

**文件路径**：`HELLO_ROS2/src/cxx_pkg/CMakeLists.txt`

```cmake
# ============================================================================
# CMakeLists.txt
# ROS2 C++ 功能包主编译配置文件
# ============================================================================

# 最低CMake版本要求
cmake_minimum_required(VERSION 4.2)

# 定义功能包名称
project(cxx_pkg)

# 默认关闭测试模块
option(BUILD_TESTING "Build tests" OFF)

# 导入自定义CMake模块路径（关联根目录cmake配置）
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")

# 引入通用ROS2 C++编译配置
include(ros2_cpp_setup)

# 显式声明项目依赖
find_package(rclcpp REQUIRED)          # ROS2 C++核心客户端库

# 调用通用函数编译节点，绑定依赖
ros2_cpp_setup(cxx_node DEPENDS rclcpp)

# 生成ROS2功能包描述文件
ament_package()
```

## 六、CLion 外部编译工具完整配置

为 CLion 配置自定义外部编译工具，采用 **Clang \+ LLD \+ Ninja** 高性能编译链，替代原生编译方式，提升编译速度、代码检测规范性，支持一键编译、一键清理构建产物，适配 ROS2 Jazzy \+ Qt6 开发环境。

### 6\.1 配置入口

打开 CLion：`File -> Settings -> Tools -> External Tools`，新建自定义工具。

### 6\.2 外部工具核心参数

- **Program**：`/home/lzw/Projects/clion/colcon_build.sh`

- **Arguments**：留空 / 可填 clean

- **Working directory**：`$ProjectFileDir$`

### 6\.3 编译脚本 colcon\_build\.sh 完整内容

**文件路径**：`/home/lzw/Projects/clion/colcon_build.sh`

```bash
#!/bin/bash
# ROS2 Jazzy + Qt6 + Clang 构建脚本

# 颜色输出
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

# 清理模式判断
CLEAN_BUILD=false
[ "$1" = "clean" ] && CLEAN_BUILD=true

# 加载 ROS2 环境
echo -e "${BLUE}→ Loading ROS2 environment...${NC}"
source /opt/ros/jazzy/setup.bash > /dev/null 2>&1
echo -e "${GREEN}✓ ROS2 ready${NC}"
echo

# 导出 Qt6 路径（让 CMake 找到 Qt，保持 CMakeLists 干净）
export CMAKE_PREFIX_PATH="/home/lzw/Qt/6.11.1/gcc_64"

# 清理构建产物
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}→ Cleaning build artifacts...${NC}"
    for dir in build install log; do
        [ -d "$dir" ] && { echo -e "  ${CYAN}• Removing $dir/${NC}"; rm -rf "$dir"; } || \
        echo -e "  ${DIM}• $dir/ (not found, skipping)${NC}"
    done
    echo -e "${GREEN}✓ Clean completed${NC}"
    echo
fi

# 开始构建
echo -e "${BLUE}→ Building...${NC}"

colcon build \
    --base-paths src \
    --symlink-install \
    --event-handlers status+ \
    --cmake-args \
        -G Ninja \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_LINKER=/usr/bin/ld.lld-18 \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo

# 构建失败检查
if [ $? -ne 0 ]; then
    echo -e "\n${RED}${BOLD}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build completed successfully${NC}"

# 链接 compile_commands.json 给 CLion 使用
[ -f "build/compile_commands.json" ] && {
    ln -sf build/compile_commands.json ./
    echo -e "${GREEN}✓ compile_commands.json linked${NC}"
}

echo -e "\n${BOLD}${GREEN}✨ Colcon Build Completed! ✨${NC}"
```

### 6\.4 Clean 清理参数使用规则

本构建脚本支持动态参数控制编译模式，可通过 External Tools 的 **Arguments** 传参，灵活切换增量编译与全量清理编译。

- **常规增量编译（日常开发）**：Arguments 保持为空，仅编译改动代码，编译速度快。

- **全量清理重编（解决缓存报错）**：Arguments 填写 `clean`，执行前自动删除 build、install、log 目录，实现纯净全量编译。

### 6\.5 External Tools 快捷键配置

可为编译工具设置自定义快捷键，一键触发编译/清理，提升开发效率。

**配置入口**：`File -> Settings -> Keymap`

**配置步骤**：

1. 搜索已创建的 External Tools 工具名称；

2. 右键选择 **Add Keyboard Shortcut**；

3. 设置自定义快捷键（推荐 `Ctrl+Shift+B`）；

4. 无冲突则保存，即可快捷调用编译脚本。

为编译工具配置专属快捷键，摆脱鼠标点击，一键触发编译/清理，大幅提升开发效率。

**配置入口**：`File -> Settings -> Keymap`

**配置步骤**：

1. 在 Keymap 搜索栏中，搜索已创建的自定义 External Tools 工具名；

2. 右键对应工具，选择 **Add Keyboard Shortcut**；

3. 按下自定义组合快捷键（推荐 `Ctrl+Shift+B`，贴合编译习惯）；

4. 确认无快捷键冲突后保存，即可一键调用 ROS2 构建脚本。

### 6\.6 CLion 代码索引优化（仅首次项目初始化）

CLion 本地默认索引与 Clang\+Ninja 编译链不匹配时，会出现头文件标红、代码提示失效等问题。只需**项目首次配置执行一次**，后续日常开发无需重复操作。

**首次初始化索引流程**：

1. **清理缓存**：删除项目根目录 `.idea` 文件夹，清除旧索引缓存；

2. **载入编译配置**：打开编译生成的 `compile_commands.json`；

3. **工程模式载入**：以工程方式载入文件，CLion 自动基于真实编译参数重建索引；

4. **效果**：适配 C\+\+26、ROS2、Qt6 环境，解决索引异常，代码补全、跳转、语法校验精准可靠。

## 七、最终项目目录结构

```plain
HELLO_ROS2/
├── cmake/
│   └── ros2_cpp_setup.cmake      # 通用C++编译工具封装
└── src/
    ├── py_pkg/                   # Python功能包
    │   └── py_pkg/
    │       └── py_node.py        # Python自定义节点
    └── cxx_pkg/                  # C++功能包
        ├── src/
        │   └── cxx_node.cpp      # C++自定义节点
        └── CMakeLists.txt        # 自定义编译配置

```


