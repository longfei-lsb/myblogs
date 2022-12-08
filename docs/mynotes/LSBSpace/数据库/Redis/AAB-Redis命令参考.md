# AAB-Redis命令参考

## String（字符串）

### setrange

> setrange key offset value
>
> offset从1开始计数，将不包括索引值在内后面根据value挨个替换
>
> 为空则用符号补齐

```shell
192.168.0.12:6379> setrange name 2 zhang
(integer) 7
192.168.0.12:6379> get name
"\x00\x00zhang"
```

### getrange

> getrange name start end
>
> start 从0开始，获取包括start在内的数
>
> start 为-1则从最后一个字开始，到结束（没有则空字符，有则输出）

```shell
192.168.0.12:6379> get name
"\x00\x00zhanglisi"
192.168.0.12:6379> getrange name 1 25
"\x00zhanglisi"
192.168.0.12:6379> getrange name 0 -1
"\x00\x00zhanglisi"
192.168.0.12:6379> getrange name -1 -1
"i"
192.168.0.12:6379> getrange name -1 1
""
192.168.0.12:6379> getrange name -1 25
"i"
192.168.0.12:6379> 
```

### incrbyfloat

> INCRBYFLOAT key increment

```shell
# 值和增量都不是指数符号
redis> SET mykey 10.50
OK
redis> INCRBYFLOAT mykey 0.1
"10.6"
redis> SET mykey 314e-2 # 值和增量都是指数符号
OK
redis> GET mykey # 用 SET 设置的值可以是指数符号
"314e-2"
redis> INCRBYFLOAT mykey 0 # 但执行 INCRBYFLOAT 之后格式会被改成非指数符号
"3.14"
redis> SET mykey 3.0 # 后跟的 0 会被移除
OK
redis> GET mykey # SET 设置的值小数部分可以是 0
"3.0"
redis> INCRBYFLOAT mykey 1.000000000000  # INCRBYFLOAT 会将无用的 0 忽略掉，有需要的话，将浮点变为整数
"4"
redis> GET mykey
"4"
```

### bitcount

> bitcount ：通过指定额外的 `start` 或 `end` 参数，可以让计数只在特定的位上进行

分析一下bitcount是如何计数的

```shell
redis> SET mykey "foobar"
OK
redis> BITCOUNT mykey
(integer) 26
redis> BITCOUNT mykey 0 0
(integer) 4
redis> BITCOUNT mykey 1 1
(integer) 6
redis>
```

从ASCII码角度解析，foobar 对应的ASCII码如下：

|      | 二进制   | bit=1个数 |
| ---- | -------- | --------- |
| f    | 01100110 | 4         |
| o    | 01101111 | 6         |
| o    | 01101111 | 6         |
| b    | 01100010 | 3         |
| a    | 01100001 | 3         |
| r    | 01110010 | 4         |
|      |          | 26        |

1. BITCOUNT mykey，所有位置为1的数量为26。

2. BITCOUNT mykey 0 0，0 0 代表开始和结束的Byte位置数。0 0 取的是f，所以结果是4。

3. BITCOUNT mykey 1 1，1 1指从第一个Byte开始到下标为1结束，即o，结果为6。

4. BITCOUNT mykey 1 3, 指取下标1到3，即oob，结果为15。

### BITOP

> 进行位运算
>
> **BITOP operation destkey key [key ...]**

- `BITOP AND destkey key [key ...]` ，对一个或多个 `key` 求逻辑并，并将结果保存到 `destkey` 。
- `BITOP OR destkey key [key ...]` ，对一个或多个 `key` 求逻辑或，并将结果保存到 `destkey` 。
- `BITOP XOR destkey key [key ...]` ，对一个或多个 `key` 求逻辑异或，并将结果保存到 `destkey` 。
- `BITOP NOT destkey key` ，对给定 `key` 求逻辑非，并将结果保存到 `destkey` 。

除了 `NOT` 操作之外，其他操作都可以接受一个或多个 `key` 作为输入。

### mget

> 对多key进行运算合并等操作时，需要加上`{}`

```test

哈希槽(hash slot)是来自Redis Cluster的概念, 但在各种集群方案都有使用。

哈希槽是一个key的集合，Redis集群共有16384个哈希槽，每个key通过CRC16散列然后对16384进行取模来决定该key应当被放到哪个槽中，集群中的每个节点负责一部分哈希槽。

以有三个节点的集群为例:

节点A包含0到5500号哈希槽
节点B包含5501到11000号哈希槽
节点C包含11001到16384号哈希槽
这样的设计有利于对集群进行横向伸缩，若要添加或移除节点只需要将该节点上的槽转移到其它节点即可。
在某些集群方案中，涉及多个key的操作会被限制在一个slot中，如Redis Cluster中的mget/mset操作。

```

**HashTag**

```
HashTag机制可以影响key被分配到的slot，从而可以使用那些被限制在slot中操作。

HashTag即是用{}包裹key的一个子串，如{user:}1, {user:}2。

在设置了HashTag的情况下，集群会根据HashTag决定key分配到的slot， 两个key拥有相同的HashTag:{user:}, 它们会被分配到同一个slot，允许我们使用MGET命令。

通常情况下，HashTag不支持嵌套，即将第一个{和第一个}中间的内容作为HashTag。若花括号中不包含任何内容则会对整个key进行散列，如{}user:。

HashTag可能会使过多的key分配到同一个slot中，造成数据倾斜影响系统的吞吐量，务必谨慎使用。

```

### msetnx

> 即便只有一个给定 `key` 已存在， `MSETNX`也会拒绝执行所有给定 `key` 的设置操作。
>
> 原子性：要么全被设置，要么全不被设置

### PSETEX

> 它以毫秒为单位，SETEX是以秒为单位

### expireat

> **EXPIREAT key timestamp：**UNIX时间戳的方式去设置过期时间

### migrate

> **MIGRATE host port key destination-db timeout [COPY] [REPLACE]**
>
> MIGRATE 127.0.0.1 7777 greeting 0 1000
>
> 将目标key复制/移动到指定redis实例中