const { put } = require('superagent')
const { format } = require('util')

class Hono {
  constructor (address, port, tenant, device) {
    this.baseURL = format('%s:%d', address, port)
    this.telemetryEndpoint = format('%s/telemetry/%s/%s', this.baseURL, tenant, device)
    this.eventEndpoint = format('%s/event/%s/%s', this.baseURL, tenant, device)
    this.contentType = 'application/json'
  }

  async PublishTelemetry (data) {
    try {
      await put(this.telemetryEndpoint).set('content-type', this.contentType).send(data)
    } catch (err) {
      console.error(err)
    }
  }

  async PublishEvent (data) {
    try {
      await put(this.eventEndpoint).set('content-type', this.contentType).send(data)
    } catch (err) {
      console.error(err)
    }
  }
}

module.exports = {
  Hono
}
