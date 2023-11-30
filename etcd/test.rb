require 'etcd'

etcd = Etcd.client(host: 'localhost', port: 2379)

# 设置键值对
begin
  response = etcd.set('/example/key', value: 'some_value')
  puts "Set successful!" if response.success?
rescue JSON::ParserError => e
  puts "JSON parsing error: #{e.message}"
rescue Etcd::Error => e
  puts "Etcd error: #{e.message}"
end

# 获取键值对
response = etcd.get('/example/key')

puts "Key: #{response.key}, Value: #{response.value}"

# 删除键值对
etcd.delete('/example/key')

# 关闭 Etcd 连接
etcd.close
