const ioFogClient = require('@iofog/nodejs-sdk')

let currentConfig = {
  port: 51121,
  host: 'my-super-host',
  queue: 'my-super-queue-name',
  username: 'http-adapter@HONO',
  password: 'http-secret'
}

const buildMessage = (amqpMessage) => {
  const INFOTYPE = 'ioMessageAdapter'
  const INFOFORMAT = amqpMessage.content_type
  const msg = amqpMessage.body.toString()
  return ioFogClient.ioMessage({
    tag: '',
    groupid: '',
    sequencenumber: 1,
    sequencetotal: 1,
    priority: 0,
    authid: '',
    authgroup: '',
    chainposition: 0,
    hash: '',
    previoushash: '',
    nonce: '',
    difficultytarget: 0,
    infotype: INFOTYPE,
    infoformat: INFOFORMAT,
    contextdata: '',
    contentdata: msg
  })
}

const listenForAMQPMessages = (amqpConfig) => {
  const container = require('rhea')

  /**
   * Default SASL behaviour is as follows. If the username and password
   * are both specified, PLAIN will be used. If only a username is
   * specified, ANONYMOUS will be used. If neither is specified, no SASl
   * layer will be used.
   */
  container.options.username = amqpConfig.username
  container.options.password = amqpConfig.password

  const received = 0

  container.on('message', function (context) {
    if (context.message.id && context.message.id < received) {
      // ignore duplicate message
      return
    }
    console.log(JSON.stringify(context.message))
    if (context.message) {
      const ioMessage = buildMessage(context.message)
      if (ioMessage) {
        ioFogClient.wsSendMessage(ioMessage)
      } else {
        console.info(`Message ${context.message.body} didn't pass transformation. Nothing to send.`)
      }
    }
  })

  container.connect({ port: amqpConfig.port, host: amqpConfig.host, idle_time_out: 5000 }).open_receiver(amqpConfig.queue)
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
              currentConfig = { ...currentConfig, ...config }
              onNewConfig()
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

const onNewConfig = () => {
  // Listen for AMQP messages
  listenForAMQPMessages(currentConfig)
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
      onMessages: (messages) => {},
      onMessageReceipt: (messageId, timestamp) => { /* we received the receipt for posted msg */ },
      onError: (error) => {
        console.error('There was an error with Message WebSocket connection to ioFog: ', error)
      }
    }
  )
}

ioFogClient.init('iofog', 54321, null, main)
