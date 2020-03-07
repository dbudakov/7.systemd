инициализация настроек /etc/systemd/system.conf  
  правка :
    
для правки вывода cgtop [здесь](https://habr.com/ru/company/redhatrussia/blog/424367/)  
 а также правка 

установка jira [здесь](https://gist.github.com/ryanvin/5ab0278b5ce3253742b0ba5d918c5fc8)  
unit для atlassian [здесь](https://confluence.atlassian.com/jirakb/run-jira-as-a-systemd-service-on-linux-979411854.html)  


limits  
```
systemctl set-property jira.service CPUQuota=40%   
```
Memory можно ограничить либо строкой в unit либо строкой в скрипте запуска
```
[Service]
MemoryLimit=140M
```
or
```
#!/bin/bash
...
echo 140000000 > /sys/fs/cgroup/memory/system.slice/jira.service/memory.limit_in_bytes
...
```
CPU 
```
systemctl set-property jira.service CPUQuota=20%
```
TASKS
```
[Service]
TasksMax=2
```
