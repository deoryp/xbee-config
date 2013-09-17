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


describeCommands = [
  {
    name:'Channel',
    command: 'CH',
    catagory: "Networking",
    description: "Set/Read the channel number used for transmitting and receiving data between RF modules.",
    range: "0x0B - 0x1A",
    default: "0x0C"
  },{
    name:'Pan Id',
    command:'ID',
    catagory: "Networking",
    description: "Set/Read the PAN (Personal Area Network) ID. Use 0xFFFF to broadcast messages to all PANs.",
    range: "0 - 0xFFFF",
    default: "0x3332"
  },{
    command: "DH",
    name:"Destination Address High",
    catagory: "Networking",
    description: "Set/Read the upper 32 bits of the 64-bit destination address. When combined with DL, it defines the destination address used for transmission. To transmit using a 16-bit address, set DH parameter to zero and DL less than 0xFFFF. 0x000000000000FFFF is the broadcast address for the PAN.",
    range: "0 - 0xFFFFFFFF",
    default: "0"
  },{
    command: "DL",
    name: "Destination Address Low",
    catagory: "Networking",
    description:"Set/Read the lower 32 bits of the 64-bit destination address. When combined with DH, DL defines the destination address used for transmission. To transmit using a 16-bit address, set DH parameter to zero and DL less than 0xFFFF. 0x000000000000FFFF is the broadcast address for the PAN.",
    range: "0 - 0xFFFFFFFF",
    default: "0"
  },{
    command: "MY",
    name: "16-bit Source Address",
    catagory: "Networking",
    description: "Set/Read the RF module 16-bit source address. Set MY =0xFFFF to disable reception of packets with 16-bit addresses. 64-bit source address(serial number) and broadcast address (0x000000000000FFFF) is always enabled.",
    range: "0 - 0xFFFF",
    default: "0"
  },{
    command: "SH",
    name: "Serial Number High",
    catagory: "Networking",
    description: "Read high 32 bits of the RF module's unique IEEE 64-bit address. 64-bit source address is always enabled.",
    range: "0 - 0xFFFFFFFF [read-only]",
    default: "Factory-set"
  },{
    command: "SL",
    name: "Serial Number Low",
    catagory: "Networking",
    description: "Read low 32 bits of the RF module's unique IEEE 64-bit address. 64-bit source address is always enabled.",
    range: "0 - 0xFFFFFFFF [read-only]",
    default: "Factory-set"
  },{
    command: "RR",
    name: "XBee Retries",
    catagory: "Networking",
    description: "Set/Read the maximum number of retries the module will execute in addition to the 3 retries provided by the 802.15.4 MAC. For each XBee retry, the 802.15.4 MAC can execute up to 3 retries.",
    range: "0 - 6",
    default: "0"
  },{
    command: "RN",
    name: "Random Delay Slots",
    catagory: "Networking",
    description: "Set/Read the minimum value of the back-off exponent in the CSMA-CA algorithm that is used for collision avoidance. If RN = 0, collision avoidance is disabled during the first iteration of the algorithm (802.15.4 - macMinBE).",
    range: "0 - 3 [exponent]",
    default: "0"
  },{
    command: "MM",
    name: "MAC Mode",
    catagory: "Networking",
    description: "Set/Read MAC Mode value. MAC Mode enables/disables the use of a Digi header in the 802.15.4 RF packet. When Modes 0 or 3 are enabled(MM=0,3), duplicate packet detection is enabled as well as certain AT commands.",
    range: "0 = Digi Mode, 1 = 802.15.4 (no ACKs), 2 = 802.15.4 (with ACKs), 3 = Digi Mode (no ACKs)",
    default: "0"
  },{
    command: "NI",
    name: "Node Identifier",
    catagory: "Networking",
    description: "Stores a string identifier. The register only accepts printable ASCII data. A string can not start with a space. Carriage return ends command. Command will automatically end when maximum bytes for the string have been entered. This string is returned as part of the ND (Node Discover) command. This identifier is also used with the DN (Destination Node) command.",
    range: "20-character ASCII string",
    default: "-"
  },{
    command: "NT",
    name: "Node Discover Time",
    catagory: "Networking",
    description: "Set/Read the amount of time a node will wait for responses from other nodes when using the ND (Node Discover) command.",
    range: "0x01 - 0xFC [x 100 ms]",
    default: "0x19"
  },{
    command: "CE",
    name: "Coordinator Enable",
    catagory: "Networking",
    description: "Set/Read the coordinator setting. A value of 0 makes it an End Device but a value of 1 makes it a Coordinator.",
    range: "0 = End Device, 1 = Coordinator", "0" ],
  },{
    command: "SC",
    name: "Scan Channels",
    catagory: "Networking",
    description: "Set/Read list of channels to scan for all Active and Energy Scans as a bitfield. This affects scans initiated in command mode (AS, ED) and during End Device Association and Coordinator startup",
    range: "0 - 0xFFFF [bitfield](bits 0, 14, 15 not allowed on the XBee-PRO)",
    default: "0x1FFE (all XBee-PRO Channels)"
  },{
    command: "A1",
    name: "End Device Association",
    catagory: "Networking",
    description: "Set/Read End Device association options. bit 0 - ReassignPanID (0 - Will only associate with Coordinator operating on PAN ID that matches module ID / 1 - May associate with Coordinator operating on any PAN ID), bit 1 - ReassignChannel(0 - Will only associate with Coordinator operating on matching CH Channel setting / 1 - May associate with Coordinator operating on any Channel), bit 2 - AutoAssociate (0 - Device will not attempt Association / 1 - Device attempts Association until success Note: This bit is used only for Non-Beacon systems. End Devices in Beacon-enabled system must always associate to a Coordinator), bit 3 - PollCoordOnPinWake (0 - Pin Wake will not poll the Coordinator for indirect (pending) data / 1 - Pin Wake will send Poll Request to Coordinator to extract any pending data), bits 4 - 7 are reserved.",
    range: "0 - 0x0F [bitfield]",
    default: "0"
  }
]

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
            if err
              console.log 'Error! ' + err
            console.log('done')


print = (name, value) ->
  console.log name + (' ' for x in [15..(name.length)]).join('') + ': ' + value

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

readChannel = (serial, callback) ->
  read serial, 'ATCH\r\n',
    error: callback
    success: (data) ->
      print 'Channel', data
      callback()

readPanId = (serial, callback) ->
  read serial, 'ATID\r\n',
    error: callback
    success: (data) ->
      print 'Pan Id', data
      callback()

readCommand = (serial, command, name, callback) ->
  read serial, 'AT' + command + '\r\n',
    error: callback
    success: (data) ->
      print name, data
      callback()




