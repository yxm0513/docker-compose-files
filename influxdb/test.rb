require 'influxdb-client'

# You can generate an API token from the "API Tokens Tab" in the UI
token = 'Oi0ljsUV6nJLBRQWGBJRnvQjeGJWvPQFUp-cbE6QoMdu-OudXZbaYnklv4o57oJpXpcsVx_BzgwsCOdCgFoclQ=='
org = 'test'
bucket = 'test'

client = InfluxDB2::Client.new('http://10.151.3.74:8086', token,
  precision: InfluxDB2::WritePrecision::NANOSECOND)


query = "from(bucket: \"test\") |> range(start: -1h)"

tables = client.create_query_api.query(query: query, org: org)
tables.each do |_, table|
  table.records.each do |record|
    puts "#{record.time} #{record.measurement}: #{record.field}=#{record.value}"
  end
end

client.close!
