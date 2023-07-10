from minio import Minio
client = Minio('http://localhost:2004/', 
               '11111111',  
               '11111111')

# check if bucket already exists
found = client.bucket_exists("test_bucket")
# create bucket if it does not exist
if not found:
    client.make_bucket("test_bucket")
else:
    print("Bucket 'test_bucket' already exists")

