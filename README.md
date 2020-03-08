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
1. мониторинг строки  
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
