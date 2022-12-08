# 02-消费者Java客户端

[TOC]

**名词解释**

> 一个从kafka集群中获取消息的java客户端，**消费者不是线程安全的**

- 透明地处理kafka集群中出现故障broker
- 透明地调节适应集群中变化的数据分区

```java
public class KafkaConsumer<K,V> extends Object implements Consumer<K,V>
```

## offset(偏移量)和消费者位置

**`偏移量`**是分区中一条消息的唯一标示，也表示消费者在分区的位置

**消费者的位置**给出了下一条消息的偏移量。它比消费者在该分区中看到的最大偏移量要大一个。它在每次消费者在调用`poll(Duration)`中接收消息时自动增长。

**`已提交`的位置**是已安全保存的最后偏移量，如果进程失败或重新启动时，消费者将恢复到这个偏移量

消费者可以选择定期自动提交偏移量，也可以选择通过调用commit API来手动的控制(如：`commitSync` 和 `commitAsync`)。主要区别是消费者来控制一条消息什么时候才被认为是`已被消费`的，**控制权在消费者**

## 消费者组和主题订阅

> Kafka的`消费者组`概念，通过 **进程池** 瓜分消息并处理消息。这些进程可以在同一台机器运行，也可分布到多台机器上，以增加可扩展性和容错性，相同`group.id`的消费者将视为同一个`消费者组`

每个消费者通过`subscribe API`动态订阅一个`topic`列表，`Kafka`会将已经订阅`topic`的消息发送到每个`group`，并通过**平衡分区**在消费者分组中所有成员之间来达到平均。

每个分区恰好地分配1个消费者（一个消费者组中）。如果一个`topic`有4个分区，并且一个消费者分组有只有2个消费者。那么每个消费者将消费2个分区

**自动动态维护**

**消费者组的成员是动态维护的**，消费者的故障、`topic`分区的增加、匹配新的`topic`等等，Kafka消费者都会都将重新平衡，这被称为`重新平衡分组`

此外，当分组重新分配自动发生时，可以通过**`ConsumerRebalanceListener`**通知消费者，这允许他们完成必要的应用程序级逻辑，例如状态清除，手动偏移提交等。

**手动维护**

它也允许消费者通过使用`assign(Collection)`手动分配指定分区，手动维护时，自动维护将失效

## 发现消费者故障

