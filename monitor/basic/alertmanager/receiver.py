from flask import Flask, request

app = Flask(__name__)

@app.route('/alert', methods=['POST'])
def receive_alert():
    if request.method == 'POST':
        alert_data = request.json
        print("Received Alert:")
        print(alert_data)
        return 'Alert received successfully\n', 200
    else:
        return 'Invalid request method\n', 400

if __name__ == '__main__':
    app.run('0.0.0.0', port=5000)

