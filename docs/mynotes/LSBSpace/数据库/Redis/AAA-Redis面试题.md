# Redis面试题

[TOC]

## **<font size = '4' color = 'pink'>什么是Redis</font>**

是基于内存且支持持久化操作的高性能key-value 数据库，具备以下是那个特征：

- 多数据类型
- 持久化机制
- 支持主从复制

## **<font size = '4' color = 'pink'>Redis优缺点</font>**

**优点：**

- 基于内存，性能好
- 支持持久化
- 支持事务，Redis的所有操作都是原子性的，同时Redis还支持对几个操作合并后的原子性执行。
- 数据结构丰富
- 支持主从复制，主机会自动将数据同步到从机，可以进行读写分离。

**缺点：**

- **不支持在线扩容**
- **不具备自动容错**，故障需要手动修复
- **基于内存限制**
- **主机宕机数据可能会丢失**，宕机前有部分数据未能及时同步到从机，切换IP后还会引入数据不一致的问题，降低了系统的可用性。

## **<font size = '4' color = 'pink'>Redis是单线程的吗？</font>**

Redis 网络请求模块使用了一个线程，其他模块仍然用的多线程

### **<font size = '4' color = 'pink'>Redis 为什么设计成单线程的？</font>**

- 基于内存，很快，不冗余过多的与系统内核交互，避免了不必要的上下文切换和竞争条件
- IO多路复用，避免了IO 代价

### **<font size = '4' color = 'pink'>Redis 是单线程的，如何提高多核 CPU 的利用率？</font>**

一致性hash算法进行分片，一个服务器多个实例

## **<font size = '4' color = 'pink'>Redis 6 中的多线程是如何实现的?</font>**

https://zhuanlan.zhihu.com/p/525576536

## **<font size = '4' color = 'pink'>熟悉Redis的哪些客户端</font>**

- **Jedis：**Jedis 多个线程使用一个连接的时候线程不安全
- **Luttece：**Lettuce 则完全克服了其线程不安全的缺点
- **Redission：**提供了分布式和可扩展的 Java 数据结构

## **<font size = '4' color = 'pink'>什么是 Redis 事务？</font>**

可以一次性执行多条命令，本质上是一组命令的集合。一个事务中的所有命令都会序列化，然后按顺序地串行化执行，而不会被插入其他命令。

Redis的事务相关命令有：

（1）**DISCARD：**取消事务，放弃执行事务块中的所有命令

（2）**EXEC：**执行事务块中的命令

（3）**MULTI：**标记一个事务的开始

（4）**UNWATCH：**取消WATCH命令对所有 key 的监视

（5）WATCH key [key...]：监视一个（或多个）key，如果在事务之前执行这个（或者这些）key被其他命令所改动，那么事务将会被打断。

（6）不支持回滚，如果事务中有错误的操作，无法回滚到处理前的状态，需要开发者处理。

（7）在执行完当前事务内所有指令前，不会同时执行其他客户端的请求。

## **<font size = '4' color = 'pink'>Redis有哪些使用场景？</font>**

- **缓存数据**
- **排行榜：**Redis提供的有序集合数据类构能实现各种复杂的排行榜应用。
- **计数器：**保证数据实时效，每次浏览都得给+1，并发量高时如果每次都请求数据库操作无疑是种挑战和压力。
- **分布式会话：**当应用增多相对复杂的系统中，一般都会搭建以Redis等内存数据库为中心的session服务，session不再由容器管理，而是由session服务及内存数据库管理
- **分布式锁：**全局ID、减库存、秒杀等场景
- **社交网络：**点赞、踩、关注/被关注、共同好友等是社交网站的基本功能
- **最新列表：**LPUSH可以在列表头部插入一个内容ID作为关键字，LTRIM可用来限制列表的数量，这样列表永远为N个ID，无需查询最新的列表，直接根据ID去到对应的内容页即可。

## **<font size = '4' color = 'pink'>Redis 和 Memcached 的区别有哪些？</font>**

- 都是内存数据库，但Memcache 还可用于缓存图片、视频
- Memcache 仅支持key-value结构的数据类型
- Memcache 挂掉后，数据没了，不支持持久化
- Memcache 的单个value最大 1m，Redis 的单个value最大 512m
- Memcached 网络IO模型是多线程，Redis是IO多路复用

