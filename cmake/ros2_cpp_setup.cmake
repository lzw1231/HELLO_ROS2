# ============================================================================
# ros2_cpp_setup.cmake
# ROS2 C++ 项目构建配置脚本
# ----------------------------------------------------------------------------
# 主要功能：
#   1. 设置 C23 / C++26 标准
#   2. 集成 ament_cmake 构建系统
#   3. 可选启用代码检查工具（lint）
#   4. 提供 ros2_cxx_setup() 函数简化节点创建
# ============================================================================

# 防止重复包含
if (__ADD_CXX_NODE_INCLUDED)
    message(STATUS "[ros2_cpp_setup.cmake] 已加载，跳过")
    return()
endif ()
set(__ADD_CXX_NODE_INCLUDED TRUE)

# ----------------------------------------------------------------------------
# 1. 设置 C/C++ 语言标准
# ----------------------------------------------------------------------------
set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# GCC/Clang 启用常用警告
if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif ()

# ----------------------------------------------------------------------------
# 2. 引入 ROS2 ament 构建系统
# ----------------------------------------------------------------------------
find_package(ament_cmake REQUIRED)

# ----------------------------------------------------------------------------
# 3. 代码质量检查（仅在 BUILD_TESTING=ON 时启用）
# ----------------------------------------------------------------------------
if (BUILD_TESTING)
    find_package(ament_lint_auto REQUIRED)
    # 避免重复查找已存在的 lint 工具
    set(ament_cmake_copyright_FOUND TRUE)
    set(ament_cmake_cpplint_FOUND TRUE)
    ament_lint_auto_find_test_dependencies()
endif ()

# ----------------------------------------------------------------------------
# 4. 创建 ROS2 节点的便捷函数
#
# 用法：
#   ros2_cxx_setup(<节点名称> DEPENDS <依赖包1> <依赖包2> ...)
#
# 说明：
#   - 自动从 src/<节点名称>.cpp 编译可执行文件
#   - 自动配置 include/ 目录的头文件搜索路径
#   - 通过 DEPENDS 参数自动查找并链接依赖包
#   - 自动安装可执行文件到 lib/${PROJECT_NAME}
#   - 如果存在 launch 目录，一并安装
# ----------------------------------------------------------------------------
function(ros2_cxx_setup NODE_NAME)
    cmake_parse_arguments(NODE "" "" "DEPENDS" ${ARGN})

    # 创建可执行文件（源文件固定位于 src/ 目录）
    add_executable(${NODE_NAME} src/${NODE_NAME}.cpp)

    # 将节点名称作为宏定义传入代码
    target_compile_definitions(${NODE_NAME} PRIVATE NODE_NAME="${NODE_NAME}")

    # 配置头文件搜索路径（支持构建时和安装后两种场景）
    target_include_directories(${NODE_NAME} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:include/${PROJECT_NAME}>
    )

    # 指定 C/C++ 标准版本
    target_compile_features(${NODE_NAME} PUBLIC
            c_std_${CMAKE_C_STANDARD}
            cxx_std_${CMAKE_CXX_STANDARD}
    )

    # 处理依赖包
    if (NODE_DEPENDS)
        ament_target_dependencies(${NODE_NAME} ${NODE_DEPENDS})
    endif ()

    # 安装可执行文件
    install(TARGETS ${NODE_NAME} DESTINATION lib/${PROJECT_NAME})

    # 可选安装 launch 目录
    install(DIRECTORY launch
            DESTINATION share/${PROJECT_NAME}
            OPTIONAL
    )
endfunction()