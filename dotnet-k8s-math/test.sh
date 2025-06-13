curl -X POST http://localhost:31002/Math/multiply -H "Content-Type: application/json" -d '{"x":2,"y":3}'
# {"result":6}

curl -X POST http://localhost:31002/Math/power -H "Content-Type: application/json" -d '{"x":7,"y":300}'
# {"result":8}

