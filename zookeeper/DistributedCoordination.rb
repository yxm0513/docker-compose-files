require 'zookeeper'

class DistributedCoordination
  def initialize(zookeeper_host, coordination_path)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @coordination_path = coordination_path
  end

  def coordinate_task(task_name)
    task_node = "#{@coordination_path}/#{task_name}"

    # 创建临时节点表示任务开始
    @zookeeper.create(path: task_node, data: 'task_started', flags: Zookeeper::CreateFlag::EPHEMERAL)

    # 等待其他节点完成任务
    wait_for_completion(task_name)

    # 执行任务代码...
    puts "Task '#{task_name}' is being coordinated."

    # 完成任务后删除节点
    @zookeeper.delete(path: task_node)
  end

  private

  def wait_for_completion(task_name)
    while true
      children, _stat = @zookeeper.get_children(path: @coordination_path)

      if children.empty?
        puts "All nodes have completed the task '#{task_name}'."
        break
      else
        puts "Waiting for other nodes to complete the task '#{task_name}'..."
        sleep(1)
      end
    end
  end
end

# 使用分布式协调
zookeeper_host = 'localhost:2181'
coordination_path = '/coordination'
task_name = 'example_task'

coordination = DistributedCoordination.new(zookeeper_host, coordination_path)
coordination.coordinate_task(task_name)

# 这里可以添加一个等待或者保持程序运行的机制，以便观察协调的结果
gets.chomp

