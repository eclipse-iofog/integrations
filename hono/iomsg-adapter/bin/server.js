const { Hono } = require('../lib/client.js')
const ioFogClient = require('@iofog/nodejs-sdk')

const hono = new Hono(process.env.HONO_ADAPTER_HOST, 8080, 'DEFAULT_TENANT', process.env.HONO_DEVICE)

const main = () => {
  // Handle ioFog
  ioFogClient.wsControlConnection(
    {
      onNewConfigSignal: () => {},
      onError: (error) => {
        console.error('There was an error with Control WebSocket connection to ioFog: ', error)
      }
    }
  )
  ioFogClient.wsMessageConnection(
    function (ioFogClient) { /* don't need to do anything on opened Message Socket */ },
    {
      onMessages: (messages) => {
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
