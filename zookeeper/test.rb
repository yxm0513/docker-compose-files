require 'zookeeper'

# 设置 ZooKeeper 服务器的主机和端口
zookeeper_host = ENV['ZOOKEEPER_HOST'] || 'localhost:2181'

# 创建 ZooKeeper 客户端
zk = Zookeeper.new(zookeeper_host)

# Create a persistent node
node_path = '/example_node'
# [:path, :data, :acl, :ephemeral, :sequence, :callback, :callback_context]
zk.create(path: node_path, data: 'example_data')


# 读取节点数据
data, _stat = zk.get(path: node_path)
puts "Data in node '#{node_path}': #{data}"

# 关闭 ZooKeeper 连接
zk.close
