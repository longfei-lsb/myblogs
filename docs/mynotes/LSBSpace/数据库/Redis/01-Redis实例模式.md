# Redis实例模式

[TOC]

## 主从模式

### 主从模式介绍

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4rg5sea6ij20kc05ddfv.jpg)

**作用**

- 避免单点故障（硬盘故障，导致数据丢失）
- 缓解单点压力（主负责读写，从负责分担读请求）

**目的：**方便做容灾恢复，并做读写分离，分担Master压力

**核心原理**

Redis 提供了复制（replication）功能，可以实现当一台数据库中的数据更新后，自动将更新的数据同步到其他数据库上

**步骤解析**

- 从数据库启动成功后，连接主数据库，发送 SYNC 命令；
- 主数据库接收到 SYNC 命令后，开始执行 BGSAVE 命令生成 RDB 文件并使用缓冲区记录此后执行的所有写命令；
- 主数据库 BGSAVE 执行完后，向所有从数据库发送快照文件，并在发送期间继续记录被执行的写命令；
- 从数据库收到快照文件后丢弃所有旧数据，载入收到的快照；
- 主数据库快照发送完毕后开始向从数据库发送缓冲区中的写命令；
- 从数据库完成对快照的载入，开始接收命令请求，并执行来自主数据库缓冲区的写命令；（**从数据库初始化完成**）
- 主数据库每执行一个写命令就会向从数据库发送相同的写命令，从数据库接收并执行收到的写命令（**从数据库初始化完成后的操作**）
- 出现断开重连后，2.8之后的版本会将断线期间的命令传给重数据库，增量复制。
- 主从刚刚连接的时候，进行全量同步；全同步结束后，进行增量同步。当然，如果有需要，slave 在任何时候都可以发起全量同步。Redis 的策略是，无论如何，首先会尝试进行增量同步，如不成功，要求从机进行全量同步。

**优缺点**

**优点**

- 支持主从复制，读写分离，分载 Master 的读操作压力
- Slave 同样可以接受其它 Slaves 的连接和同步请求，这样可以有效的分载 Master 的同步压力；

**缺点**

- Redis 较难支持在线扩容
- Redis不具备自动容错和恢复功能，需要手动完成（主节点挂掉，将不能完成写操作）
- 多个Slave全量同步可能会导致主节点宕机

### 搭建实战主从

主要有两步

- 准备 master/slave 配置文件
- 先启动 master 再启动 slave，进行验证

**集群规划**

| 节点   | 配置文件       | 端口 |
| ------ | -------------- | ---- |
| master | redis6379.conf | 6379 |
| slave1 | redis6380.conf | 6380 |
| slave1 | redis6381.conf | 6380 |

**配置文件**

```nginx
# redis6379.conf    master
# 包含命令，有点复用的意思
include /opt/redis-5.0.5/redis.conf
pidfile /var/run/redis_6379.pid
port    6379
dbfilename dump6379.rdb
logfile "my-redis-6379.log"

# redis6380.conf    slave1
include /opt/redis-5.0.5/redis.conf
pidfile /var/run/redis_6380.pid
port    6380
dbfilename dump6380.rdb
logfile "my-redis-6380.log"
# 最后一行设置了主节点的 ip 端口
replicaof 127.0.0.1 6379

# redis6381.conf    slave2
include /opt/redis-5.0.5/redis.conf
pidfile /var/run/redis_6381.pid
port    6381
dbfilename dump6381.rdb
logfile "my-redis-6381.log"
# 最后一行设置了主节点的 ip 端口
replicaof 127.0.0.1 6379

## 注意 redis.conf 要调整一项，设置后台运行，对咱们操作比较友好
daemonize yes
```

**启动节点**

启动节点，然后查看节点信息

```shell
# 顺序启动节点
$ redis-server redis6379.conf
$ redis-server redis6380.conf
$ redis-server redis6381.conf

# 进入redis 客户端，开多个窗口查看方便些
$ redis-cli -p 6379
$ info replication
```

**info replication** 命令可以查看连接该数据库的其它库的信息，可看到有两个 slave 连接到 master

## 哨兵模式

### 哨兵模式介绍

哨兵模式是一种特殊的模式，首先 Redis 提供了哨兵的命令，**哨兵是一个独立的进程，作为进程，它会独立运行。其原理是哨兵通过发送命令，等待Redis服务器响应，从而监控运行的多个 Redis 实例**。

