#!/bin/bash
#OUEST1

CONF(){
op0="/etc/sysconfig/watchlog"
cat>$op0<<EOF
# /etc/sysconfig/watchlog
# Configuration file for my watchdog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD=ALERT
LOG=/var/log/watchlog.log
EOF
	}          

LOG(){
op1="/var/log/watchlog.log"
cat>$op1<<EOF
#/var/log/watchlog.log
ALERT
EOF
	}

SH(){
op2="/opt/watchlog.sh"
cat>$op2<<EOF
#!/bin/bash
#/opt/watchlog.sh
WORD=\$1
LOG=\$2
DATE=\`date\`
if grep \$WORD \$LOG &> /dev/null
then
	logger "\$DATE: I found word, Master!"
else
	exit 0
fi
EOF
chmod +x /opt/watchlog.sh
	}

SRV_WATCH(){
op4="/lib/systemd/system/watchlog.service"
cat>$op4<<EOF
#/lib/systemd/system/watchlog.service
		
[Unit]
Description=My watchlog service
				
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF
	}

TIMER_WATCH(){
op5="/lib/systemd/system/watchlog.timer"
cat>$op5<<EOF
#/lib/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
	}
        
	
LN_WATCH(){
src6="/lib/systemd/system/watchlog.service"
src7="/lib/systemd/system/watchlog.timer"  
op6="/etc/systemd/system/multi-user.target.wants/"
ln -s \$src{6,7} $op6
	}       
	
QUEST1(){
CONF
LOG
SH
SRV_WATCH
TIMER_WATCH
LN_WATCH
telinit 6
	}   

QUEST1

#QUEST2
	PRECONF2(){
		src8=httpd
        	yum install $src8 -y
	}

SRV2(){
op9="/lib/systemd/system/httpd@.service"
cat>$op9<<EOF
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)
		
[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true
		
[Install]
WantedBy=multi-user.target
EOF
	}


CONF2(){
op10=/etc/sysconfig/httpd-first
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

	CONF_HTTPD(){
		src12=/etc/httpd/conf/httpd.conf 
		op12=/etc/httpd/conf/first.conf
		op13=/etc/httpd/conf/second.conf

		cp $src12 $op12
		cp $src12 $op13
	sed -i '
	s/Listen 80/Listen 8008/' $op13
	sed -i '
	s/# least PidFile./PidFile \/var\/run\/httpd-second.pid/' $op13

	}	
	
	LN_HTTPD(){
		src14="/lib/systemd/system/httpd@first.service"
		src15="/lib/systemd/system/httpd@second.service"
		op14="/etc/systemd/system/multi-user.target.wants/"
		ln -s $src{14,15} $op14
	}
	QUEST2(){
		PRECONF2
		SRV2
		CONF2
		CONF_HTTPD
		LN_HTTPD
		telinit 6
	}
QUEST2

#QUEST3
	INST_WGET(){
	 src16=wget
	 src17="https://www.atlassian.com/software/jira/downloads/binary/"
	 op17="/root/atlassian-jira-software-8.7.1-x64.bin"
	 yum install $src16  -y
	 wget $src17 -O $op17
	 chmod 755 $op17
	 $op1
	}
         
	SRV_JIRA(){ 
	op18="/lib/systemd/system/jira.service"
	cat >$op18<<EOF
		[Unit]
		Description=Atlassian Jira
		After=network.target
		
		[Service]
		Type=forking
		User=jira
		PIDFile=/opt/atlassian/jira/work/catalina.pid
		ExecStart=/opt/atlassian/jira/bin/start-jira.sh
		ExecStop=/opt/atlassian/jira/bin/stop-jira.sh
		MemoryLimit=140M
		TasksMax=5
		Slice=user-1000.slice
		Restart=always
		
		[Install]
		WantedBy=multi-user.target
EOF
	}
          
	ln_service(){
	 src19="/lib/systemd/system/jira.service"
	 op19="/etc/systemd/system/multi-user.target.wants/"
	 ln -s $src19 $op19
	}
        
	QUEST3(){
		INST_WGET
		SRV_JIRA
		ln_service
		systemctl set-property \
			jira.service \
			CPUQuota=40%
	} 	
QUEST3
