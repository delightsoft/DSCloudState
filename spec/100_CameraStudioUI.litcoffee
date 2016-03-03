Управление камера через веб-интерфейс студии
==============================

Одна из интересных задач для CloudState, в рамках концепции AngularTV - это реализовать следующую схему:

Есть два типа серверов: сервер-камера, где происходит сбор данных и сервер-студия, куда передаются данные и откуда они
передаются на пользовательский интерфейс (web-панель или административный).  При этом сервер-студия имеет публичный
сетевой адрес, а сервер-камера может находиться в закрытой подсети.  Камеры могут подключаться к студии в любой момент.
Одновременно может быть подключено несколько камер.

Оригинал данных камеры находится на сервере-камера, потому он должна подключиться (connect) к серверу-студии, которые
должен слушать (listen) новые камеры. При подключении новой камеры, на сервере-студии создается клон новой камеры,
который добавляется в список камер в студии

Оригинал списка камер находится на сервере-студии.  Он доступен для клонирования на веб интерфейс (angular-приложение).
В списке камер видно название камер и адрес по которому можно на неё подписать на студии.  По факту это мы клонируем на
UI состояние клона камеры на сервере-студии.

Важно, что при вызове команды на клоне камеры в UI, команда выполнялись на сервере-камере, на котором находится оригинал
камеры.

    # TODO: Одна камера может цепляться к нескольким студиям
    # TODO: Любой listen и connect можно отключить через вызов обратной функции

    require './_globals'
    CloudState = require '../src/CloudState'

    fdescribe '100 Camera Studio UI:', ->

      class Camera extends CloudState

        constructor: ->
          super()
          @started = false
          @frames = []
          return

        @setters

          start: (v) ->
            @started = v
            return

          addFrame: (frame) ->
            @frames.push frame
            @frames.unshift if @frames.length > 10
            return

        start: -> @_start true; return

        stop: -> @_start false; return

        @makeOriginAndClone()

Для тестов, готовим два сокета, соединенных между собой

      afterEach (done) ->

        require('./_pairSockets').cleanUp @, done

      beforeEach (done) ->

        count = 2

        end = =>

          done() if --count == 0

          return

        require('./_pairSockets') @, end
        .add 'socketA', 'socketB'
        .add 'socketC', 'socketD'
        .add 'socketE', 'socketF'

        @origin = new Camera.Origin

        @clone = new Camera.Clone

        @clone2 = new Camera.Clone

        end()

Просто подключение Clone к Origin

      it '010', (done) ->

        require('./_specSteps') @, done, true

Создаем оригинал

        .step -> # 1

          @origin._addFrame 'frame 1'

Clone-состояние подключаетс к Origin

        .step # 2

          action: ->

            @origin.__addClone @socketA

            @clone.__setOrigin @socketB

Клон получает полное состояни от Origin

          expect: (done) ->

            unwatch = @clone.__watch '_wholeState', ->

              expect(@_ready).toBeTruthy()
              expect(@_connected).toBeTruthy()

              expect(@started).toBeFalsy()
              expect(@frames).toEqual ['frame 1']

              unwatch(); done()

Когда изменения вносятся в Origin

        .step # 3

          action: ->

            @origin._addFrame 'frame 2'

На Origin получаем сообщение об изменении состоянии

          expect: (done1, done2) ->

            unwatchOrigin = @origin.__watch 'addFrame', (setter, data) ->

              expect(setter).toBe 'addFrame'
              expect(data).toBe 'frame 2'

              unwatchOrigin(); done1()

Такое же сообщение мы видим на Clone

            unwatchClone = @clone.__watch 'addFrame', (setter, data) ->

              expect(setter).toBe 'addFrame'
              expect(data).toBe 'frame 2'

              unwatchClone(); done2()

Если мы выполняем команду на Clone

        .step # 4

          action: ->

            @clone.start()

Команда выполняет на Origin

          expect: (done1, done2, done3) ->

            require('./_catchMethod') @origin, 'start', done1

И приводит к соотвествующим изменениям на Origin и Clone

            unwatchOrigin = @origin.__watch 'start', (setter, data) ->

              expect(setter).toBe 'start'
              expect(data).toBe true

              unwatchOrigin(); done2()

            unwatchClone = @clone.__watch 'start', (setter, data) ->

              expect(setter).toBe 'start'
              expect(data).toBe true

              unwatchClone(); done3()

        .step # 5

Теперь подключаем clone к clone'у

          action: ->

            @clone.__addClone @socketC

            @clone2.__setOrigin @socketD

Состояние с clone копируется на clone2

          expect: (done) ->

            unwatch = @clone2.__watch '_wholeState', ->

              expect(@_ready).toBeTruthy()
              expect(@_connected).toBeTruthy()

              expect(@started).toBeTruthy()
              expect(@frames).toEqual ['frame 1', 'frame 2']

              unwatch(); done()

        .step # 6

          action: ->

            @clone2.stop()

Команда выполняет на Origin

          expect: (done1, done2, done3, done4) ->

            require('./_catchMethod') @origin, 'stop', done1

И приводит к соотвествующим изменениям на Origin и Clone

            unwatchOrigin = @origin.__watch 'start', (setter, data) ->

              expect(setter).toBe 'start'
              expect(data).toBe false

              unwatchOrigin(); done2()

            unwatchClone = @clone.__watch 'start', (setter, data) ->

              expect(setter).toBe 'start'
              expect(data).toBe false

              unwatchClone(); done3()

            unwatchClone2 = @clone2.__watch 'start', (setter, data) ->

              expect(setter).toBe 'start'
              expect(data).toBe false

              unwatchClone2(); done4()

Если отключить связь межд @clone и @origin

        .step # 7

          action: ->

            @socketA.disconnect()

то @clone и @clone2 перейдут в состояние `__connected == false`

          expect: (done1, done2) ->

            unwatchClone = @clone.__watch '_connected', ->

              expect(@_connected).toBeFalsy()

              unwatchClone(); done1()

            unwatchClone2 = @clone2.__watch '_connected', ->

              expect(@_connected).toBeFalsy()

              unwatchClone2(); done2()

        # TODO: Добавить изменение состояния пока камера отключена

        .step # 8

          action: ->

            # TODO: Нужно ли поддерживать режим, когда мы делаем setOrigin раньше чем на другом конце происходит addClone

            @origin.__addClone @socketE

            @clone.__setOrigin @socketF

          expect: (done1, done2) ->

            unwatchClone = @clone.__watch '_connected', ->

              expect(@_connected).toBeTruthy()

              unwatchClone(); done1()

            unwatchClone2 = @clone2.__watch '_connected', ->

              expect(@_connected).toBeTruthy()

              unwatchClone2(); done2()

