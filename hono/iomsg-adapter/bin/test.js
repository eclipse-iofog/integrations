const { Hono } = require('../lib/client.js')

var hono = new Hono('localhost', 8080, 'DEFAULT_TENANT', '4711')
hono.PublishTelemetry('{ "softly": "spoken", "json": "data" }')
hono.PublishEvent('{ "softly": "spoken", "json": "data" }')
