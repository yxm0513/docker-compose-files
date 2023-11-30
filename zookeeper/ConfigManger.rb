require 'zookeeper'

class ConfigManager
  def initialize(zookeeper_host, config_path)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @config_path = config_path
  end

  def set_config(data)
    @zookeeper.set(path: @config_path, data: data)
  end

  def get_config
    result = @zookeeper.get(path: @config_path)
    result[:data]
  end
end

# 使用协同配置管理
zookeeper_host = 'localhost:2181'
config_path = '/shared_config'

config_manager = ConfigManager.new(zookeeper_host, config_path)

# 设置配置信息
config_manager.set_config('{"database_host": "localhost", "database_port": 5432}')

# 获取配置信息
config = config_manager.get_config
puts "Current configuration: #{config}"

