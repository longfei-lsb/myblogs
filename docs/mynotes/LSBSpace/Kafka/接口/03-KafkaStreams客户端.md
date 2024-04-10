# 03-KafkaStreams客户端

[TOC]

> ***Kafka Streams从一个或多个输入topic进行连续的计算并输出到0或多个外部topic中。***

可以通过`TopologyBuilder`类定义一个计算逻辑`处理器`DAG拓扑。或者也可以通过提供的高级别`Streams DSL`来定义转换的StreamsBuilder。（PS：计算逻辑其实就是自己的代码逻辑；DSL：以极其高效的方式描述特定领域的对象、规则和运行方式的语言。）

```java
/**
 * 该类是将两个名称分别为："my-topic", "topic-test"的topic，通过Stream的api 经过一定的逻辑，输出到另一个名为："my-output-topic"的 topic 中
 */
public class KafkaStreamBuilderTest {
    public static void main(String[] args) {
        Map<String, Object> props = new HashMap<>();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "my-stream-processing-application");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "81.70.52.213:9092");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        StreamsConfig config = new StreamsConfig(props);

        StreamsBuilder builder = new StreamsBuilder();
        builder.stream(Arrays.asList("my-topic", "topic-test"))
                .mapValues(value -> value.toString() + 666)
                .to("my-output-topic");
        Topology topology = builder.build();
        KafkaStreams streams = new KafkaStreams(topology, config);
        streams.start();
    }
}
```

在内部，KafkaStreams实例包含一个正常的`KafkaProducer`和`KafkaConsumer`实例，用于读取和写入

KafkaStreams实例可以作为单个streams处理客户端（也可能是分布式的）。

**分布式`Kafka Stream`的原理：**

与其他的相同`StreamsConfig.APPLICATION_ID_CONFIG`的实例进行协调（无论是否在同一个进程中，在同一台机器的其他进程中，或远程机器上）。这些实例将根据输入 `topic`分区的基础上来划分工作，以便所有的分区都被消费掉。如果实例添加或失败，所有实例将重新平衡它们之间的分区分配，以保证负载平衡。