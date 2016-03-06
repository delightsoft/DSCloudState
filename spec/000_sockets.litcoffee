CloudState работает используя две библиотеки: socket.io и socket.io-client.

    require './_globals'
    socketIO = require 'socket.io'
    socketIOClient = require 'socket.io-client'
    socketIOMock = require './_socket.io-mock'

Тестировать можно используя реальные библиотеки.

    describe '000 Sockets:', ->

      afterEach ->

        @serverSocket?.close()
        @clientSocket?.close()

Для простого соединения достаточно начать слушать на порту, а другой стороне выполнить connect().

      fit '010', (done) ->

        (@serverSocket = socketIO(3990)).of('/addr').on 'connection', (socket) =>

После создания соединения можно отправлять свои сообщения

          socket.emit 'msg',  arg = [ { name: 'addFrame', args: [ 'frame 1' ] } ], '2nd argument'

Прим.: Будет переданно то значение, которое было в момент вызова

          arg.length = 0

          return

        @clientSocket = socketIOClient('http://localhost:3990/addr')

И получать эти сообщения на другой стороне.

        @clientSocket.on 'msg', (args, secondArg) ->

          expect(args).toEqual  [ { name: 'addFrame', args: [ 'frame 1' ] } ]

          expect(secondArg).toBe '2nd argument'

И если сообщение пришло, то проверка прошла успешно

          done()

          return

Однако, для тестирования сложных сценариев нужно как то имитировать временное пропадание соединения.  А это сделать
на реальных сокетах сложно.  Потому будем использовать socket.io-mock

    describe '000 Sockets (2):', ->

      beforeEach ->
        @socketIOMock = new socketIOMock()

Простой сценарий для socket.io-mock - это создать серверный сокет, подключить к нему клиентский сокет,

      it '010', (done) ->

через указание того же namespace.

        @socketIOMock.of('/testNamespace').on 'connection', (socket) ->

После чего передать сообщение от клиента на сервер,

          socket.on 'request', (req1, req2) ->
            expect(req1).toBe 'req1'
            expect(req2).toBe 'req2'

а в ответ сервер ответит клиенту.

            socket.emit 'response', 'resp1', 'resp2'

            return # on 'request'

После получения ответа, клиент отключится.

          socket.on 'disconnect', ->

Достаточно для первого теста

            done()

            return # on 'disconnect'


        (client = new @socketIOMock.Client).connect '/testNamespace'

Для полноты имитации, события происходят только на следующий tick. И on 'connect' можно объявить после того
как вызвана операции connect.

//        client = new @socketIOMock.Client

        client.on 'connect', ->

          client.emit 'request', 'req1', 'req2'

И on 'response' можно сделать после того как сделан emit

          client.on 'response', (resp1, resp2) ->

            expect(resp1).toBe 'resp1'
            expect(resp2).toBe 'resp2'

            client.close()

            return # on 'response'

          return # on 'connect'

//        client.connect '/testNamespace'