![多哨兵](https://tva1.sinaimg.cn/large/e6c9d24ely1h4s2zb59ybj20kc0aegmj.jpg)

**故障切换的过程**

假设主服务器宕机，哨兵1先检测到这个结果，系统并不会马上进行 failover 过程，仅仅是哨兵1主观的认为主服务器不可用，这个现象成为**主观下线**。当后面的哨兵也检测到主服务器不可用，并且数量达到一定值时，那么哨兵之间就会进行一次投票，投票的结果由一个哨兵发起，进行 failover 操作。切换成功后，就会通过发布订阅模式，让各个哨兵把自己监控的从服务器实现切换主机，这个过程称为**客观下线**。这样对于客户端而言，一切都是透明的。

**步骤**

1. 每个Sentinel（哨兵）进程以每秒钟一次向整个集群以及其他Sentinel（哨兵）进程发送一个 PING 命令。
2. PING回复超时，则视为**主观下线**（SDOWN）。超时选项：down-after-milliseconds
3. 当大于等于配置文件指定的值数量的哨兵认为Master节点主观下线，Master就被标记为**客观下线**（ODOWN）
4. 当非Master节点客观下线，每个 Sentinel（哨兵）进程会每 10 秒一次向集群中其他节点发送INFO命令
5. 当Master节点客观下线，每个 Sentinel（哨兵）进程会每 1 秒一次向集群中其他从节点发送INFO命令
6. Master节点对PING 命令返回有效回复，Master观下线状态就会被移除

**优点：**有效的监控整个集群，动态完成故障修复，程序更健壮、可用性更高

**缺点：**缺点Redis较难支持在线扩容

### 搭建实战哨兵

主要有两步：

- 准备主从复制集群，并启动
- 增加哨兵配置，启动验证

**集群规划**

一般来说，哨兵模式的集群是：一主，二从，三哨兵。

**哨兵配置**

哨兵的配置其实跟 redis.conf 有点像，可以看一下自带的 `sentinel.conf`

这里咱们创建三个哨兵文件， **哨兵文件的区别在于启动端口不同**

```nginx
# 文件内容
# sentinel1.conf
port 26379
sentinel monitor mymaster 127.0.0.1 6379 1
# sentinel2.conf
port 26380
sentinel monitor mymaster 127.0.0.1 6379 1
# sentinel3.conf
port 26381
sentinel monitor mymaster 127.0.0.1 6379 1
```

```shell
# 启动哨兵
$ redis-sentinel sentinel1.conf
$ redis-sentinel sentinel2.conf
$ redis-sentinel sentinel3.conf
```

## Cluster 集群模式

### Cluster 集群模式介绍

实现了 Redis 的分布式存储，**也就是说每台 Redis 节点上存储不同的内容**。

![image-20200531184321294](https://tva1.sinaimg.cn/large/e6c9d24ely1h4s3vai8lyj20j208yaar.jpg)

蓝色代表集群节点，客户端可以与任何一个节点相连接，然后就可以访问集群中的任何一个节点。对其进行存取和其他操作。

**集群的数据分片**

采用hash槽的方式

每个节点上有两个东西：插槽（取值范围是：0-16383）、cluster（计算取模）

Redis 集群有16384 个哈希槽

key 通过 CRC16 算法校验后对 16384 取模来决定放置哪个槽

集群的每个节点负责一部分hash

这种结构很容易添加或者删除节点，因为只需要槽移动，然后进行删除（转移节点上的槽位）和添加（分槽到这里）

互相PING的方式进行集群节点监控，内部使用二进制协议优化传输速度和带宽

半数以上节点检测超时，就会让从节点顶上，从节点没有，则该主从模式的集群（但是另外的仍然可以提供服务）就无法提供服务了

**优化：**采用一致性哈希算法(consistent hashing)

**搭建实战集群**

主要有两步

- 配置文件
- 启动验证

### Docker本机搭建集群模式

**首先创建一个网络**

**注意，这里有个坑，避免将网络IP设置为和你的路由器是一样的，不然服务器没办法上网。**

```shell
docker network create redis --subnet 192.168.0.1/16
```

多个服务器时，唯一的区别是需要在每一个服务器上设置host类型的网络

比如：

安装Docker时，它会自动创建三个网络，bridge（创建容器默认连接到此网络）、 none 、host

| 网络模式   | 简介                                                         |
| ---------- | ------------------------------------------------------------ |
| Host       | 容器将不会虚拟出自己的网卡，配置自己的IP等，而是使用宿主机的IP和端口。 |
| Bridge     | 此模式会为每一个容器分配、设置IP等，并将容器连接到一个docker0虚拟网桥，通过docker0网桥以及Iptables nat表配置与宿主机通信。 |
| None       | 该模式关闭了容器的网络功能。                                 |
| Container  | 创建的容器不会创建自己的网卡，配置自己的IP，而是和一个指定的容器共享IP、端口范围。 |
| 自定义网络 | 略                                                           |

网络创建好了后，接着编写一个shell脚本，通过这个脚本，一键生成6个redis的配置

```shell
for port in $(seq 1 6);
do
        mkdir -p /media/soft/redis-node/node-${port}/conf
        touch /media/soft/redis-node/node-${port}/conf/redis.conf
        cat << EOF >/media/soft/redis-node/node-${port}/conf/redis.conf
port 6379
bind 0.0.0.0
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-announce-ip 192.168.0.1${port}
cluster-announce-port 6379
cluster-announce-bus-port 16379
appendonly yes
EOF
done

```

redis的配置创建好了后，我们在编写一个shell脚本，用来生成redis容器

```shell
for port in $(seq 1 6)
do
        docker run -itd -p 637${port}:6379 -p 1637${port}:16379 --name redis-${port} -v /media/soft/redis-node/node-${port}/data:/data -v /media/soft/redis-node/node-${port}/conf/redis.conf:/etc/redis/redis.conf --net redis --ip 192.168.0.1${port} redis redis-server /etc/redis/redis.conf

done
```

接下来开始创建集群，随便进入一个容器中，然后去创建

```shell
# 进入容器内部，如果进入失败，使用/bin/sh尝试
docker exec -it redis-1 /bin/bash
# 创建集群，IP地址根据自己的网络填写，端口默认是6379
redis-cli --cluster create 192.168.0.11:6379 192.168.0.12:6379 192.168.0.13:6379 192.168.0.14:6379 192.168.0.15:6379 192.168.0.16:6379 --cluster-replicas 1
# 回车后会有提示，可以看到我们创建的集群的相关信息，输入 "yes" 确定创建

```

等待一段时间，集群创建完成，紧接着就来测试我创建的集群是否正确

```shell
# 连接集群
redis-cli -c
# 查看集群信息
cluster info 
cluster nodes
```

### k8s本机搭建集群模式

- 有状态服务的ip、服务名和pv是不会变更和销毁的

[创建过程](https://juejin.cn/post/6844903806719754254)	