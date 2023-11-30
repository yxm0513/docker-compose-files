# example.rb
require 'elasticsearch'


# 连接到本地Elasticsearch节点
client = Elasticsearch::Client.new(
  log: true,
  transport_options: { ssl: { verify: false } }
)

# 创建一个索引
index_name = 'my_index'
index_exists = client.indices.exists?(index: index_name)

# Create the index if it doesn't exist
unless index_exists
  client.indices.create(index: index_name, body: {
    settings: {
      number_of_shards: 1,
      number_of_replicas: 0
    },
    mappings: {
      properties: {
        title: { type: 'text' },
        content: { type: 'text' }
      }
    }
  })
  puts "Index '#{index_name}' created successfully."
else
  puts "Index '#{index_name}' already exists."
end

# 索引一些文档
documents = [
  { title: 'Document 1', content: 'This is the content of document 1.' },
  { title: 'Document 2', content: 'Content of document 2.' }
]

documents.each_with_index do |doc, id|
  client.index(index: index_name, id: id + 1, body: doc)
end

# 搜索文档
response = client.search(index: index_name, body: {
  query: {
    match: { content: 'content' }
  }
})

puts "Search Results:"
response['hits']['hits'].each do |hit|
  puts "ID: #{hit['_id']}, Score: #{hit['_score']}, Title: #{hit['_source']['title']}"
end

