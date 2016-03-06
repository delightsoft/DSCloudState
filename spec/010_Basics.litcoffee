Базовые свойства CloudState
==============================

Идея
------------------------------

CloudState - позволяет организовать синхронизацию состояний между несколькими узлами (сервера, браузерами), используя
в качестве канала библиотеку socket.io.

Для передачи состояния, на одном из компьютеров создается один главный (origin) объект состояния, и к нему
подключаются clone-объекты.  Оrigin является самостоятельным объектом, и может работать без clone.  Clone является
подчиненым объектом, и не может менять своё состояние без подключение к origin объекту.

Все изменения состояния origin передаются на clone-объекты, через вызов setter-методов - их имен начинаются с подчерка.

Все команды полученные clone-объектом из jscript-кода, передаются на origin для исполнения.

Для кода использующего CloudState объекты, практически не видна разница работает ли он с Origin или Clone.

    require './_globals'
    socketIO = require 'socket.io'
    socketIOClient = require 'socket.io-client'
    CloudState = require '../src/CloudState'

    serverSocket = clientSocket = null

    describe '010 Basics:', ->

      afterEach ->
        @serverSocket.close() if @serverSocket
        @clientSocket.close() if @clientSocket

Классы Origin и Clone
------------------------------

При наследовании от класса CloudState

      it '010', ->

        class X extends CloudState

в самом *конце описания* нового класса, необходимо вызвать статический метод makeOriginAndClone()

          @makeOriginAndClone()

этот метод создаст два производных класса, привязанных к новому классу.  Класс <имя класс>.Origin

          expect(X.Origin).toBeDefined()

и класс <имя класс>.Clone.

Эти классы должны быть использованы для создания объектов.

          expect(X.Clone).toBeDefined()

Методы
------------------------------

Структура данных и методы в классе наследнике CloudState определяются, так же, и для любого класса

      it '020', ->

        class X extends CloudState

          constructor: ->
            super()
            @field1 = ''
            return

          method1: ->
            @field1 = 'a value'
            return

и не забываем вызвать makeOriginAndClone()

          @makeOriginAndClone()
        
НЕ ПРАВИЛЬНО! Создавать объекты напряму из класса        
        
        expect(-> x = new X(); return).toThrow(new Error 'It\'s wrong to create a new instance of remote state directly.  Use <className>.Origin or <className>.Clone.(connect | listen)')
      
Через операцию new можно создавать объекты только подкласса Origin
      
        x = new X.Origin()
        expect(x.field1).toBe ''
        x.method1()
        expect(x.field1).toBe 'a value'

Именование свойств и методов
------------------------------

CloudState оринетирован на работу с AngularJS.  Плюс не желательно чтоб методы CloudState путались с методами классов,
которые реализуют remote state для конкретных задач. Поэтому выполняется следующее соглашение:

      # TODO: Показать как работает digest при обновлениях

      it '030', ->

        class X extends CloudState
          @setters
            setV: (v) -> @v = v; return
          action: -> return
          @makeOriginAndClone()

методы классов (статические) CloudState, Origin и Clone - просто методы

          expect(CloudState.setters).toBeDefined()
          expect(CloudState.makeOriginAndClone).toBeDefined()
          expect(X.Clone.connect).toBeDefined()
          expect(X.Clone.listen).toBeDefined()

внутрение переменные называются с двумя $ в начале, чтоб angular игнорировал их при выводе объекта состояния целиком

          x = new X.Origin()
          expect(x.$$blocked).toBeDefined()

общие методы CloudState, начинаются с двух подчерков

          expect(x.__connect).toBeDefined()

методы изменения состояний, начинаются с подчерка

          expect(x._setV).toBeDefined()

методы объекта - без изменений

          expect(x.action).toBeDefined()

Наследование классов состояния
------------------------------

Можно наследоваться от класса, которые унаследован от CloudState

      it '040', ->
  
        class X extends CloudState

          constructor: ->
            @field1 = ''
            return

          method1: ->
            @field1 = 'a value'
            return

          @makeOriginAndClone()

        class Y extends X

          constructor: ->
            super()
            @field2 = ''
            return

          method2: ->
            @field2 = 'a value'
            return

          @makeOriginAndClone()

        y = new Y.Origin()
        expect(y.field1).toBe ''
        expect(y.field2).toBe ''
        y.method1()
        y.method2()
        expect(y.field1).toBe 'a value'
        expect(y.field2).toBe 'a value'

        # TODO: Block direct class instantiation

НЕ ПРАВИЛЬНО! Создавать классы Clone напрямую.  Их надо создавать через методы listen

      it '050', (done) ->

        class X extends CloudState

          @makeOriginAndClone()

        x = new X.Origin()

сперва создает X.Origin объект, который слушает на порту

        x.__listen (@serverSocket = socketIO(3990)), '/origin'

потом подключаем к X.Clone объект

        X.Clone.connect (@clientSocket = socketIOClient.connect('http://localhost:3990/origin')), (err, clone) ->

          if err then done.fail(err); return

          expect(clone).toBeDefined()
          expect(clone).not.toBeNull()

          done()
          return

или connect к Origin объекту

      it '060', (done) ->

        class X extends CloudState

          @makeOriginAndClone()

сперва воздаем X.Clone, который слушает на порту когда появится X.Origin

        X.Clone.listen (@serverSocket = socketIO(3990)), '/clone', (err, clone) ->

          if err then done.fail(err); return

          expect(clone).toBeDefined()
          expect(clone).not.toBeNull()

          done()
          return

потом создаем X.Origin, который подключается к X.Clone

        x = new X.Origin()
        x.__connect (@clientSocket = socketIOClient.connect('http://localhost:3990/clone'))
