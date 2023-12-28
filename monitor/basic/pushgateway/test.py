import requests
import time
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

# 创建一个Registry
registry = CollectorRegistry()

# 创建一个Gauge指标
gauge = Gauge('example_metric', 'Example metric description', registry=registry)

# 设置Gauge的值
gauge.set(50)

# 推送指标到Pushgateway
push_to_gateway('localhost:9091', job='example_job', registry=registry)

