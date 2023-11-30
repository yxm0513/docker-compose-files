require 'zookeeper'

class ServiceDiscovery
  def initialize(zookeeper_host, service_path)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @service_path = service_path
  end

  def register_service(service_name, service_address, service_port)
    service_node = "#{@service_path}/#{service_name}"
    service_data = { 'address' => service_address, 'port' => service_port }.to_json
    @zookeeper.create(path: service_node, data: service_data, flags: 0)
    puts "Service '#{service_name}' registered at '#{service_node}'"
  end

  def discover_services
    services = []
    children = @zookeeper.get_children(path: @service_path)[:children]

    children.each do |service_name|
      service_node = "#{@service_path}/#{service_name}"
      service_data = @zookeeper.get(path: service_node)[:data]
      services << { 'name' => service_name, 'data' => JSON.parse(service_data) }
    end

    services
  end
end

# 使用服务发现
zookeeper_host = 'localhost:2181'
service_path = '/services'

service_discovery = ServiceDiscovery.new(zookeeper_host, service_path)

# 注册服务
service_discovery.register_service('web_service', 'localhost', 8080)
service_discovery.register_service('api_service', 'localhost', 5000)

# 发现服务
discovered_services = service_discovery.discover_services

puts 'Discovered services:'
discovered_services.each do |service|
  puts "Name: #{service['name']}, Address: #{service['data']['address']}, Port: #{service['data']['port']}"
end

