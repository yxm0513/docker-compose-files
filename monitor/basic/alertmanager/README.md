python receiver.py



prometheus/alert.yml

- name: test
  rules:
  - alert: mytest
    expr: cpu_usage > 20
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "from my exporter"
      description: "from my export"
