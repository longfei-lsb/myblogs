# MySQL主从复制

[TOC]

## 概念

**MySQL 主从复制是指数据可以从一个MySQL数据库服务器主节点复制到一个或多个从节点**。

默认采用**异步复制**方式，从节点可以复制主数据库中的所有数据库或者特定的数据库

## 主要用途

- 读写分离提高并发
- 实施备份**方便的故障切换**
- 高可用
- 扩展、降低单机磁盘I/O访问的频率，提高单个机器的I/O性能

## 主从形式

### 一主多从

> 提高系统的读性能，不仅实现HA（High Availability Cluster），读写分离提高并发能力

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y4n9jkicj206s07ct8m.jpg)

### 多主一丛

> 备份

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y4n6njdrj2060058q2s.jpg)

### 双主复制

> 提高读写压力，增大了复制压力

双主复制，也就是互做主从复制，每个**master**（主）**既是master，又是另外一台服务器的**slave****（从）**。这样任何一方所做的变更，都会通过复制应用到另外一方的数据库中。

### 级联复制

> 不仅可以降低主节点复制压力，并且对数据一致性没有负面影响

**级联复制下从节点也要开启binary log（bin-log）功能。**

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y4n3ut99j208e02y744.jpg)

## 主从复制的原理

> 涉及到三个线程，一个运行在**主节点（log dump thread）**，其余两个(**I/O thread, SQL thread**)运行在从节点

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y4n116t0j20hs06zaaa.jpg)

### 主节点log dump 线程

> 用于**发送和读取bin-log**的内容

**当从节点连接主节点时，主节点会为自己的每一个从节点创建一个log dump线程**

读取时**加锁**，读取完成，在发送给从节点之前，释放锁

### 从节点 I/O 线程

> **通知更新**主节点binlog，并存储**接收到**的数据到本地**relay-log（中继日志）中**

当从节点上执行`start slave`命令之后，从节点会创建一个I/O线程用来连接主节点，请求主库中更新的bin-log

I/O线程接收到主节点的blog dump进程发来的更新之后，保存在本地**relay-log（中继日志）**中

### 从节点 SQL 线程

> 读取relay-log中的内容，解析成具体的操作并执行，最终保证主从数据的一致性

主节点会为每一个当前连接的从节点建一个**log dump 进程**，而每一个从节点都有自己的**I/O进程**和**SQL进程**

**目的：**将拉取更新和执行分成独立的任务。这样在执行同步数据任务时，不会降低读操作性能。

**例如：**如果从节点没有运行，不影响I/O同步到本地，等从服务器运行后就可以完成数据同步了

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y4mumchoj20hs0733yl.jpg)

### 复制的基本过程

- Slave上执行sart slave命令，从节点上I/O 进程连接主节点，请求从指定日志文件的指定位置（或者从最开始的日志）之后的日志内容；
- Master接收到请求之后，通过负责复制的I/O进程（log dump 线程）根据请求信息读取指定日志指定位置之后的日志信息，返回给从节点信息中除了日志所包含的信息之外，还包括本次返回的信息的bin-log file 的以及bin-log position（bin-log中的下一个指定更新位置）；
- Slave的I/O进程接收到之后，将接收到的日志内容更新到本机的relay-log（中继日志）的文件（Mysql-relay-bin.xxx）的最末端，并将读取到的binary log（bin-log）文件名和位置保存到**master-info** **文件**中，以便在下一次读取的时候能够清楚的告诉Master“我需要从某个bin-log 的哪个位置开始往后的日志内容，请发给我”；
- Slave 的 SQL线程检测到relay-log 中新增加了内容后，会将relay-log的内容解析成在主节点上实际执行过SQL语句，然后在本数据库中按照解析出来的顺序执行，并在**relay-log.info**中记录当前应用中继日志的文件名和位置点。

## 主从复制模式

### 异步模式（mysql async-mode）

> 主节点不会主动推送bin-log到从节点，主库在执行完客户端提交的事务后会立即将结果返给给客户端，并不关心从库是否已经接收并处理

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y53ccbyhj20hs07u0t2.jpg)

**优势：**不影响客户端整体性能，对网络延迟没有要求

**劣势：**但如果主节点上已经提交的事务可能并没有传到从节点上，此时，强行将从提升为主，可能导致新主节点上的**数据不完整**。

### 半同步模式(mysql semi-sync)

> 介于异步复制和全同步复制之间，半同步模式不是mysql内置的，从mysql 5.5开始集成，需要master 和slave 安装插件开启半同步模式。

主库在执行完客户端提交的事务后不是立刻返回给客户端，而是等待至少一个从库接收到并写到relay-log中才返回成功信息给客户端（但并不能保证从节点将此事务执行更新到db中）。

否则需要等待直到超时时间然后切换成异步模式再提交

**优势：**增加了一定的数据安全性，比全同步模式延迟要低，这个延迟至少是一个TCP/IP往返的时间

**劣势：**最好在低延时的网络中使用，多出了一个通知（至少一次网络IO），损耗到了客户端的性能

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4y5aadkuzj20hs08b0t9.jpg)

### 全同步模式