**<font size = '4' color = 'pink'>请说说 Redis 的线程模型？</font>**

Redis 内部使用文件事件处理器 file event handler，这个文件事件处理器是单线程的，所以Redis 才叫做单线程的模型

文件事件处理器的结构包含 4 个部分：

- 多个 socket。
- IO 多路复用程序。
- 文件事件分派器。
- 事件处理器（连接应答处理器、命令请求处理器、命令回复处理器）。

## **<font size = '4' color = 'pink'>Redis分布式锁</font>**

- **set nx px：**设置key-value的形式，防止过期时间达到后，锁被其他线程释放掉
- **使用Lua脚本：**保证命令的原子性
- **Redisson框架：**定时狗的方式延长业务有效期时常
- **多机实现的分布式锁Redlock+Redisson：**在设置的时间内，若超过一半节点加锁成功，则算加锁成功；如果获取锁失败，解锁！

## **<font size = '4' color = 'pink'>Redis实例模式</font>**

- **主从模式：**主从复制，读写分离，分担压力。缺点：手动解决故障，无法做到自动监控
- **哨兵模式：**动态监控故障修复，可用性更高。缺点：不支持横向扩展
- **集群模式：**支持横向扩展，节点之间自定义协议进行PING-PANG形式监控，采用hash槽的方式

### **<font size = '4' color = 'pink'>为什么Redis哨兵集群只有2个节点无法正常工作</font>**

哨兵集群必须部署2个以上节点。

如果两个哨兵实例，即两个Redis实例，一主一从的模式。

则Redis的配置quorum=1，表示一个哨兵认为master宕机即可认为master已宕机。

但是如果是机器1宕机了，那哨兵1和master都宕机了，虽然哨兵2知道master宕机了，但是这个时候，需要

majority，也就是大多数哨兵都是运行的，2个哨兵的majority就是2（2的majority=2，3的majority=2，5的

majority=3，4的majority=2），2个哨兵都运行着，就可以允许执行故障转移。

但此时哨兵1没了就只有1个哨兵了了，此时就没有majority来允许执行故障转移，所以故障转移不会执行。

### **<font size = '4' color = 'pink'>Redis cluster节点间通信是什么机制？</font>**

Redis cluster节点间采取gossip协议进行通信，所有节点都持有一份元数据

节点元数据变更时，会不断交换通信保持集群的完整性

主要交换故障信息、节点的增加和移除、hash slot信息等。

**优点：**更新请求会陆陆续续，打到所有节点上去更新，有一定的延时，降低了压力

**缺点：**元数据更新有延时，可能导致集群的一些操作会有一些滞后

## **<font size = '4' color = 'pink'>Redis淘汰策略</font>**

![1.png](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r2uwrbvhj21cp0kymz5.jpg)

- **noeviction：**不淘汰，不提供服务，直接返回错误
- **volatile-random：**在有过期的时间键值对儿里，随机淘汰
- **volatile-ttl：**在有过期的时间键值对儿里，越早过期，越先被删除
- **volatile-lru：**在有过期的时间键值对儿里，淘汰最近未被使用的
- **volatile-lfu：**在有过期的时间键值对儿里，淘汰最近最少使用的
- **allkeys-lru：**所有key中，淘汰最近未被使用的
- **allkeys-lfu：**所有key中，淘汰最近最少被使用的
- **allkeys-random：**所有key中，随机淘汰

## **<font size = '4' color = 'pink'>LRU算法实现</font>**

> 1、removeEldestEntry

