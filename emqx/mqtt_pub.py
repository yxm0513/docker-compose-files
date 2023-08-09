import paho.mqtt.client as paho
broker="10.151.3.74"
port=1883
def on_publish(client,userdata,result):             #create function for callback
    print("data published \n")
    pass
client1= paho.Client("control1")                           #create client object
client1.on_publish = on_publish                          #assign function to callback
client1.connect(broker,port, keepalive=65535)                                 #establish connection
ret= client1.publish("testtopic/1","on")        
