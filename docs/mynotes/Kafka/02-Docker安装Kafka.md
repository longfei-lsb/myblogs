# 02-Docker安装Kafka

[TOC]

```shell
# 拉取镜像
# zookeeper
docker pull wurstmeister/zookeeper
# kafka
docker pull wurstmeister/kafka
# kafka manager：kafka可视化管理工具
docker pull sheepkiller/kafka-manager

# 启动zookeeper
docker run -d --name zookeeper -p 2181:2181 -it wurstmeister/zookeeper

# 启动kafka
docker run -d --name kafka \
-p 9092:9092 \
-e KAFKA_BROKER_ID=0 \
-e KAFKA_HEAP_OPTS=-Xmx500M \
-e ALLOW_PLAINTEXT_LISTENER=yes \
-e KAFKA_ZOOKEEPER_CONNECT=81.70.52.213:2181 \ # 这里要换成自己zookeeper的ip和端口
-e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://81.70.52.213:9092 \ # 这里要换成自己的ip
-e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 wurstmeister/kafka
# 完整命令
docker run -d --name kafka -p 9092:9092 -e KAFKA_BROKER_ID=0 -e KAFKA_HEAP_OPTS=-Xmx500M -e ALLOW_PLAINTEXT_LISTENER=yes -e KAFKA_ZOOKEEPER_CONNECT=81.70.52.213:2181 -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://81.70.52.213:9092 -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 -v /etc/localtime:/etc/localtime wurstmeister/kafka

# 启动kafka manager
docker run -d --name kfk-manager \
--restart always \
-p 9000:9000 \
-e ZK_HOSTS=81.70.52.213:2181 \ # 这里要换成自己zookeeper的ip和端口
sheepkiller/kafka-manager
```

访问：http://81.70.52.213:9000/

![image-20220929152150149](https://i.imgur.com/UpmLerN.png)

**扩展：**

kafka有一个更加友好的工具：[kafka-map](https://github.com/dushixiang/kafka-map/blob/master/README-zh_CN.md)

但是它依赖于java 1，若要安装，需要升级linux的java 版本，那么我们如何在已经有java 8 的情况下，完成与java 11 并存，并随意切换呢？

**下面是解决方案：**

```shell
# 安装java 11
yum install java-11-openjdk* -y

# 切换java配置
sudo alternatives --config java
------------------
# 内容：

There are 2 programs which provide 'java'.

  Selection    Command
-----------------------------------------------
*+ 1           java-1.8.0-openjdk.x86_64 (/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.312.b07-2.el8_5.x86_64/jre/bin/java)
   2           java-11-openjdk.x86_64 (/usr/lib/jvm/java-11-openjdk-11.0.13.0.8-4.el8_5.x86_64/bin/java)

Enter to keep the current selection[+], or type selection number: # 输入对应序号，按下回车键即可

# 查看java版本
java -version
------------------
# 内容：
openjdk version "11.0.13" 2021-10-19 LTS
OpenJDK Runtime Environment 18.9 (build 11.0.13+8-LTS)
OpenJDK 64-Bit Server VM 18.9 (build 11.0.13+8-LTS, mixed mode, sharing)
# ok！
```

docker 安装kafka-map

```
docker run -d \
    -p 10001:8080 \
    -v /opt/kafka-map/data:/usr/local/kafka-map/data \
    -e DEFAULT_USERNAME=admin \
    -e DEFAULT_PASSWORD=admin \
    --name kafka-map \
    --restart always dushixiang/kafka-map:latest
```

