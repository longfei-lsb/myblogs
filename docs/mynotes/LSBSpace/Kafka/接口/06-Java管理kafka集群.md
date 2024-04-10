# 06-Java管理kafka集群

Kafka的管理Java客户端，支持管理和检查topic、broker、配置和ACL。

```java
/**
 * Java管理kafka集群
 */
public class KafkaAdminTest {
    public static void main(String[] args) {
        String bootstrapServers = "81.70.52.213:9092";
        createTopics(bootstrapServers, Arrays.asList("topic1", "topic2", "topic3"));
        listTopics(bootstrapServers);
        newPartitions(bootstrapServers, "topic1");
    }

    /**
     * 指定集群创建主题
     */
    private static void createTopics(String bootstrapServers, List<String> topicList) {
        List<NewTopic> newTopicList = topicList.stream().map(topic -> new NewTopic(topic, 1, (short) 1)).collect(Collectors.toList());
        Properties properties = new Properties();
        properties.put("bootstrap.servers", bootstrapServers);
        properties.put("connections.max.idle.ms", 10000);
        properties.put("request.timeout.ms", 5000);
        try (AdminClient client = AdminClient.create(properties)) {
            CreateTopicsResult result = client.createTopics(newTopicList);
            try {
                result.all().get();
            } catch (InterruptedException | ExecutionException e) {
                throw new IllegalStateException(e);
            }
        }
    }

    /**
     * 查看指定集群中的topic列表
     */
    private static void listTopics(String bootstrapServers) {
        Properties properties = new Properties();
        properties.put("bootstrap.servers", bootstrapServers);
        properties.put("connections.max.idle.ms", 10000);
        properties.put("request.timeout.ms", 5000);
        try (AdminClient client = AdminClient.create(properties)) {
            ListTopicsResult result = client.listTopics();
            try {
                result.listings().get().forEach(topic -> {
                    System.out.println(topic);
                });
            } catch (InterruptedException | ExecutionException e) {
                throw new IllegalStateException(e);
            }
        }
    }

    /**
     * 指定集群，指定topic增加分区
     */
    private static void newPartitions(String bootstrapServers, String topic) {
        Properties properties = new Properties();
        properties.put("bootstrap.servers", bootstrapServers);
        properties.put("connections.max.idle.ms", 10000);
        properties.put("request.timeout.ms", 5000);

        try (AdminClient client = AdminClient.create(properties)) {
            Map<String, NewPartitions> newPartitions = new HashMap<>();
            // 增加到2个
            newPartitions.put(topic, NewPartitions.increaseTo(2));
            CreatePartitionsResult rs = client.createPartitions(newPartitions);
            try {
                rs.all().get();
            } catch (InterruptedException | ExecutionException e) {
                throw new IllegalStateException(e);
            }
        }
    }
}
```