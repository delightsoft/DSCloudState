Тестирование сетевых соединений, требует чтобы сперва был написан код, который обрабатывает событие, и только
потом можно выполнить проверяемую операцию.  Однако, для спецификаций нужно писать что делаем, и только потом что
получаем.

Этот класс решает эту проблему, разделя шаги спецификации на часть - что хотим сделать (action), и часть - что
ожидаем (expect).  И эти части выполняются в обратной последовательности - сперва expect, а потом action.

Так как expect часто предполагает ожидание поступления сигнала, мы можем передать несколько callback-методов, и
метод expect будет считаться выполненым, если все callback-методы были вызваны.

    process = require 'process'

    class SpecSteps

Для отладки спецификации, полезно включать debug в true - тогда видно на каком шаге завис (не вызвал done) тест.

      constructor: (@context, @done, @debug) ->

        @steps = []

Так как все шаги определяются за один вызов функции, то логично запустить процесс выполнения на следующем тике.

        process.nextTick => @_executeStep 1

Добавляем шаги в тест, через цепочку вызовов метода step.

      step: (arg) ->

        if typeof arg == 'object'
          throw new Error 'Invalid \'arg\'' unless arg != null
          for k, v of arg
            throw new Error "Unexpected 'arg.#{k}' in #{arg}" unless k == 'action' || k == 'expect'
            throw new Error "Invalid 'arg.#{k}': #{v}" unless typeof v == 'function'
          throw new Error "Missing 'arg.action'" unless arg.hasOwnProperty 'action'
          throw new Error "'arg.expect' must have at least one 'done' parameter" unless !arg.hasOwnProperty('expect') || arg.expect.length > 0
        else if typeof arg == 'function'
          arg = action: arg
        else throw new Error "Invalid arg: #{arg}"

        @steps.push arg

        @ # step:

      _executeStep: (stepIndex) ->

Если мы прошли последний шаг, то вызываем метод done, данный нам из вне - чтобы завершить jasmine-тест.

        if stepIndex > @steps.length
          @done()
          return

        console.log 'step: ', stepIndex if @debug

        if (step = @steps[stepIndex - 1]).hasOwnProperty 'expect'

          doneCount = step.expect.length

          doneFunc = =>
            @_executeStep stepIndex + 1 if --doneCount == 0
            return

Вызываем метод execute, с необходимым количество параметров.  Каждый параметр это функция doneFunc, которая после того
как её вызовут doneCount, считает что шаг закончен и можно переходить к следующему шагу.

          step.expect.apply @context, (doneFunc for i in [0...doneCount])
          step.action.call @context

Если нет части expect, то просто выполняем action, и переходим к следующему шагу

        # TODO: Подумать, не надо ли передавать в action также done-метод

        else

          step.action.call @context
          @_executeStep stepIndex + 1

    module.exports = (context, done, debug) ->

      throw new Error "Invalid argument 'context': #{conext}" unless typeof context == 'object' && context != null
      throw new Error "Invalid argument 'done': #{done}" unless typeof done == 'function'

      # TODO: Добвать methodSpy в conext, чтоб легко перехватывать вызовы методов.

      new SpecSteps context, done, debug
