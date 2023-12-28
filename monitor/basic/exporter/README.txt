python3 test_exporter.py



prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'my_exporter'
    static_configs:
      - targets: ['localhost:8000']

重启prometheus, 登录prometheus :9090, 都是cpu_usage Execute


grafana类似, 添加dashboard, panel
