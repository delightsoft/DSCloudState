# TODO: Add state object name, so I could distinguish them

module.exports = class CloudState

  constructor: (->

    # TODO: Make it right

# only .Origin and .Clone has '__connect' method
#    unless typeof @.__connect != 'undefined'
#      throw new Error 'It\'s wrong to create a new instance of remote state directly.  Use <className>.Origin or <className>.Clone.(connect | listen)'

    @_ver = 0

    @$$blocked = 0
    @$$updates = []
    @$$watchers = {}
    @$$originSocket = null
    @$$clonesSockets = []

    @_ready = false
    @_connected = false

    return)

  # send updates from Origin
  sendUpdates = ->
    if @$$updates.length > 0
      @_ver++
      updates = @$$updates
      for socket in @$$clonesSockets when socket.connected && socket.ds_connected
        socket.emit 'update', updates

    watchers = @$$watchers
    for update in @$$updates
      if watchers.hasOwnProperty (name = update.name)
        args = update.args.slice()
        args.unshift(name)
        for watcher in watchers[name]
          watcher.apply @, args

      updates.length = 0
    return

  __addUpdate: (update) ->
    @$$updates.push update
    sendUpdates.call @ if @$$blocked == 0
    return

  __block: (func) -> # 4 original
    @$$blocked++
    func()
    sendUpdates.call @ if --@$$blocked == 0
    return

  __watch: (setterName, listener) ->
    list = if @$$watchers.hasOwnProperty setterName then @$$watchers[setterName] else @$$watchers[setterName] = []
    list.push listener
    return ->
      for lst, i in list when lst == listener
        list.splice i, 1
        break
      return

  __setters:

    set: (key, value) ->
      @[key] = value
      return

    _connected: (@_connected) ->
      return

    _wholeState: (state) ->

      # Note: @__connected value comes with state
      # Note: We cannot use R.merge, since it creates a new copy of object
      @[k] = v for k, v of JSON.parse state

      return

  @setters = ((methods) ->
    @::__setters = R.merge @__super__.constructor::__setters, methods
    return)

  findSetters = (proto) ->
    loop
      if proto.hasOwnProperty '__setters'
        return proto.__setters
      unless (superClass = proto.__super__) && (ctor = superClass.constructor) && (proto = ctor::)
        return null
    return

  __addClone: (socket) ->

    return false if socket.disconnected

    socket.ds_connected = false

    @$$clonesSockets.push socket

    socket.on 'getState', socket.ds_getState = (knownVersion) =>

      socket.ds_connected = true

      return if typeof knownVersion == 'number' && @_ver == knownVersion

      oneCloneUpdate = [name: '_wholeState', args: [JSON.stringify(@, ((k, v) -> if k.charAt(0) == '$' then undefined else v))]]

      socket.emit 'update', oneCloneUpdate

      return

    socket.on 'disconnect', =>
      for clone, i in @$$clonesSockets when clone == socket
        socket.removeListener 'disconnect', socket.ds_getState
        delete socket.ds_getState
        @$$clonesSockets.splice i, 1
        break

    return true

  @makeOriginAndClone = (->

    setters = findSetters @::

    @Origin = class Origin extends @

      constructor: ->
        super()
        @_ready = true
        @_connected = true
        return

      __addClone: (socket) ->

        return unless super socket

        socket.on 'method', (cmd) =>
          @[cmd.name].apply @, cmd.args
          return

        return # __addClone:

    # add _<setter name> methods to Origin.prototype
    if setters
      for name, func of setters
        do (name, func) =>
          @Origin::["_#{name}"] = (->
            func.apply @, args = Array::slice.call arguments
            @__addUpdate name: name, args: args
            return)

    @Clone = class Clone extends @

      parent = @

      _rootScope = null

      __addClone: (socket) ->

        return unless super socket

        # Bypass 'method' to Origin
        socket.on 'method', (cmd) =>

          if @$$originSocket?.connected
            @$$originSocket.emit 'method', cmd

          # TODO: Add error if socket is closed

          return

      __setConnected: (value) ->
        return unless @_connected != value
        @_connected = value
        @__onUpdate [name: '_connected', args: [value]]
        return

      # Process incoming 'update' package
      __onUpdate: (updates) ->

        # forward updates to linked clones
        for socket in @$$clonesSockets when socket.connected
          socket.emit 'update', updates

        @_ver++

        for update in updates
          setters[update.name].apply @, update.args

        watchers = @$$watchers

        for update in updates
          if watchers.hasOwnProperty (name = update.name)
            (args = update.args).unshift name
            for watcher in watchers[name]
              watcher.apply @, args

        if (_rootScope ?= (GLOBAL || window)._rootScope) && !_rootScope.$$phase
          _rootScope.$digest()

        return

      __onConnect: ->

        (prevSocket.removeListener 'connnect', @__onConnectFunc; @__onConnectFunc = null) if @__onConnectFunc

        if @_ready
          @$$originSocket.emit 'getState', @__ver
          @__setConnected true
        else
          @$$originSocket.emit 'getState'

        return

      __onDisconnect: ->

        @__setOrigin null

        return

      __setOrigin: (socket) ->

        if (prevSocket = @$$originSocket)
          (prevSocket.removeListener 'connnect', @__onConnectFunc; @__onConnectFunc = null) if @__onConnectFunc
          prevSocket.removeListener 'update', @__onUpdateFunc; @__onUpdateFunc = null
          prevSocket.removeListener 'disconnect', @__onDisconnectFunc; @__onDisconnectFunc = null

        if !socket || socket.disconnected
          @$$originSocket = null
          @__setConnected false
          return

        @$$originSocket = socket

        if socket.connected
          @__onConnect()
        else
          socked.on 'connect', @__onConnectFunc = => @__onConnect.apply @, arguments

        socket.on 'update', @__onUpdateFunc = => @__onUpdate.apply @, arguments

        socket.on 'disconnect', @__onDisconnectFunc = => @__onDisconnect.apply @, arguments

        return

    # make proxy methods for every method from base-class prototype
    proto = @::
    loop
      for name, func of proto
        continue if name == 'constructor'
        if typeof func == 'function' && name.charAt(0) != '_'
          do (name, func) =>
            @Clone::[name] = (->
              @$$originSocket?.emit 'method', {name, args: Array::slice.call arguments}
              return)
      break if (proto = proto.__proto__) == CloudState::

    return)
