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
Скрипт лежит [здесь](https://github.com/dbudakov/7.systemd/blob/master/homework/script.sh)   
После запуска VM, необходимо запустить `/vagrant/script.sh`, cценарий настройки останавливается и ждёт ответа после загрузки дистрибутива Jira:
```
We couldn't find fontconfig, which is required to use OpenJDK. Press [y, Enter] to install it.
For more info, see https://confluence.atlassian.com/x/PRCEOQ
```
необходимо прожать "y", далее можно жать "Enter", после чего будет вопрос о запуске сервиса:
```
Installation of Jira Software 8.7.1 is complete
Start Jira Software 8.7.1 now?
Yes [y, Enter], No [n]
```
на запрос запуска сервиса прожать "n"
Mетод рестарта jira.service (Restart=always) выбран из соображения постоянной активности сервиса , в случае его прерывания или получения сигналов TERM или KILL он самостоятельно поднимается

#### Проверка настроек VM  
1. Проверить мониторинг строки
```
journalctl |tail| grep Master
```
2. Проверить работу двух httpd сервисов
```  
 ss -tnulp | grep httpd
```
3. Проверить лимиты jira.service, а также ограничения по использованию процессора проверить так:  
```
for i in Active CGroup Memory Tasks;do systemctl status jira| grep $i;done
systemd-cgtop 
```
#### Описание скрипта
```
#!/bin/bash
#OUEST1

CONF(){                                                   # создаем файл /sysconfig/watchlog, он же
op0="/etc/sysconfig/watchlog"                             # файл настроек для скрипта watchlog.sh
cat>$op0<<EOF
# /etc/sysconfig/watchlog
# Configuration file for my watchdog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD=ALERT
LOG=/var/log/watchlog.log
EOF
	}          

LOG(){                                                    # создаем сам лог в котором будет мониторится  
op1="/var/log/watchlog.log"                               # наличие слова "ALERT"
cat>$op1<<EOF
#/var/log/watchlog.log
ALERT
EOF
	}

SH(){                                                     #  создаем скрипт /opt/watchlog
op2="/opt/watchlog.sh"
cat>$op2<<EOF
#!/bin/bash
#/opt/watchlog.sh
WORD=\$1
LOG=\$2
DATE=\`date\`
if grep \$WORD \$LOG &> /dev/null                         # оператор условия настроен на grep
then                                                      # если код возврата 0, то пишется
	logger "\$DATE: I found word, Master!"            # строка в лог, иначе нет
else
	exit 0
fi
EOF
chmod +x /opt/watchlog.sh
	}

SRV_WATCH(){                                              # unit.sevice для watchlog.sh
op4="/lib/systemd/system/watchlog.service"                  
cat>$op4<<EOF
#/lib/systemd/system/watchlog.service
		
[Unit]
Description=My watchlog service                     
				
[Service]
Type=oneshot                                              # тип сервиса, один запуск
EnvironmentFile=/etc/sysconfig/watchlog                   # файл окружения
ExecStart=/opt/watchlog.sh \$WORD \$LOG                   # скрипт старта с передачей скрипту параметров
EOF
	}

TIMER_WATCH(){                                            # юнит для таймера  watchlog
op5="/lib/systemd/system/watchlog.timer"                  
cat>$op5<<EOF                             
#/lib/systemd/system/watchlog.timer                       
[Unit]  
Description=Run watchlog script every 30 second           

[Timer]
# Run every 30 second
OnUnitActiveSec=30                                        # параметр означает запуск по событию после активации
Unit=watchlog.service                                     # сервиса с аналогичным именем через 30 сек 
                                                         
[Install]
WantedBy=multi-user.target                                # соответствие таргету загрузки  
EOF
	}
        
	
LN_WATCH(){
src6="/lib/systemd/system/watchlog.service"
src7="/lib/systemd/system/watchlog.timer"  
op6="/etc/systemd/system/multi-user.target.wants/"
ln -s $src6 $op6                                          # создание символических ссылок на наши юниты
ln -s $src7 $op6                                          # аналогично команде systemctl enable [unit]
	}       
	
QUEST1(){                                                 # вызов функций в определённом порядке
CONF
LOG
SH
SRV_WATCH
TIMER_WATCH
LN_WATCH
	}   

QUEST1                                                    # запуск функции
  
#QUEST2
	PRECONF2(){                                       # предустрановка VM
		src8=httpd
        	yum install $src8 -y
	}
                      
SRV2(){                                                   # создание юнита для сервиса httpd с использованием                 
op9="/lib/systemd/system/httpd@.service"                  # шаблона
cat>$op9<<EOF
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)
		
[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I                   # непосредственно обозначение подстановки шаблона
ExecStart=/usr/sbin/httpd \$OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd \$OPTIONS -k graceful
ExecStop=/bin/kill -WINCH \${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true
		
[Install]
WantedBy=multi-user.target
EOF
	}


CONF2(){                                                # создание файлов конфигурации ОКРУЖЕНИЯ для 
op10=/etc/sysconfig/httpd-first                         # двух httpd.service
op11=/etc/sysconfig/httpd-second
cat>$op10<<EOF
# /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf
EOF
cat>$op11<<EOF
# /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf
EOF
	}

	CONF_HTTPD(){                              # копирование основного файла конфигурации httpd
		src12=/etc/httpd/conf/httpd.conf   # для наших сервисов с правкой файла для httpd-second.service
		op12=/etc/httpd/conf/first.conf         
		op13=/etc/httpd/conf/second.conf

		cp $src12 $op12
		cp $src12 $op13
	sed -i '                                   # поиск строки с параметром порта и замена 80 на 8008
	s/Listen 80/Listen 8008/' $op13                       
	sed -i '                                   # настрой PidFile'a для второго сервиса
	s/# least PidFile./PidFile \/var\/run\/httpd-second.pid/' $op13   

	}	
	
	LN_HTTPD(){
		src14="/lib/systemd/system/httpd@first.service"
		src15="/lib/systemd/system/httpd@second.service"
		op14="/etc/systemd/system/multi-user.target.wants/"
		ln -s $src{14,15} $op14            # создание симлинков для автостарта служб   
	}
	QUEST2(){                                  # запуск функций в определённом порядке
		PRECONF2
		SRV2
		CONF2
		CONF_HTTPD
		LN_HTTPD
	}
QUEST2                                             # вызов основной функции


#QUEST3
	INST_WGET(){                               # предустановка для настройки jira.service
	 src16=wget
	 src17="https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-8.7.1-x64.bin"
	 op17=/root/atlassian-jira-software-8.7.1-x64.bin
	 yum install $src16  -y
	 wget $src17 -O $op17
	 chmod 755 $op17
	 $op17
	}
         
SRV_JIRA(){                                        # создание юнита для jira.service
op18="/lib/systemd/system/jira.service"
cat >$op18<<EOF
[Unit]
Description=Atlassian Jira
After=network.target                               # требование для загрузки
	
[Service]
Type=forking                                       # тип service'а 
User=jira
PIDFile=/opt/atlassian/jira/work/catalina.pid           
ExecStart=/opt/atlassian/jira/bin/start-jira.sh           
ExecStop=/opt/atlassian/jira/bin/stop-jira.sh           
SuccessExitStatus=143				   # обработка 143 кода возврата, что нормально для java приложения
MemoryLimit=140M                                   # лимит памяти для юнита
TasksMax=20                                        # лимит тасков для юнита
Slice=user-1000.slice                              # установка slice для юнита
Restart=always                                     # рестарт юнита, в случае некорректного завершения его работы
			                           # отличной от systemctl stop [service]
						   
[Install]
WantedBy=multi-user.target
EOF
	}
          
	ln_service(){
		src19=/lib/systemd/system/jira.service
		op19=/etc/systemd/system/multi-user.target.wants/
		ln -s $src19 $op19                 # создание симлинков для автостарта jira.service
	}
        
	QUEST3(){                                  # вызов функций в определённом порядке
		INST_WGET
		SRV_JIRA
		ln_service
		systemctl start jira		
		systemctl set-property \          # ограничение использования юнитом процессора
			jira.service \
			CPUQuota=40%  
	} 	
QUEST3                                            # запуск функции 
telinit 6                                         # рестарт системы

```
### Дополнительно
По умолчанию точность таймера в systemd установлена в 1 минуту. Это значение можно переопределить. `man systemd.timer`  
Использование юнитов, 6'й абзац и далее по тексту поиском "template" [здесь](https://wiki.archlinux.org/index.php/Systemd_(%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9)#%D0%98%D1%81%D0%BF%D0%BE%D0%BB%D1%8C%D0%B7%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D0%B5_%D1%8E%D0%BD%D0%B8%D1%82%D0%BE%D0%B2)       
Борьба за ресурсы, часть 1: Основы Cgroups [здесь](https://habr.com/ru/company/redhatrussia/blog/423051/)  
