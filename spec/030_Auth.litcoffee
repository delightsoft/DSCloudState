Авторизация
==============================
Для работы в Сети нужен механизм авторизации подключений.

Для авторизации мы передаем функцию в метод listen, которая получает параметры события auth.

Если авторизация не прошла, функция возвращает undefined или false.

Иначе, то что возвращает функция считается информацией об авторизации, и сохраняется в свойстве сокета $ds_auth



