argv = require('optimist')
    .usage 'Configure your xBee.\nUsage: $0',
      'help':
        description:'Show this help message'
        boolean: true
        alias: 'h'
      'debug':
        description: 'Turn debug on'
        boolean: true
        default: false
      'list':
        description: 'List the serial ports attached to your system'
        boolean: true
        alias: 'l'
      'baudrate':
        description: 'Set the baudrate for the serial port'
        default: 9600
        alias: 'b'
      'port':
        description: 'Specify the serial port for your xBee device.'
        alias: 'p'
      'describe':
        description: 'Describe the connected xBee device.'
        alias: 'd'
        boolean: true
      'panId':
        description: 'Set the Pan Id for the xBee device.'
    .check( (argv)->
      if argv.help || (!argv.list && !argv.port)
        return false
      return true
    )
    .argv

async = require 'async'

serialport = require("serialport")
SerialPort = serialport.SerialPort

Xbee = require("./xbee")

if argv.list
  serialport.list (err, ports) ->
    ports.forEach (port) ->
      console.log 'Port: ' + port.comName

describeCommands = require('./xbee-commands')

port = argv.port
if port
  baudrate = argv.baudrate
  serial = new SerialPort port,
    baudrate: baudrate

  serial.on "open", () ->
  
    xbee = new Xbee(serial)
    console.log('Serial Port Open.\n')

    console.log(xbee)

    if argv.panId
      xbee.connect ()->
        xbee.writeCommand 'ID', argv.panId, 'Set Pan Id', () ->
          xbee.writeCommand 'WR', '', 'Save.', () ->
            console.log 'done.'
            process.kill(process.pid, 'SIGINT')

    else if argv.describe
      xbee.connect () ->
        async.forEachSeries describeCommands,
          (command, callback) ->
            xbee.readCommand command.command, command.name, callback
          , (err) ->
            console.log("done.")
            if err
              console.log 'Error! ' + err
            process.kill(process.pid, 'SIGINT')

