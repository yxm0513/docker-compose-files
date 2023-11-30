require 'zookeeper'

class ServiceWatcher
  def initialize(zookeeper_host, service_path)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @service_path = service_path
  end

  def watch_services
    children, _stat = @zookeeper.get_children(path: @service_path, watch: true)

    puts 'Initial services:'
    children.each { |service_name| puts "Service: #{service_name}" }

    # 设置 Watcher
    @zookeeper.register(path: @service_path) do |event|
      puts "Service event: #{event.type}"

      if event.type == Zookeeper::ZOO_CHANGED_EVENT
        # 节点发生变化，重新获取服务列表
        updated_services = @zookeeper.get_children(path: @service_path)[:children]
        puts 'Updated services:'
        updated_services.each { |service_name| puts "Service: #{service_name}" }
      end

      # 重新注册 Watcher
      watch_services
    end
  end
end

# 使用 Watcher 监听服务节点变化
zookeeper_host = 'localhost:2181'
service_path = '/services'

service_watcher = ServiceWatcher.new(zookeeper_host, service_path)
service_watcher.watch_services

# 这里可以添加一个等待或者保持程序运行的机制，以便观察 Watcher 的回调
gets.chomp

