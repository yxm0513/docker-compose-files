require 'bunny'

# 连接到RabbitMQ服务器
connection = Bunny.new(
  host: 'localhost',
  port: 5672,
  user: 'user',
  password: 'password'
)
connection.start

# 创建一个通道
channel = connection.create_channel

# 声明一个队列
queue_name = 'hello'
queue = channel.queue(queue_name)

# 发送消息到队列
message = 'Hello, RabbitMQ!'
queue.publish(message)
puts " [x] Sent '#{message}'"

# 接收消息从队列
puts ' [*] Waiting for messages. To exit press CTRL+C'
queue.subscribe(block: true) do |_delivery_info, _properties, body|
  puts " [x] Received '#{body}'"
end

