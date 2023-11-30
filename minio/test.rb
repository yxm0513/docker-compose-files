require 'aws-sdk-s3'

# 设置 MinIO 的访问密钥和密钥
minio_access_key = '11111111'
minio_secret_key = '11111111'

# 设置 MinIO 的端点和桶名称
minio_endpoint = 'http://localhost:2004'
minio_bucket_name = 'testbucket'

# 创建 MinIO S3 客户端
s3_client = Aws::S3::Client.new(
  endpoint: minio_endpoint,
  access_key_id: minio_access_key,
  secret_access_key: minio_secret_key,
  region: 'us-east-1', # MinIO 不要求设置区域，这里设置为默认值
  force_path_style: true # 使用路径样式访问，适用于 MinIO
)

bucket_exists = s3_client.list_buckets.buckets.any? { |bucket| bucket.name == minio_bucket_name }

# Create the bucket if it does not exist
unless bucket_exists
  s3_client.create_bucket(bucket: minio_bucket_name)
  puts "Bucket '#{minio_bucket_name}' created successfully!"
else
  puts "Bucket '#{minio_bucket_name}' already exists!"
end

# 上传文件到 MinIO 桶
file_path = 'test.py'
object_key = 'test.py'

File.open(file_path, 'rb') do |file|
  s3_client.put_object(
    bucket: minio_bucket_name,
    key: object_key,
    body: file
  )
end

puts "File uploaded successfully!"

# 列出 MinIO 桶中的所有对象
resp = s3_client.list_objects_v2(bucket: minio_bucket_name)

puts "Objects in the bucket:"
resp.contents.each do |object|
  puts object.key
end

