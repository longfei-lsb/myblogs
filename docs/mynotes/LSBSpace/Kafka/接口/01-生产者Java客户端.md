# 02-生产者Java客户端

[TOC]

## kafka客户端发布`record(消息)`到kafka集群

新的生产者是线程安全的，在线程之间共享**单个生产者**实例，通常单例比多个实例要快

一个简单的例子，使用producer发送一个有序的key/value(键值对)，放到java的`main`方法里就能直接运行

```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("acks", "all");
props.put("retries", 0);
props.put("batch.size", 16384);
props.put("linger.ms", 1);
props.put("buffer.memory", 33554432);
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

Producer<String, String> producer = new KafkaProducer<>(props);
for(int i = 0; i < 100; i++)
    producer.send(new ProducerRecord<String, String>("my-topic", Integer.toString(i), Integer.toString(i)));
// 这里要关闭，否则会丢失数据，原因下面会说
producer.close();
```

生产者的`缓冲空间池`保留尚未发送到服务器的消息，后台I/O线程负责将这些消息转换成请求发送到集群，如果**使用后不关闭生产者，则会丢失这些消息**（自己可以去掉`producer.close();`试一遍）

`send()`方法是异步的，添加消息到缓冲区等待发送，并立即返回。**生产者将单个的消息批量在一起发送来提高效率**。

`ack`是判别请求是不是成功发送了，指定了“all”将会阻塞消息，这种设置性能最低，但是是最可靠的

`retries`，如果请求失败，生产者会自动重试，我们指定是0次，如果**启用重试，则会有重复消息的可能性**。

`producer`(生产者)缓存每个分区未发送的消息。缓存的大小是通过 `batch.size` 配置指定的。值较大的话将会产生更大的批。并需要更多的内存（因为每个“活跃”的分区都有1个缓冲区）。

默认缓冲可立即发送，即便缓冲空间还没有满，如果你想减少请求的数量，可以设置`linger.ms`大于0。例如上面的代码段，可能100条消息在一个请求发送，因为我们设置了linger(逗留)时间为1毫秒，然后，如果我们没有填满缓冲区，这个设置将增加1毫秒的延迟请求以等待更多的消息。**需要注意的是，在高负载下，相近的时间一般也会组成批，即使是 `linger.ms=0`。在不处于高负载的情况下，如果设置比0大，以少量的延迟代价换取更少的，更有效的请求。** --- 这个没看懂

`buffer.memory` 控制生产者可用的缓存总量，如果消息发送速度比其传输到服务器的快，将会耗尽这个缓存空间。当缓存空间耗尽，其他发送调用将被阻塞，阻塞时间的阈值通过`max.block.ms`设定，之后它将抛出一个TimeoutException。

`key.serializer`和`value.serializer`示例，将用户提供的key和value对象ProducerRecord转换成字节，你可以使用附带的**ByteArraySerializaer**或**StringSerializer**处理简单的string或byte类型。

## 幂等和事务

从`Kafka 0.11`开始，KafkaProducer又支持两种模式：`幂等生产者`和`事务生产者`

- **幂等生产者：**从至少一次交付到精确一次交付，特别是生产者的重试将不再引入重复
- **事务生产者：**原子地将消息发送到多个分区（和主题！）

要启用`幂等（idempotence）`，必须将`enable.idempotence`配置设置为`true`。 如果设置，则`retries（重试）`配置将默认为`Integer.MAX_VALUE`，acks配置将默认为`all`。API没有变化，所以无需修改现有应用程序即可利用此功能。**生产者只能保证单个会话内发送的消息的幂等性**

要使用`事务生产者`和`attendant API`，必须设置`transactional.id`。如果设置了`transactional.id`，幂等性会和幂等所依赖的生产者配置一起自动启用。此外，应该对包含在事务中的topic进行耐久性配置。特别是，`replication.factor`应该至少是`3`，而且这些topic的`min.insync.replicas`应该设置为`2`。最后，为了实现从端到端的事务性保证，消费者也必须配置为只读取`已提交`的消息。

`transactional.id`的目的是实现单个生产者实例的多个会话之间的事务恢复。它通常是由分区、有状态的应用程序中的分片标识符派生的。因此，它对于在分区应用程序中运行的每个生产者实例来说应该是唯一的。

所有新的事务性API都是阻塞的，并且会在失败时抛出异常。下面的例子说明了新的API是如何使用的。它与上面的例子类似，只是所有100条消息都是一个事务的一部分。

```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("transactional.id", "my-transactional-id");
Producer<String, String> producer = new KafkaProducer<>(props, new StringSerializer(), new StringSerializer());

producer.initTransactions();

try {
    producer.beginTransaction();
    for (intcer<Stringtring> producer producerducer = new KafkaProducer<>(props, new StringSerializer(), new StringSerializer());

producer.initTransactions();

try {
    producer.beginTransaction();
    for (int i = 0; i < 100; i++)
        producer.send(new ProducerRecord<>("my-topic", Integer.toString(i), Integer.toString(i)));
    producer.commitTransaction();
} catch (ProducerFencedException | OutOfOrderSequenceException | AuthorizationException e) {
    // We can't recover from these exceptions, so our only option is to close the producer and exit.
    producer.close();
} catch (KafkaException e) {
    // For all other exceptions, just abort the transaction and try again.
    producer.abortTransaction();
}
producer.close();

```

## send()

```java
public Future<RecordMetadata> send(ProducerRecord<K,V> record,Callback callback)
```

异步发送消息，当发送已确认是调用`callback`

`send`发送的异步消息保存在`等待发送的消息缓存`中，此方法就立即返回。

发送的结果是一个`RecordMetadata`（**发送的分区、分配的offset、消息时间戳**），其中：如果topic使用的是**CreateTime**，则使用**用户提供的时间戳或发送的时间**；如果topic使用的是**LogAppendTime**，则追加消息时，**时间戳是broker的本地时间**

异步会返回一个`future`，调用`get()`会阻塞，直到返回`RecordMetadata`或抛异常

**发送到同一个分区的消息回调保证按一定的顺序执行**，也就是说，在下面的例子中 `callback1` 保证执行 `callback2` 之前：

```java
producer.send(new ProducerRecord<byte[],byte[]>(topic, partition, key1, value1), callback1);
producer.send(new ProducerRecord<byte[],byte[]>(topic, partition, key2, value2), callback2);
```

**注意：**`callback`一般在生产者的`I/O`线程中执行，所以是相当的快的，如果执行时间太长，将阻塞延迟其他的线程的消息发送。

如果回调很昂贵，建议在`callback`主体中使用自己的`Executor`来并行处理