```java
// Mybatis缓存中的实现
package org.apache.ibatis.cache.decorators;

import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.ibatis.cache.Cache;

/**
 * Lru (least recently used) cache decorator.
 *
 * @author Clinton Begin
 */
public class LruCache implements Cache {

  private final Cache delegate;
  private Map<Object, Object> keyMap;
  private Object eldestKey;

  public LruCache(Cache delegate) {
    this.delegate = delegate;
    setSize(1024);
  }

  @Override
  public String getId() {
    return delegate.getId();
  }

  @Override
  public int getSize() {
    return delegate.getSize();
  }

  public void setSize(final int size) {
    keyMap = new LinkedHashMap<Object, Object>(size, .75F, true) {
      private static final long serialVersionUID = 4267176411845948333L;

      @Override
      protected boolean removeEldestEntry(Map.Entry<Object, Object> eldest) {
        boolean tooBig = size() > size;
        if (tooBig) {
          eldestKey = eldest.getKey();
        }
        return tooBig;
      }
    };
  }

  @Override
  public void putObject(Object key, Object value) {
    delegate.putObject(key, value);
    cycleKeyList(key);
  }

  @Override
  public Object getObject(Object key) {
    keyMap.get(key); // touch
    return delegate.getObject(key);
  }

  @Override
  public Object removeObject(Object key) {
    return delegate.removeObject(key);
  }

  @Override
  public void clear() {
    delegate.clear();
    keyMap.clear();
  }

  private void cycleKeyList(Object key) {
    keyMap.put(key, key);
    if (eldestKey != null) {
      delegate.removeObject(eldestKey);
      eldestKey = null;
    }
  }

}
```

> 2、自定义实现

```java
package com.lsb.spring.base.letecode.有名算法.LRU算法;

import java.util.*;

/**
 *
 */
class LRUCache {
    static class DLinkedNode {
        int key;
        int value;
        DLinkedNode prev;
        DLinkedNode next;

        public DLinkedNode() {
        }

        public DLinkedNode(int _key, int _value) {
            key = _key;
            value = _value;
        }
    }

    private Map<Integer, DLinkedNode> cache = new HashMap<Integer, DLinkedNode>();
    private int size;
    private int capacity;
    private DLinkedNode head, tail;

    public LRUCache(int capacity) {
        this.size = 0;
        this.capacity = capacity;
        // 使用伪头部和伪尾部节点
        head = new DLinkedNode();
        tail = new DLinkedNode();
        head.next = tail;
        tail.prev = head;
    }

    public int get(int key) {
        DLinkedNode node = cache.get(key);
        if (node == null) {
            return -1;
        }
        // 如果 key 存在，先通过哈希表定位，再移到头部
        moveToHead(node);
        return node.value;
    }

    public void put(int key, int value) {
        DLinkedNode node = cache.get(key);
        if (node == null) {
            DLinkedNode nodeNew = new DLinkedNode(key, value);
            cache.put(key, nodeNew);
            addToHead(nodeNew);
            if (cache.size() > capacity) {
                // 如果超出容量，删除双向链表的尾部节点
                DLinkedNode tail = removeTail();
                // 删除哈希表中对应的项
                cache.remove(tail.key);
            }
        } else {
            node.value = value;
            moveToHead(node);
        }
    }

    private void moveToHead(DLinkedNode node) {
        removeNode(node);
        addToHead(node);
    }

    private void removeNode(DLinkedNode node) {
        node.prev.next = node.next;
        node.next.prev = node.prev;
    }

    private void addToHead(DLinkedNode node) {
        node.prev = head;
        node.next = head.next;
        head.next.prev = node;
        head.next = node;
    }
    private DLinkedNode removeTail() {
        DLinkedNode res = tail.prev;
        removeNode(res);
        return res;
    }
}
```

## **<font size = '4' color = 'pink'>Redis中的数据类型及其应用场景</font>**

