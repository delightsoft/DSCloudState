Это helper для однаразового перехвата вызова метода

    module.exports = (object, method, done, checkFunc) ->
      
      throw new Error "Invalid argument 'object'" unless typeof object == 'object' && object != null
      throw new Error "Invalid argument 'method'" unless typeof method == 'string' && method.length > 0
      throw new Error "Invalid argument 'done'" unless typeof done == 'function'
      throw new Error "Invalid argument 'checkFunc'" unless typeof checkFunc == 'function' || typeof checkFunc == 'undefined'

      throw new Error "Object has no method: #{method}" unless typeof object[method] == 'function'

      [originalFn, object[method]] = [object[method], ->
        checkFunc.apply @, arguments if checkFunc
        originalFn.apply @, arguments
        object[method] = originalFn
        done()]