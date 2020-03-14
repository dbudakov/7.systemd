### Домашнее задание  
Systemd  
Цель: Цели: - Понимать назначение systemd - Уметь создавать unit-файлы - Знать где искать информацию о systemd и его компонентах Результат ДЗ: - Создать разные типы unit-файлов - Использовать шаблоны unit-файлов - Задать разные типы параметров (переменные, ограничения, код завершения) - Переписать SysV скрипт на unit-файл  
Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):  
1. Создать сервис и unit-файлы для этого сервиса:  
- сервис: bash, python или другой скрипт, который мониторит log-файл на наличие ключевого слова;  
- ключевое слово и путь к log-файлу должны браться из /etc/sysconfig/ (.service);  
- сервис должен активироваться раз в 30 секунд (.timer).  
  
2. Дополнить unit-файл сервиса httpd возможностью запустить несколько экземпляров сервиса с разными конфигурационными файлами.  
  
3. Создать unit-файл(ы) для сервиса:  
- сервис: Kafka, Jira или любой другой, у которого код успешного завершения не равен 0 (к примеру, приложение Java или скрипт с exit 143);  
- ограничить сервис по использованию памяти;  
- ограничить сервис ещё по трём ресурсам, которые не были рассмотрены на лекции;  
- реализовать один из вариантов restart и объяснить почему выбран именно этот вариант.  
* реализовать активацию по .path или .socket.  
  
4*. Создать unit-файл(ы):  
- сервис: демо-версия Atlassian Jira;  
- переписать(!) скрипт запуска на unit-файл.  

### Решение
Скрипт лежит [здесь]  
Скрипт останавливается и ждёт ответа после загрузки дистрибутива Jira,
```
We couldn't find fontconfig, which is required to use OpenJDK. Press [y, Enter] to install it.
For more info, see https://confluence.atlassian.com/x/PRCEOQ
```
необходимо прожать "y", далее можно жать "Enter", далее будет вопрос о запуске сервиса
```
Installation of Jira Software 8.7.1 is complete
Start Jira Software 8.7.1 now?
Yes [y, Enter], No [n]
```
на запрос запуска сервиса прожать "n"

1.Проверить мониторинг строки из watchlog
```
journalctl |grep Master
```
2.работу двух httpd сервисов проверить так
``` 
 ss -tnulp | grep httpd
```
3.лимиты jira, а также ограничения по использованию процессора проверить так 
```
for i in Active CGroup Memory Tasks;do systemctl status jira| grep $i;done
systemd-cgtop 
```
### Описание
#### 1. мониторинг строки  
Создаем ряд файлов:  
  /etc/sysconfig/watchlog # окружение юнита
```
# Configuration file for my watchdog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log 
```

  /var/log/watchlog.log # непосредственно файл для мониторинга
```
ALERT
```

  /opt/watchlog.sh # скрипт выполнения 
```
#!/bin/bash
#/opt/watchlog.sh

WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi
```
  /lib/systemd/system/watchlog.service # основной юнит запуска скрипта
```
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```
  /lib/systemd/system/watchlog.timer # для тайминга выполнения юнита
```
#/lib/systemd/system/watchlog.timer

[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```
создаем линки в соответствующей дирректории, для автозапуска юнитов, причём линки нужны и на .timer и на .service, в результате того что таймер настроен на работу только после запуска юнита, если не запустить юнит таймер не запуститься  
```
ln -s /lib/systemd/system/watchlog.service /etc/systemd/system/multi-user.target.wants/
ln -s /lib/systemd/system/watchlog.timer /etc/systemd/system/multi-user.target.wants/
```
По проверки лога всё, можно перезагружать VM логинится и примерно через минуту в журнале с небольшим промежутком будет появлятся соответствующая запись
```
journalctl|tail
--- 
I found word, Master!"
---
```
#### 2. httpd с двойным окружением
Устанавливаем сервис, и копируем файли юнита, но с пометкой для использования шаблона, файл такого вида указывает что после "@" и до "."  используется шаблон  [name]@[template].service  
```
yum install httpd -y
cp /lib/systemd/system/httpd.service /lib/systemd/system/httpd@.service
```
далее правим строку в юните с шаблоном 
```
#/lib/systemd/system/httpd@.service

[Service]
EnvironmentFile=/etc/sysconfig/httpd-%I #добавляем %I для использования подстановки шаблона
```
Далее создаем файлы окружения для каждого из шаблонов  
```
---file 1
# /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf
---
---file 2
# /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf
---
```
далее копируем конфиг httpd сервиса для наших шаблонов заменяя в файле для второго шаблона строки PIDFile и используемого порта
```
cp /etc/httpd/conf/httpd /etc/httpd/conf/{first,second}
vi /etc/httpd/cont/second

###/etc/httpd/cont/second
PidFile /var/run/httpd-second.pid
Listen 8008
###
```
Добавляем сервисы в автозагрузку
```
ln -s /lib/systemd/system/httpd@first.service /etc/systemd/system/multi-user.target.wants/
ln -s /lib/systemd/system/httpd@second.service /etc/systemd/system/multi-user.target.wants/
```
по настройки httpd в двойном окружении всё, можно грузить VM и проверять работу служб
```
 ss -tnulp | grep httpd
```

#### 3. Установка jira(java app), ограничение ресурсов
скачиваем и устанавливаем только клиент jira
```
yum install wget -y
mkdir /opt/src ; cd /opt/src
wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-8.7.1-x64.bin
chmod 755 /opt/src/jira*     
/opt/src/jira*
```
создаем юнит и ограничиваем его по нескольким параметрам, а также ставим параметр рестарта в режиме "always", чтобы служба самостоятельно перезапускалась, при некорректном её выключении, автостарт не сработает только в случае корректной остановки службы через `systemctl stop jira.service`
```
[Unit]
Description=Atlassian Jira                        # описание юнита
After=network.target                              # условия загрузки, после сетевых служб

[Service]
Type=forking                                      # задаем тип форкинг, процесс создающий др. процессы
User=jira                                         # пользователь
PIDFile=/opt/atlassian/jira/work/catalina.pid     # пид файл
ExecStart=/opt/atlassian/jira/bin/start-jira.sh   # скрипт запуска приложения
ExecStop=/opt/atlassian/jira/bin/stop-jira.sh     # скрипт остановки приложения
MemoryLimit=140M                                  # ограничение на использование памяти
TasksMax=5                                        # максимальноe кол-во активных задач 5
Slice=user-1000.slice                             # назначение слайса, необходимо писать наименование конечного слайса без ветки
Restart=always                                    # авторестарт

[Install]
WantedBy=multi-user.target                        # вхождение данного серсвиса в группу таргетов
```
дополнительно установим ограничение на использование процессора, данное ограничение останется активным и после перезагрузки VM
```  
systemctl set-property jira.service CPUQuota=40%   
```
далее создаем линк для организации автозагрузки юнита
```
ln -s /lib/systemd/system/jira.service /etc/systemd/system/multi-user.target.wants/
```
По ограничению и рестарту сервисов всё, можно грузить и проверять работу служб.