1. **String（字符串）**
2. **List（列表）：**关注列表、粉丝列表，实现一个简单的轻量级消息队列
3. **Hash（字典）：**经常被用来存储用户相关信息。优化用户信息的获取，不需要重复从数据库当中读取，提高系统性能。
4. **Set（集合）：**关注列表、共同关注、我的粉丝，[查看实现](https://blog.97it.net/archives/140.html)
5. **Sorted Set（有序集合）**：用户的积分排行榜需求就可以通过有序集合实现，使用List实现轻量级的消息队列

## **<font size = '4' color = 'pink'>Redis为什么那么快？</font>**

- **纯内存**操作
- **单线程**没有额外的线程开销
- 基于**非阻塞的IO复用**模型机制：采用Reactor模式，redis利用epoll来实现IO多路复用，将连接信息和事件放到队列中，依次放到文件事件分派器，事件分派器将事件分发给事件处理器
- **Redis的自定义协议**
- **高效的数据结构：**每种数据类型的底层都由一种或多种数据结构来支持。正是因为有了这些数据结构，Redis 在存储与读取上的速度才不受阻碍

![image-20220802091012885](https://tva1.sinaimg.cn/large/e6c9d24ely1h4s5g5u2hdj20k80i5jte.jpg)

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r4a9peaej20hs0bl751.jpg)

**[更好的解析](https://baijiahao.baidu.com/s?id=1708807538121555902&wfr=spider&for=pc)**

## **<font size = '4' color = 'pink'>Redis的持久化机制</font>**

> **RDB（Redis默认持久化机制）、AOF、混合持久化（RDB+AOF）。**

### **RDB**

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r4q5u0j1j20lq0aft9v.jpg)

**手动触发：**可以使用save和bgsave两个命令进行触发

**save命令：**save命令会阻塞当前Redis的线程，直到RDB持久化过程完成为止，若持久化的数据较大，则会造成长时间的阻塞，不建议在线上环境直接使用该命令。

![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4r4rvze9nj20g008jmxp.jpg)

**bgsave命令：**fork操作创建出一个子进程，微秒级阻塞，时间很短，在执行redis-cli shutdown命令关闭redis服务时，如果没有开启AOF持久化，就会自动执行bgsave

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r4ttevhyj20mp0a10tk.jpg)

**bgsave 的原理是什么？**

fork 和 cow。

fork 是指 Redis 通过创建子进程来进行 bgsave 操作。

cow 指的是 copy on write，子进程创建后，父子进程共享数据段，父进程继续提供读写服务，写脏的页面数据会逐渐和子进程分离开来。 

这里 bgsave 操作后，会产生 RDB 快照文件。

**优点**

- 压缩后的二进制文件，适用于备份、全量复制，适用于灾难恢复
- 加载RDB恢复数据远快于AOF方式

**缺点**

- 无法做到实时，每次都要创建子进程，频繁操作成本过高
- 保存后的二进制文件，存在老版本不兼容新版本rdb文件的问题
- 数据可能丢失

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r4xcptcwj20bh0a5gm4.jpg)

### AOF

**开启和关闭：**默认没有启动，需要redis.config中进行手动修改

**执行流程：**当redis服务重启时，可加载AOF文件进行恢复。以下是AOF方案的执行流程。

