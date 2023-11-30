require 'zookeeper'

class LeaderElection
  def initialize(zookeeper_host, election_path, node_id)
    @zookeeper = Zookeeper.new(zookeeper_host)
    @election_path = election_path
    @node_id = node_id
  end

  def participate_in_election
    election_node = "#{@election_path}/node_#{@node_id}"
    @zookeeper.create(path: election_node, data: 'candidate', flags: Zookeeper::CreateFlag::EPHEMERAL | Zookeeper::CreateFlag::SEQUENCE)

    check_for_leader
  end

  private

  def check_for_leader
    while true
      election_nodes, _stat = @zookeeper.get_children(path: @election_path)
      sorted_nodes = election_nodes.sort

      leader_node = sorted_nodes.first
      current_node = "node_#{@node_id}"

      if leader_node == current_node
        puts "Node #{@node_id} is the leader!"
        break
      else
        puts "Node #{@node_id} is not the leader. Waiting for leader election..."
        sleep(1)
      end
    end
  end
end

# 使用分布式选举
zookeeper_host = 'localhost:2181'
election_path = '/election'
node_id = '1'

leader_election = LeaderElection.new(zookeeper_host, election_path, node_id)
leader_election.participate_in_election

# 这里可以添加一个等待或者保持程序运行的机制，以便观察选举结果
gets.chomp

