# Имитатор (mock) socket.io и socket.io-client нужен для отработки логики remote-state.  К сожаление варианты имитаторов
# найденные в сети были или слишком простыми или слишком уж сложным - потом показалось разумным сделать имитатор
# именно тех методов и режимов работы которые будут использоватьчя в remote-state.
#
# Для использования

process = require 'process'

EventEmitter = (require 'events').EventEmitter

emit = EventEmitter::emit

class Namespace extends EventEmitter

  constructor: (url) ->
    @__url = url

class ServerSocket extends EventEmitter

  constructor: ->
    @__status = 'good'
    @__pair = null

    @connected = false
    @disconnected = false

    return

  __setStatus: (status) ->
    @__pair.__status = @__status = status
    return

  __fire: ->
    emit.apply @, arguments
    return

  emit: (event, data) ->
    throw new Error 'Socket is closed' unless (pair = @__pair)
    args = (R.clone arg for arg in arguments) # it's deep copy of arguments
    process.nextTick ->
      emit.apply pair, args
    return # emit:

  disconnect: ->

    return unless @__pair

    @connected = false
    @disconnected = true
    (pair = @__pair).__pair = null
    pair.connected = false
    pair.disconnected = true
    @__pair = null
    process.nextTick =>
      @__fire 'disconnect'
      pair.__fire 'disconnect'
    return # close:

class ClientSocket extends ServerSocket

  connect: (url) ->
    for ns in @__mock.namespaces when ns.__url == url
      ss = new ServerSocket()
      ss.__mock = @__mock
      ss.__pair = @
      ss.connected = true
      @__pair = ss
      process.nextTick =>
        ns.emit 'connection', ss
        @connected = true
        @__fire 'connect'
      @ # connect:

    @__mock.clientAwaits.push url: url, socket: @

    @ # connect:

module.exports =

  class SocketIOMock

    constructor: ->

      @namespaces = []
      @clientAwaits = []

      self = @

      @Client = class InnerClientSocket extends ClientSocket
          constructor: ->
            super()
            @__mock = self
            return # constructor:

      return # constructor:

    of: (url) ->

      @namespaces.push (namespace = new Namespace url)

      for cs, i in @clientAwaits by -1 when cs.url == url
        @clientAwaits.splice i, 1
        cs.socket.connect url

      namespace # return