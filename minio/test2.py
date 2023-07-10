from bulkboto3 import BulkBoto3
TARGET_BUCKET = "test-bucket"
NUM_TRANSFER_THREADS = 50
TRANSFER_VERBOSITY = True

bulkboto_agent = BulkBoto3(
    resource_type="s3",
    endpoint_url="http://localhost:2004",
    aws_access_key_id="11111111",
    aws_secret_access_key="11111111",
    max_pool_connections=300,
    verbose=TRANSFER_VERBOSITY,
)

bulkboto_agent.create_new_bucket(bucket_name=TARGET_BUCKET)

bulkboto_agent.upload_dir_to_storage(
     bucket_name=TARGET_BUCKET,
     local_dir="test_dir",
     storage_dir="my_storage_dir",
     n_threads=NUM_TRANSFER_THREADS,
)
