import rclpy
from rclpy.node import Node

class MyNode(Node):
    def __init__(self):
        super().__init__('py_node')

def main(args=None):
    rclpy.init(args=args)
    node = MyNode()
    
    # 使用变量获取节点名称
    node_name = node.get_name()
    node.get_logger().info(f'{node_name}: Hello, ROS2!')
    
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
