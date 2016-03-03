Для тестирования сетевых соединений, необходимо иметь пары объектов socket.io соединеных между собой.  Пар может быть
несколько штук.  Важно, чтоб после окончания теста сокеты были корректно закрыты.

Если true - тестируем на реальных объектах socket.io.  При этом тесты на reconnect не сработают.

    useRealSockets = false

    port = 3390

    socketIO = require 'socket.io'
    socketIOClient = require 'socket.io-client'
    socketIOMock = require './_socket.io-mock'

    class PairSockets

        constructor: (@context, @done) ->

          @count = 0

          return

Добавляем пару сокетов, с именами name1 и name2 в контексте теста.

        add: (name1, name2) ->

          @count += 2

Создаем пару socket.io сокетов.  Используя порты начиная с порта startPort.

          if useRealSockets

            serverSocket = @context.__serverSocket ?= socketIO(port)

            serverSocket.of("/#{name1}").on 'connection', (socket1) =>

              @context[name1] = socket1

              (sockets = (@context.__sockets ?= [])).push socket1

              sockets.push socket2

              @done() if --@count == 0

              return

            (@context[name2] = socket2 = socketIOClient.connect("http://localhost:#{port}/#{name1}")).on 'connect', =>

              @done() if --@count == 0

              return

Создаем пару mock-сокетов.  Они работают без создания реального сетевого соединения.

          else

            socketIOMock = @context.socketIOMock ?= new socketIOMock()

            socketIOMock.of("/#{name1}").on 'connection', (socket1) =>

              @context[name1] = socket1

              (sockets = (@context.__sockets ?= [])).push socket1

              sockets.push socket2

              @done() if --@count == 0

              return

            ((@context[name2] = socket2 = new socketIOMock.Client).connect "/#{name1}").on 'connect', =>

              @done() if --@count == 0

              return

          @ # add:

Возвращаем метод, который возвращает новый instance класса PairSocket

        module.exports = func =  (context, done) ->

          new PairSockets context, done

Добавляем статический метод cleanUp - который корректно закрывает сокеты запомненые в переменно
__sockets в контекте теста.

        func.cleanUp = (context, done) =>

          count = 0

          end = ->

            if --count == 0

              serverSocket.close() if (serverSocket = context.__serverSocket)
                            
              done()

            return # end =

          for socket, i in (sockets = context.__sockets) by 2 when socket.connected

            count += 2

            socket.on 'disconnect', end

            sockets[i + 1].on 'disconnect', end

            socket.disconnect()

          return