订阅一组topic后，当调用poll(long）时，消费者将自动加入到组中，只要持续的调用poll，消费者将一直保持可用，并继续从分配的分区中接收消息，此外，消费者向服务器定时发送心跳。

当达到以下任意条件，消费者将被视为死亡，并且将它的分区重新分配给其他消费者

- 消费者崩溃
- 无法在session.timeout.ms配置的时间内发送心跳
- 持续的发送心跳，但是没有处理

对于第三种情况，为了防止消费者“占着茅坑（分区）不拉屎的情况”，我们使用`max.poll.interval.ms`活跃检测机制。 在此基础上，如果你调用的`poll`的频率大于最大间隔，则客户端将主动地离开组，以便其他消费者接管该分区。发生这种情况时，你会看到offset提交失败（调用commitSync（）引发的CommitFailedException）。这是一种安全机制，保障只有活动成员能够提交offset。所以**要留在组中，你必须持续调用poll**。

消费者提供两个配置设置来控制poll循环：

1. `max.poll.interval.ms`：增大poll的间隔，可以为消费者提供更多的时间去处理返回的消息（调用poll(long)返回的消息，通常返回的消息都是一批）。缺点是此值越大将会延迟组重新平衡。
2. `max.poll.records`：此设置限制每次调用poll返回的消息数，这样可以更容易的预测每次poll间隔要处理的最大值。通过调整此值，可以减少poll间隔，减少重新平衡分组

**ps：**由于消费者消息处理时间的不可预测性，所以建议另开线程去处理返回的消息，**但是必须注意确保已提交的offset不超过实际位置。**另外，你必须禁用自动提交，并只有在线程完成处理后才为记录手动提交偏移量（取决于你）。 还要注意，你需要`pause暂停`分区，不会从poll接收到新消息，让线程处理完之前返回的消息（如果你的处理能力比拉取消息的慢，那创建新线程将导致你机器内存溢出）。

## 示例

### 自动提交偏移量(Automatic Offset Committing)

```java
Properties props = new Properties();
props.setProperty("bootstrap.servers", "localhost:9092");
props.setProperty("group.id", "test");
props.setProperty("enable.auto.commit", "true");
props.setProperty("auto.commit.interval.ms", "1000");
props.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
props.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList("foo", "bar"));
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records)
        System.out.printf("offset = %d, key = %s, value = %s%n", record.offset(), record.key(), record.value());
}
```

设置`enable.auto.commit`,偏移量由`auto.commit.interval.ms`控制自动提交的频率。

集群是通过配置bootstrap.servers指定一个或多个broker。不用指定全部的broker，它将自动发现集群中的其余的borker**（最好指定多个，万一有服务器故障）**。

客户端订阅了主题`foo`和`bar`。消费者组叫`test`。

broker通过心跳机器自动检测test组中失败的进程，消费者会自动`ping`集群，告诉进群它还活着。如果它停止心跳的时间超过`session.timeout.ms`,那么就会认为是故障的，它的分区将被分配到别的进程。

这个`deserializer`设置如何把byte转成object类型，例子中，通过指定string解析器，我们告诉获取到的消息的key和value只是简单个string类型。

### 手动控制偏移量(Manual Offset Control)

> 您可以直接控制记录何时被视为“已消费”

可以自己控制offset，当消息认为已消费过了，这个时候再去提交它们的偏移量。这个很有用的，当消费的消息结合了一些处理逻辑，这个消息就不应该认为是已经消费的，直到它完成了整个处理。

```java
Properties props = new Properties();
props.setProperty("bootstrap.servers", "localhost:9092");
props.setProperty("group.id", "test");
props.setProperty("enable.auto.commit", "false");
props.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
props.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList("foo", "bar"));
final int minBatchSize = 200;
List<ConsumerRecord<String, String>> buffer = new ArrayList<>();
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        buffer.add(record);
    }
    if (buffer.size() >= minBatchSize) {
        insertIntoDb(buffer);
        consumer.commitSync();
        buffer.clear();
    }
}
```

在这个例子中，我们将消费一批消息并将它们存储在内存中。当我们积累足够多的消息后，我们再将它们批量插入到数据库中。

> **我们一定要明确：**消息处理和偏移量提交是两个过程，这也提供给了消费者处理消息的强大灵活性

**一种情况：**如果设置是自动提交，可能会出现，在Kafka中已经消费了的消息，保存到数据库却失败了，对于整个程序来说，其实并没有准确控制消息是成功消费的。**为了避免这种情况，我们去手动提交偏移量**

**另一种情况：**数据库保存成功，手动提交出现了事故（这只是一种可能性），那么消费者则会获取到之前相同的已经提交的偏移量，导致重复消费（这就是`Kafka`的至少一次保证），对于`Kafka`视角来说，在故障情况下，可以重复

**还有一种情况：**如果无法执行已消费的操作，却执行了手动提交（比如：异常捕获后，没有处理，直接跳过），这会使已提交的偏移超过消耗的位置，这肯定会导致记录缺失

> 注意：针对于第二种情况，自动提交也可以完成至少一次，但需要你必须下次调用`poll(Duration)`之前或关闭消费者之前，处理完所有返回的数据，否则，也会出现第三种情况！（用屁股想想都知道～）

某些情况下，我们需要更精确的提交，通过指定一个明确消息的偏移量为“已提交”，例如，我们处理完每个分区中的消息后，提交偏移量（而非刚才的那种处理完所有分区的消息后，一并提交偏移量）：

```java
try {
    while(running) {
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(Long.MAX_VALUE));
        for (TopicPartition partition : records.partitions()) {
            List<ConsumerRecord<String, String>> partitionRecords = records.records(partition);
            for (ConsumerRecord<String, String> record : partitionRecords) {
                System.out.println(record.offset() + ": " + record.value());
            }
            long lastOffset = partitionRecords.get(partitionRecords.size() - 1).offset();
            consumer.commitSync(Collections.singletonMap(partition, new OffsetAndMetadata(lastOffset + 1)));
        }
    }
} finally {
  consumer.close();
}
```

**注意：**已提交的offset应始终是你的程序将读取的下一条消息的offset。因此，调用`commitSync(offsets)`时，你应该加1个到最后处理的消息的offset。

### 订阅指定的分区(Manual Partition Assignment)

有些场景可能需要我们指定`topic`的分区去消费消息，比如：

- 一个消费者进程与该分区保存了某种本地状态（如本地磁盘的键值存储），则它应该只能获取这个分区的消息
- 消费者本身的高可用性（会故障恢复，在另一台机器重启）。在这种情况下，不需要Kafka检测故障，重新分配分区，因为消费者进程将在另一台机器上重新启动

要使用此模式，，你只需调用`assign（Collection）`消费指定的分区即可：

```java
String topic = "foo";
TopicPartition partition0 = new TopicPartition(topic, 0);
TopicPartition partition1 = new TopicPartition(topic, 1);
consumer.assign(Arrays.asList(partition0, partition1));
```

一旦**手动分配分区**，你可以在循环中调用poll（跟前面的例子一样）。消费者分组仍需要提交offset，只是现在**分区的设置只能通过调用`assign`修改**，因为手动分配**不会进行分组协调**，因此消费者故障**不会引发分区重新平衡**。每一个消费者是独立工作的（即使和其他的消费者共享GroupId）。为了避免offset提交冲突，通常你**需要确认每一个consumer实例的gorupId都是唯一的**。

> 注意，手动分配分区（即，assgin）和动态分区分配的订阅topic模式（即，subcribe）不能混合使用。

## 在Kafka之外存储偏移量

消费者可以不使用kafka内置的offset仓库。可以选择自己来存储offset。

需要注意的是：用原子的方式存储结果和offset，但这不能保证原子，要想真正的原子，你需要使用kafka的offset提交功能。

**例子**

- 消费结果和offset存储在`关系数据库`中：让提交结果和offset在单个事务中，要么一起成功，要么一起失败
- 消费结果和offset存储在`本地仓库`中：可以通过订阅一个指定的分区并将offset和索引数据一起存储来构建一个搜索索引。如果这是以原子的方式做的，常见的可能是，即使崩溃引起未同步的数据丢失。索引程序从它确保没有更新丢失的地方恢复，而仅仅丢失最近更新的消息

每个消息都有自己的offset，所以要管理自己的偏移，你只需要做到以下几点：

- 配置 `enable.auto.commit=false`
- 使用提供的 `ConsumerRecord` 来保存你的位置。
- 在重启时用 `seek(TopicPartition, long)` 恢复消费者的位置。

当分区分配也是手动完成的（像上文搜索索引的情况），这种类型的使用是最简单的。

如果分区分配是自动完成的，需要特别小心处理分区分配变更的情况。可以通过调用`subscribe（Collection，ConsumerRebalanceListener）`和`subscribe（Pattern，ConsumerRebalanceListener）`中提供的`ConsumerRebalanceListener`实例来完成的。例如，当消费者需要放弃分区获取时，消费者将通过实现`ConsumerRebalanceListener.onPartitionsRevoked（Collection）`来给这些分区提交它们offset。当分区分配给消费者时，消费者通过`ConsumerRebalanceListener.onPartitionsAssigned(Collection)`为新的分区正确地将消费者初始化到该位置。

`ConsumerRebalanceListener`的另一个常见用法是清除应用已移动到其他位置的分区的缓存。

**例子如下：**

```java
/**
  * main：如何自动分配分区给消费者的情况下，去维护在Kafka之外存储的偏移量
  */
 static void maintainOutsideOffsetForAutoPartitions() {
     Properties props = new Properties();
     props.setProperty("bootstrap.servers", "81.70.52.213:9092");
     props.setProperty("group.id", "test");
     props.setProperty("enable.auto.commit", "true");
     props.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
     props.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
     KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
     // 这里加监听器
     consumer.subscribe(Arrays.asList("my-topic", "topic-test"), new MyTopicConsumerRebalanceListener(consumer, currentOffsets));
     try {
         while (true) {
             ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(Long.MAX_VALUE));
             for (ConsumerRecord<String, String> record : records) {
                 //消费消息
                 currentOffsets.put(new TopicPartition(record.topic(), record.partition()), new OffsetAndMetadata(record.offset() + 1));
             }
         }
     } finally {
         consumer.close();
     }
 }

// MyTopicConsumerRebalanceListener
public class MyTopicConsumerRebalanceListener implements ConsumerRebalanceListener {
    private final KafkaConsumer<String, String> consumer;

    private final Map<TopicPartition, OffsetAndMetadata> currentOffsets;

    public MyTopicConsumerRebalanceListener(KafkaConsumer<String, String> consumer, Map<TopicPartition, OffsetAndMetadata> currentOffsets) {
        this.consumer = consumer;
        this.currentOffsets = currentOffsets;
    }

    /**
     * 这个方法会在在均衡开始之前和消费者停止读取消息之后被调用
     */
    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        //提交消费位移
        consumer.commitSync(currentOffsets);
    }

    /**
     * 这个方法会在重新分配之后和消费者开始读取消费之前被调用
     */
    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        partitions.forEach(topicPartition -> {
            consumer.seek(topicPartition, currentOffsets.get(topicPartition));
        });
    }
}
```

## 控制消费的位置

**大多数情况下**

从头到尾的消费消息，周期性的提交位置（自动或手动）

**几种场景需要自定义消费位置**

1. 消费者对时间敏感
2. 本地状态存储消费信息（上面说的）

**自定义消费位置**

kafka使用`seek(TopicPartition, long)`指定新的消费位置。用于查找服务器保留的最早和最新的offset的特殊的方法也可用（`seekToBeginning(Collection)` 和 `seekToEnd(Collection)`）。

## 消费者流量控制

如果消费者分配了多个分区，并同时消费所有的分区，这些分区具有相同的优先级。

例如流处理，当处理器从2个topic获取消息并把这两个topic的消息合并，当其中一个topic长时间落后另一个，则暂停消费，以便落后的赶上来。

kafka支持动态控制消费流量，分别在future的`poll(long)`中使用`pause(Collection)` 和 `resume(Collection)` 来暂停消费指定分配的分区，重新开始消费指定暂停的分区。

## 读取事务性消息

// TODO

## 多线程处理

// TODO
