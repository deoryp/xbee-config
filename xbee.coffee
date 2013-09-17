argv = require('optimist')
    .usage 'Configure your xBee.\nUsage: $0',
      'help':
        description:'Show this help message'
        boolean: true
        alias: 'h'
      'list':
        description: 'List the serial ports attached to your system'
        boolean: true
        alias: 'l'
      'port':
        description: 'Specify the serial port for your xBee device.'
        alias: 'p'
      'describe':
        description: 'Describe the connected xBee device.'
        alias: 'd'
        boolean: true
    .check( (argv)->
      if argv.help || (!argv.list && !argv.port)
        return false
      return true
    )
    .argv

async = require 'async'

serialport = require("serialport")
SerialPort = serialport.SerialPort

if argv.list
  serialport.list (err, ports) ->
    ports.forEach (port) ->
      console.log 'Port: ' + port.comName

describeCommands = require('./xbee-commands')

port = argv.port
if port
  baudrate = 19200
  serial = new SerialPort port,
    baudrate: baudrate

  serial.on "open", () ->
    console.log('Serial Port Open.\n')

    if argv.describe
      connect serial, () ->
        async.forEachSeries describeCommands,
          (command, callback) ->
            readCommand(serial, command.command, command.name, callback)
          , (err) ->
            console.log("done.")
            if err
              console.log 'Error! ' + err
            process.kill(process.pid, 'SIGINT')

print = (name, value) ->
  console.log name + (' ' for x in [25..(name.length)]).join('') + ': ' + value

read = (serial, command, callbacks) ->
  serial.write command, (err, results) ->
    if err
      console.log 'err ' + err
      console.log 'results ' + results
      callbacks.error(err)
    serial.once 'data', callbacks.success

connect = (serial, callback) ->
  read serial, '+++',
    error: callback
    success: (data) ->
      print 'Connected', data
      setTimeout callback, 1100

readCommand = (serial, command, name, callback) ->
  read serial, 'AT' + command + '\r\n',
    error: callback
    success: (data) ->
      print name, data
      callback()




