const Hono = require('../lib/client.js').Hono
const ioFogClient = require('@iofog/nodejs-sdk')

const hono = new Hono(process.env.HONO_ADAPTER_HOST, 8080, 'DEFAULT_TENANT', process.env.HONO_DEVICE)

const main = () => {
  // Handle ioFog
  ioFogClient.wsControlConnection(
    {
      'onNewConfigSignal':
        function onNewConfigSignal () {
          // upon receiving signal about new config available -> go get it
          // fetchConfig();
        },
      'onError':
        function onControlSocketError (error) {
          console.error('There was an error with Control WebSocket connection to ioFog: ', error)
        }
    }
  )
  ioFogClient.wsMessageConnection(
    function (ioFogClient) { /* don't need to do anything on opened Message Socket */ },
    {
      'onMessages':
        function onMessagesSocket (messages) {
          if (messages) {
            // when getting new messages we store newest and delete oldest corresponding to configured limit
            for (let i = 0; i < messages.length; i++) {
              const message = messages[i]
              hono.PublishEvent(JSON.parse(message.contentdata.toString('ascii')))
            }
          }
        },
      'onMessageReceipt':
          function (messageId, timestamp) { /* we received the receipt for posted msg */ },
      'onError':
        function onMessageSocketError (error) {
          console.error('There was an error with Message WebSocket connection to ioFog: ', error)
        }
    }
  )
}

ioFogClient.init('iofog', 54321, null, main)
