const { Hono } = require('../lib/client.js')
const ioFogClient = require('@iofog/nodejs-sdk')

const honoConst = {
  device: '4711',
  tenant: 'DEFAULT_TENANT',
  port: 8080
}

let currentConfig = {
  host: ''
}

const fetchConfig = () => {
  ioFogClient.getConfig(
    {
      onBadRequest: (errorMsg) => {
        console.error('There was an error in request for getting config from the local API: ', errorMsg)
      },
      onNewConfig: (config) => {
        try {
          if (config) {
            if (JSON.stringify(config) !== JSON.stringify(currentConfig)) {
              currentConfig = config
            }
          }
        } catch (error) {
          console.error('Couldn\'t stringify Config JSON: ', error)
        }
      },
      onError: (error) => {
        console.error('There was an error getting config from the local API: ', error)
      }
    }
  )
}

const main = () => {
  // Handle ioFog
  fetchConfig()
  ioFogClient.wsControlConnection(
    {
      onNewConfigSignal: () => { fetchConfig() },
      onError: (error) => {
        console.error('There was an error with Control WebSocket connection to ioFog: ', error)
      }
    }
  )
  ioFogClient.wsMessageConnection(
    function (ioFogClient) { /* don't need to do anything on opened Message Socket */ },
    {
      onMessages: (messages) => {
        const hono = new Hono(currentConfig.host, honoConst.port, honoConst.tenant, honoConst.device)
        if (messages) {
          for (const message of messages) {
            hono.PublishEvent(JSON.parse(message.contentdata.toString('ascii')))
          }
        }
      },
      onMessageReceipt: (messageId, timestamp) => { /* we received the receipt for posted msg */ },
      onError: (error) => {
        console.error('There was an error with Message WebSocket connection to ioFog: ', error)
      }
    }
  )
}

ioFogClient.init('iofog', 54321, null, main)
