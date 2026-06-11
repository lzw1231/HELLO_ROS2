#include <rclcpp/rclcpp.hpp>
#include <string>

int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);    
    
    auto node = std::make_shared<rclcpp::Node>("cxx_node");
    
    // 使用变量获取节点名称并输出
    std::string node_name_actual = node->get_name();
    RCLCPP_INFO(node->get_logger(), "Node %s: Hello, ROS2!", node_name_actual.c_str());
    
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}
