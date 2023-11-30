import influxdb_client, os, time
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

token='Oi0ljsUV6nJLBRQWGBJRnvQjeGJWvPQFUp-cbE6QoMdu-OudXZbaYnklv4o57oJpXpcsVx_BzgwsCOdCgFoclQ=='
org = "test"
url = "http://10.151.3.74:8086"
client = influxdb_client.InfluxDBClient(url=url, token=token, org=org)
bucket="test"

write_api = client.write_api(write_options=SYNCHRONOUS)
   
for value in range(5):
  point = (
    Point("measurement1")
    .tag("tagname1", "tagvalue1")
    .field("field1", value)
  )
  write_api.write(bucket=bucket, org="test", record=point)
  time.sleep(1) # separate points by 1 second


query_api = client.query_api()

query = """from(bucket: "test")
 |> range(start: -10m)
 |> filter(fn: (r) => r._measurement == "measurement1")"""
tables = query_api.query(query, org="test")

for table in tables:
  for record in table.records:
    print(record)