指当主库执行完一个事务，然后所有的从库都复制了该事务并成功执行完才返回成功信息给客户端。因为需要等待所有从库执行完该事务才能返回成功信息，所以全同步复制的客户端性能必然会收到严重的影响。

### 异步模式，全同步模式，半同步模式的对比

![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4y5c0gomlj20j50dwq3n.jpg)

### GTID 复制模式

传统复制模式中，找点相对来说比较麻烦，MySQL 5.6里面不用再找bin-log和pos点，只需要知道主节点的ip，端口，以及账号密码就行，因为复制是自动的，MySQL会通过内部机制**GTID**自动找点同步。

**GTID (global transaction identifier)** 即全局事务ID, 保证了在每个在主库上提交的事务在集群中有一个唯一的ID.

#### GTID 复制原理

在原来基于日志的复制中, 从库需要告知主库要从哪个偏移量进行增量同步, 如果指定错误会造成数据的遗漏, 从而造成数据的不一致.

基于GTID的复制中, 从库会告知主库已经执行的事务的GTID的值, 然后主库会将所有未执行的事务的GTID的列表返回给从库. 并且可以保证同一个事务只在指定的从库执行一次（**通过全局的事务ID确定从库要执行的事务的方式代替了以前需要用bin-log和pos点确定从库要执行的事务的方式**）

格式为：GTID=server_uuid:transaction_id

- server_uuid是在数据库启动过程中自动生成，每台机器的server-uuid不一样，uuid存放在数据目录的auto.conf文件中
- transaction_id就是事务提交时系统顺序分配的一个不会重复的序列号

主节点更新数据时，会在事务前产生GTID，一起记录到bin-log日志中。从节点的I/O线程将变更的bin-log，写入到本地的relay-log中。SQL线程从relay-log中获取GTID，然后对比本地bin-log是否有记录（所以MySQL从节点必须要开启binary-log）。如果有记录，说明该GTID的事务已经执行，从节点会忽略。如果没有记录，从节点就会从relay-log中执行该GTID的事务，并记录到binlog。在解析过程中会判断是否有主键，如果没有就用二级索引，如果有就用全部扫描。

**好处：**

1. GTID使用master_auto_position=1代替了binlog和position号的主从复制搭建方式，相比binlog和position方式更容易搭建主从复制。
2. GTID方便实现主从之间的failover（主从切换），不用一步一步的去查找position和binlog文件。

**局限性：**

1. 不能使用create table table_name select * from table_name模式的语句
2. 在一个事务中既包含事务表的操作又包含非事务表
3. 不支持CREATE TEMPORARY TABLE or DROP TEMPORARY TABLE语句操作
4. 使用GTID复制从库跳过错误时，不支持sql_slave_skip_counter参数的语法

### 多线程复制

> 多线程复制（基于库）

**基于库的多线程复制原理**

与单线程不同的是，增加了一个Work Thread（工作线程）

**SQL Thread：** 在Slave上,读取 binlog，并分配 binlog 给work thread (分配原则,判断并行执行的事务是否拥有相同的数据库)

**Work Thread（工作线程）：**执行binlog ,可以有多个

**多线程复制**

mysql5.7 基于BLGC的多线程复制原理,同时处于prepare阶段的事务不会有冲突。

在mysql5.7 的binlog中新增了两个字段：

- **last_committd：**标注哪些事务可以并行执行
- **sequence_number：**标注事物的顺序

last_committed:事务提交编号,同一组内的事务,编号相同,可以并行执行

sequence_number:binglog写入顺序,用户确保master的binlog顺序和slave的binlog顺序的一致

## 主从复制方式

**MySQL 主从复制有三种方式：

- 基于**SQL**语句的复制**（statement-based replication，SBR）**
- 基于**行**的复制**（row-based replication，RBR)**
- **混合模式**复制**（mixed-based replication,MBR)**

对应的bin-log文件的格式也有三种：**STATEMENT**、**ROW**、 **MIXED**

#### Statement-base Replication (SBR)

就是记录sql语句在bin-log中，Mysql 5.1.4 及之前的版本都是使用的这种复制格式。优点是只需要记录会修改数据的sql语句到bin-log中，减少了bin-log日质量，节约I/O，提高性能。缺点是在某些情况下，会导致主从节点中数据不一致（比如sleep(),now()等）。

#### Row-based Relication(RBR)

mysql master将SQL语句分解为基于Row更改的语句并记录在bin-log中，也就是只记录哪条数据被修改了，修改成什么样。优点是不会出现某些特定情况下的存储过程、或者函数、或者trigger的调用或者触发无法被正确复制的问题。缺点是会产生大量的日志，尤其是修改table的时候会让日志暴增,同时增加bin-log同步时间。也不能通过bin-log解析获取执行过的sql语句，只能看到发生的data变更。

#### Mixed-format Replication(MBR)

MySQL NDB cluster 7.3 和7.4 使用的MBR。是以上两种模式的混合，对于一般的复制使用STATEMENT模式保存到bin-log，对于STATEMENT模式无法复制的操作则使用ROW模式来保存，MySQL会根据执行的SQL语句选择日志保存方式。