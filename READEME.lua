 portainer文档 https://portainer.readthedocs.io/en/stable/
 docker run -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v /home/docker/portainer:/data --name portainer --restart=always portainer/portainer
 administrator mengya fhqydidxil1zql




 mysql镜像
 1.运行“docker pull mysql”获取mysql镜像
 docker pull mysql
 2.在后台启动mysql容器(--name指定了容器的名称，方便之后进入容器的命令行，MYSQL_ROOT_PASSWORD=emc123123指定了mysql的root密码，-d表示在后台运行)
 docker run --name=mengya -it -p 3306:3306 -e MYSQL_ROOT_PASSWORD=mengyagamepassword -d mysql
 3.进入容器bash并进入mysql命令行：
[root@localhost ~]# docker exec -it mysql bash
root@eb3dbfb0958f:/# mysql -uroot -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 3
Server version: 5.7.20 MySQL Community Server (GPL)

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> 


redis 镜像
docker pull redis
docker run -p 6379:6379 -d redis:latest redis-server

docker exec -ti da20f redis-cli   -- <==> <docker exec -ti d0b86 redis-cli -h localhost -p 6379>
127.0.0.1:6379> select 0
OK
127.0.0.1:6379> set mengya start
OK
127.0.0.1:6379> get mengya
"start"
127.0.0.1:6379> exit





CONFLUENCE 镜像
docker run -d --name confluence -p 8090:8090 --link postgresdb:db --user root:root cptactionhank/atlassian-confluence:latest


