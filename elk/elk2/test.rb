require 'logstash-logger'

logger = LogStashLogger.new(
  type: :tcp,
  host: 'localhost',
  port: 5000,
  sync: true
)

logger.info('This is a sample log message sent to Logstash')

# Make sure to close the logger connection to flush the logs
logger.close
