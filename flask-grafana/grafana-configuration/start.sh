curl --request POST http://localhost:3000/api/datasources --header 'Content-Type: application/json' -d @datasources.json
curl --request POST http://localhost:3000/api/dashboards/db --header 'Content-Type: application/json' -d @dashboard.json
