const ioFogClient = require('@iofog/nodejs-sdk')

const buildMessage = (amqpMessage) => {
  const INFOTYPE = 'heartrate'
  const INFOFORMAT = 'utf-8/json'
  const jsonMsg = JSON.stringify('')
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
    contentdata: jsonMsg
  })
}

const listenForAMQPMessages = (amqpConfig) => {
  const container = require('rhea')

  const received = 0

  container.on('message', function (context) {
    if (context.message.id && context.message.id < received) {
      // ignore duplicate message
      return
    }
    console.log(JSON.stringify(context.message.body))
    if (context.message.body) {
      const ioMessage = buildMessage(context.message.body)
      if (ioMessage) {
        ioFogClient.wsSendMessage(ioMessage)
      } else {
        console.info(`Message ${context.message.body} didn't pass transformation. Nothing to send.`)
      }
    }
  })

  container.connect({ port: amqpConfig.port, host: amqpConfig.host, idle_time_out: 5000 }).open_receiver(amqpConfig.queue)
}

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
      onMessages: (messages) => {},
      onMessageReceipt: (messageId, timestamp) => { /* we received the receipt for posted msg */ },
      onError: (error) => {
        console.error('There was an error with Message WebSocket connection to ioFog: ', error)
      }
    }
  )

  // Listen for AMQP messages
  const amqpConfig = {
    port: 51121,
    host: 'my-super-host',
    queue: 'my-super-queue-name'
  }
  listenForAMQPMessages(amqpConfig)
}

ioFogClient.init('iofog', 54321, null, main)