![img](https://pic1.zhimg.com/80/v2-78fffe3b08cf6471c1dfeae7883a51d5_1440w.jpg?source=1940ef5c)

写入磁盘机制

![img](https://pica.zhimg.com/80/v2-2d24e5bd7a64506528c24dfb7e60ec2c_1440w.jpg?source=1940ef5c)

重写机制

![img](https://pic3.zhimg.com/80/v2-4f1dc98afe5c8793fd18538e7bd27dd9_1440w.jpg?source=1940ef5c)

**优点**

- **AOF比RDB更可靠：**我们可以设置不同的fsync策略：no、everysec和?always，默认是everysec。在这种配置下，redis仍然可以保持良好的性能，并且就算发生故障停机，也最多只会丢失1秒钟的数据

- AOF是一个纯追加的日志文件，即使日志因为某些原因包含了未写入完整的命令（如磁盘已满，写入中途停机等等）可以redis-check-aof轻易地修复这种问题。

- AOF文件件太大时，会重写

- AOF文件易于解析

  ![img](https://pic1.zhimg.com/80/v2-a50ba6316b18456e785dcb028067d119_1440w.jpg?source=1940ef5c)

**缺点**

AOF持久化的速度，相对RDB较慢的，存储的是一个文本文件，到了后期文件会比较大，传输困难。

### 混合

是对已有方式的优化。混合持久化只发于 AOF 重写过程。使用了混合持久化，重写后的新 AOF 文件件前半段是 RDB 格式的全量数据，后半段是 AOF 格式的增量数据

**优点：**结合RDB和AOF的优点，更快的重写和恢复

**缺点：**AOF文件中的RDB部分不再是AOF格式，可读性差

## **<font size = '4' color = 'pink'>分布式环境下，Redis如何保持数据的一致性</font>**

### 一致性

- **强一致性**：数据任何情况保持一致
- **弱一致性**：允许出现数据不一致的情况
- **最终一致性**：保证在一定时间内，能够达到一个数据一致的状态

### **<font size = '4' color = 'pink'>删除缓存，还是更新缓存？</font>**

删除，因为更新会导致数据不一致（最后的线程优先于前面的线程更新缓存，会导致数据不一致）

### 3种方案

**缓存延时双删：**更新前删除缓存，更新数据库后，延时（比如：1s）再次删除缓存。这个休眠时间 = 读业务逻辑数据的耗时 + 几百毫秒。这么做的目的，就是确保读请求结束，写请求可以删除读请求造成的缓存脏数据

**删除缓存重试机制：**把因为第二次删除失败的key放入消息队列，再次获取到要删除的key，重试删除操作

**读取biglog异步删除缓存：**可以使用阿里的canal将binlog日志采集发送到MQ队列里面然后通过ACK机制确认处理这条更新消息，删除缓存，保证数据缓存一致性

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4r5zh2sr6j20k00glaah.jpg)

**MySQL与Redis缓存的同步的两种方案：**

- **触发器+UDF函数：**通过MySQL自动同步刷新Redis
- **binlog：**解析MySQL的binlog实现，将数据库中的数据同步到Redis

## **<font size = '4' color = 'pink'>Redis命令踩坑</font>**

**过期时间意外丢失？**

```shell
127.0.0.1:6379> SET testkey val1 EX 60
OK
127.0.0.1:6379> TTL testkey
(integer) 59
127.0.0.1:6379> SET testkey val2
OK
127.0.0.1:6379> TTL testkey  // key永远不过期了！
(integer) -1
```

**DEL 竟然也会阻塞 Redis？**

> 原因：删除这种 key 时，Redis 需要依次释放每个元素的内存

**删除一个 key 的耗时，与这个 key 的类型有关**

- key 是 String 类型，DEL 时间复杂度是 O(1)
- key 是 List/Hash/Set/ZSet 类型，DEL 时间复杂度是 O(M)，M 为元素数量

**删除步骤：**

1. 查询元素数量：执行 LLEN/HLEN/SCARD/ZCARD 命令
2. 判断元素数量：如果元素数量较少，可直接执行 DEL 删除，否则分批删除
3. 分批删除：执行 LRANGE/HSCAN/SSCAN/ZSCAN + LPOP/RPOP/HDEL/SREM/ZREM 删除

## **<font size = '4' color = 'pink'>缓存雪崩、缓存穿透、缓存预热、缓存更新、缓存降级</font>**

> **缓存雪崩**

**解释：**大规模的缓存失效，导致大量的请求直接打在数据库上面，而使数据库实例宕机

**原因：**同一时间大规模的key失效

**分析几种可能：**

- redis宕机导致
- 采用了相同的过期时间

**解决方案：**

- 加上一个随机值，比如1-5分钟随机，避免相同的过期时间
- 设置某些key，只允许一个线程查询数据和写缓存
- 加锁或者使用队列来控制读数据库写缓存的线程数量
- 热点数据缓存永远不过期

>  **缓存击穿**

**解释：**大量请求访问热点key，而这个key刚好过期失效，导致数据库压力剧增

**原因：**访问了一个失效的热点key

**分析：**

- 是否可以考虑热点key不设置过期时间
- 是否可以考虑降低打在数据库上的请求数量

**解决方案：**

- 使用互斥锁
- 热点的key可以设置永不过期

> **缓存穿透**

**解释：**访问的key不存在，直接打在了数据库上

**原因：**访问了不存在的key

**解决方案：**

- 使用布隆过滤器（存在判误：不存在的key一定不存在，存在的key，就有大可能存在）
- 不存在的key，放进redis缓存（可能会严重占用内存）

> **缓存预热**

- 定时刷新缓存
- 项目启动的时候自动进行加载
- 写个缓存刷新页面，上线时手工操作下

> **缓存降级**

- 降级的最终目的是保证核心服务可用，即使是有损的

**总之，要做好熔断机制保护数据库不会被打死**