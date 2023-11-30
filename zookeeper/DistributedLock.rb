require 'zookeeper'

class DistributedLock
  def initialize(zookeeper_host, lock_path)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @lock_path = lock_path
  end

  def acquire_lock
    create_lock_node
    wait_for_lock
  end

  def release_lock
    @zookeeper.delete(path: @lock_path)
  end

  private

  def create_lock_node
    @zookeeper.create(
      path: @lock_path,
      data: 'lock_data',
      flags: Zookeeper::CreateFlag::EPHEMERAL | Zookeeper::CreateFlag::SEQUENCE
    )
  end

  def wait_for_lock
    while true
      children = @zookeeper.get_children(path: File.dirname(@lock_path))[:children].sort

      if File.basename(@lock_path) == children.first
        puts "Lock acquired!"
        break
      else
        sleep(1)
      end
    end
  end
end

# 使用分布式锁
zookeeper_host = 'localhost:2181'
lock_path = '/distributed_lock'

lock = DistributedLock.new(zookeeper_host, lock_path)

begin
  lock.acquire_lock
  # 执行需要加锁的操作
  puts "Performing locked operation..."
  sleep(5)
ensure
  lock.release_lock
  puts "Lock released."
end

