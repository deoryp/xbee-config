
print = (name, value) ->
  console.log name + (' ' for x in [25..(name.length)]).join('') + ': ' + value

send = (serial, command, callbacks) ->
  serial.write command, (err, results) ->
    if err
      console.log 'err ' + err
      console.log 'results ' + results
      callbacks.error(err)
    serial.once 'data', callbacks.success

class XBee
  constructor: (@serial) ->
  connect: (callback) ->
    serial = @serial
    setTimeout () ->
      send serial, '+++',
        error: callback
        success: (data) ->
          print 'Connected', data
          setTimeout callback, 1100
      , 1100

  readCommand: (command, name, callback) ->
    send @serial, 'AT' + command + '\r\n',
      error: callback
      success: (data) ->
        print name, data
        callback()

  writeCommand: (command, arg, name, callback) ->
    send @serial, 'AT' + command + ' ' + arg + '\r\n',
      error: callback
      success: (data) ->
        print name, data
        callback()


module.exports =  XBee
