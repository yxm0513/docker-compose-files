from http.server import HTTPServer, BaseHTTPRequestHandler
import time
import random

# 示例指标
metrics = {
    'cpu_usage': lambda: random.uniform(0, 100),
    'memory_usage': lambda: random.uniform(0, 100),
    'disk_space': lambda: random.uniform(0, 100),
}

# 导出指标的HTTP请求处理器
class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()

            # 生成指标数据
            metric_data = ['# HELP {} Sample metric help\n# TYPE {} gauge\n{} {}\n'.format(metric, metric, metric, value()) for metric, value in metrics.items()]

            # 发送指标数据
            self.wfile.write('\n'.join(metric_data).encode())
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Not Found')

# 启动HTTP服务器
def run(server_class=HTTPServer, handler_class=MetricsHandler, port=8000):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f'Starting exporter on port {port}...')
    httpd.serve_forever()

if __name__ == '__main__':
    run()

