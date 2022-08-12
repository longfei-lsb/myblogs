# commons-pool 对象池分析

[TOC]



## 1、池-河豚池

要创建一个池，必须有一个池的抽象，至于抽象方法的定义，我们是通过现实中的范例来抽象出来的同一种行为方式。

简单来讲：<font color="pink">池应为抽象池，池有接收、推送和关闭销毁的基本能力</font>

在此基础上，抽象池也应该具有对“池中物”的一些其他能力

- 清空池中物
- 借出
- 归还
- 清空
- 过滤进来的物体
- 状态统计
- 库存统计
- ……

那么，我们根据刚才的理解创建出自己的池

> 抽象池体-对象池（ObjectPool<T>） T - 代表泛意义上的对象，可以理解为池中真实实体

```java
public interface ObjectPool<T> extends Closeable {

    /**
     * 池接收实体的能力
     */
    void addObject() throws Exception, IllegalStateException,
            UnsupportedOperationException;

    /**
     * 批量接收实体的能力
     */
    default void addObjects(final int count) throws Exception {
        for (int i = 0; i < count; i++) {
            addObject();
        }
    }

    /**
     * 推送给外部使用的能力
     */
    T borrowObject() throws Exception, NoSuchElementException,
            IllegalStateException;

    /**
     * 清空池中实体的能力
     */
    void clear() throws Exception, UnsupportedOperationException;

    /**
     * 禁止使用的能力
     */
    @Override
    void close();

    /**
     * 当前借出去的数量
     */
    int getNumActive();

    /**
     * 池当前状态的实体闲置数量
     */
    int getNumIdle();

    /**
     * 当借出去的实体被确定（由于异常或其他问题）无效时，应使用此方法
     */
    void invalidateObject(T obj) throws Exception;

    /**
     * 借出去的实体无效时，告诉池子应该以什么样的方式销毁该实体
     */
    default void invalidateObject(final T obj, final DestroyMode mode) throws Exception {
        invalidateObject(obj);
    }

    /**
     * 回收原本的池中物（借出去的）
     */
    void returnObject(T obj) throws Exception;

}

```

那我们到这里已经创建了一个池，也赋予了池该有的特性，（不难想到，我们池中还应该有一个可以存放实体的容器，我们先跳过，之后再分析解答）

## 2、池中物（河豚）

我们应该明白，我们自己自定义实体是没有办法被提前预知的，所以在定义池中物的时候我们应该具有抽象的定义，以此来代表所有的池中物，并赋予其特性和能力

简单来讲：<font color="pink">池中物应具有代表放进池中的单个实体的通用抽象</font>

在此基础上，池中物也应该具有从池中取出到归还的所有信息，例如：状态、取出时间、借用时间、使用次数、……

例如：一台电视机，你拿出来的时候可以知道它的防伪标识、出厂日期、分辨率、品牌、当前状态（开｜关机）、当前售卖流程（已出售）等等。

那么，我们根据刚才的理解创建出池中物的抽象

> 池中物-池中对象（PooledObject<T>） T - 代表泛意义上的对象，可以理解为一个池中物真实实体

```java
public interface PooledObject<T> extends Comparable<PooledObject<T>> {

    /**
     * 池中物被派发（借出）时执行
     */
    boolean allocate();

    /**
     * 池中物的比较规则
     */
    @Override
    int compareTo(PooledObject<T> other);

    /**
     * 池中物被回收（归还）时执行
     */
    boolean deallocate();

    /**
     * 告知驱逐测试已经结束
     */
    boolean endEvictionTest(Deque<PooledObject<T>> idleQueue);

    @Override
    boolean equals(Object obj);

    /**
     * 获取池中物活跃时间（脱离池之后的时间）
     */
    default Duration getActiveTime() {
        return Duration.ofMillis(getActiveTimeMillis());
    }

    /**
     * 获取池中物活跃时间（ms级）
     */
    long getActiveTimeMillis();

    /**
     * 被人用了多少次
     */
    default long getBorrowedCount() {
        return -1;
    }

    /**
     * 什么时候开始成了池中物
     */
    long getCreateTime();

    /**
     * 呆在池中闲了多长时间
     */
    default Duration getIdleTime() {
        return Duration.ofMillis(getIdleTimeMillis());
    }

    /**
     * 呆在池中闲了多长时间（ms级）
     */
    long getIdleTimeMillis();

    /**
     * 上次借出时间
     */
    long getLastBorrowTime();

    /**
     * 上次归还时间
     */
    long getLastReturnTime();

    /**
     * 上次使用时间
     */
    long getLastUsedTime();

    /**
     * 获取真实实体
     */
    T getObject();

    /**
     * 池中物的目前状态
     */
    PooledObjectState getState();

    @Override
    int hashCode();

    /**
     * 设为无效
     */
    void invalidate();

    /**
     * 设为抛弃、无效
     */
    void markAbandoned();

    /**
     * 标记为归还
     */
    void markReturning();

    /**
     * 打印栈信息
     */
    void printStackTrace(PrintWriter writer);

    /**
     * 暂时不用
     */
    void setLogAbandoned(boolean logAbandoned);

    /**
     * 暂时不用
     */
    default void setRequireFullStackTrace(final boolean requireFullStackTrace) {
        // noop
    }

    /**
     * 暂时不用
     */
    boolean startEvictionTest();

    /**
     * 暂时不用
     */
    @Override
    String toString();

    /**
     * 暂时不用
     */
    void use();
```

池中物创建完成！

## 3、池中物工厂-（养河豚者）

顾名思义，工厂是用来创建池中物实体的，即：池中物实体的来源

前面我们已经有了池、池中物，两个静态抽象物，<font color="pink"> 那么什么样的实体才能是池中物呢？又以什么样的表现形式去借还呢？</font>

那么现在我们需要一个第三个操作者，用来处理将**什么样**的自定义（也可为第三方）实体作为池中物真正实体、并且**以怎样**的方式放入池中，**怎样的**方式取出来。

按照上述的理解，这个第三者应该具备一下基本职能：

- 创造出池中物
- 处理并借出池中物
- 归还并处理池中物
- 销毁池中物

那么我们按照这样的职能去理解一下下面的第三者抽象。

> 池中物工厂-负责池中物的第三者（PooledObjectFactory<T> ） T - 代表泛意义上的对象，可以理解为单个池中物真实实体

```java
public interface PooledObjectFactory<T> {

  /**
   * 借之前调用，用来对实体做处理（借出河豚之前，喂食，保证它有搽皮鞋的力气）
   */
  void activateObject(PooledObject<T> p) throws Exception;

  /**
   * 以默认的方式，销毁实体
   */
  void destroyObject(PooledObject<T> p) throws Exception;

  /**
   * 以指定的方式，销毁实体
   */
  default void destroyObject(final PooledObject<T> p, final DestroyMode mode) throws Exception {
      destroyObject(p);
  }

  /**
   * 创造池中物
   */
  PooledObject<T> makeObject() throws Exception;

  /**
   * 归还时调用（河豚被回收时，如果死了就扔掉，或者丢给汽车厂做轮胎……，哈哈哈）
   */
  void passivateObject(PooledObject<T> p) throws Exception;

  /**
   * 校验实体，并作处理
   */
  boolean validateObject(PooledObject<T> p);
}

```

## 4、辅助物

> 鱼叉、渔网、鱼厂标记笔等等

到这里我们已经能够粗略的描述出池的工作模式了，但是也远并非如此，我们在此之前还需要一些辅助性的配置

接下来是所有的辅助配置，我会在代码里面一一解释

```java
/**
 * 打印信息的
 */
public abstract class BaseObject {

    @Override
    public String toString() {
        final StringBuilder builder = new StringBuilder();
        builder.append(getClass().getSimpleName());
        builder.append(" [");
        toStringAppendFields(builder);
        builder.append("]");
        return builder.toString();
    }

    /**
     * 继承的类附加进来的信息
     */
    protected void toStringAppendFields(final StringBuilder builder) {
        // do nothing by default, needed for b/w compatibility.
    }
}
```

配置类（先放到这里，之后讲解）

```java
/**
 * Provides the implementation for the common attributes shared by the
 * sub-classes. New instances of this class will be created using the defaults
 * defined by the public constants.
 * <p>
 * This class is not thread-safe.
 * </p>
 *
 * @param <T> Type of element pooled.
 * @since 2.0
 */
public abstract class BaseObjectPoolConfig<T> extends BaseObject implements Cloneable {

    /**
     * The default value for the {@code lifo} configuration attribute.
     * @see GenericObjectPool#getLifo()
     * @see GenericKeyedObjectPool#getLifo()
     */
    public static final boolean DEFAULT_LIFO = true;

    /**
     * The default value for the {@code fairness} configuration attribute.
     * @see GenericObjectPool#getFairness()
     * @see GenericKeyedObjectPool#getFairness()
     */
    public static final boolean DEFAULT_FAIRNESS = false;

    /**
     * The default value for the {@code maxWait} configuration attribute.
     * @see GenericObjectPool#getMaxWaitMillis()
     * @see GenericKeyedObjectPool#getMaxWaitMillis()
     */
    public static final long DEFAULT_MAX_WAIT_MILLIS = -1L;

    /**
     * The default value for the {@code maxWait} configuration attribute.
     * @see GenericObjectPool#getMaxWaitMillis()
     * @see GenericKeyedObjectPool#getMaxWaitMillis()
     * @since 2.10.0
     */
    public static final Duration DEFAULT_MAX_WAIT = Duration.ofMillis(DEFAULT_MAX_WAIT_MILLIS);

    /**
     * The default value for the {@code minEvictableIdleTime}
     * configuration attribute.
     * @see GenericObjectPool#getMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTimeMillis()
     * @deprecated Use {@link #DEFAULT_MIN_EVICTABLE_IDLE_TIME}.
     */
    @Deprecated
    public static final long DEFAULT_MIN_EVICTABLE_IDLE_TIME_MILLIS =
            1000L * 60L * 30L;

    /**
     * The default value for the {@code minEvictableIdleTime}
     * configuration attribute.
     * @see GenericObjectPool#getMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTimeMillis()
     * @since 2.10.0
     */
    public static final Duration DEFAULT_MIN_EVICTABLE_IDLE_TIME =
            Duration.ofMillis(DEFAULT_MIN_EVICTABLE_IDLE_TIME_MILLIS);

    /**
     * The default value for the {@code softMinEvictableIdleTime}
     * configuration attribute.
     * @see GenericObjectPool#getSoftMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTimeMillis()
     * @deprecated Use {@link #DEFAULT_SOFT_MIN_EVICTABLE_IDLE_TIME}.
     */
    @Deprecated
    public static final long DEFAULT_SOFT_MIN_EVICTABLE_IDLE_TIME_MILLIS = -1;

    /**
     * The default value for the {@code softMinEvictableIdleTime}
     * configuration attribute.
     * @see GenericObjectPool#getSoftMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTime()
     * @since 2.10.0
     */
    public static final Duration DEFAULT_SOFT_MIN_EVICTABLE_IDLE_TIME =
            Duration.ofMillis(DEFAULT_SOFT_MIN_EVICTABLE_IDLE_TIME_MILLIS);

    /**
     * The default value for {@code evictorShutdownTimeout} configuration
     * attribute.
     * @see GenericObjectPool#getEvictorShutdownTimeoutMillis()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeoutMillis()
     * @deprecated Use {@link #DEFAULT_EVICTOR_SHUTDOWN_TIMEOUT}.
     */
    @Deprecated
    public static final long DEFAULT_EVICTOR_SHUTDOWN_TIMEOUT_MILLIS = 10L * 1000L;

    /**
     * The default value for {@code evictorShutdownTimeout} configuration
     * attribute.
     * @see GenericObjectPool#getEvictorShutdownTimeout()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeout()
     * @since 2.10.0
     */
    public static final Duration DEFAULT_EVICTOR_SHUTDOWN_TIMEOUT =
            Duration.ofMillis(DEFAULT_EVICTOR_SHUTDOWN_TIMEOUT_MILLIS);

    /**
     * The default value for the {@code numTestsPerEvictionRun} configuration
     * attribute.
     * @see GenericObjectPool#getNumTestsPerEvictionRun()
     * @see GenericKeyedObjectPool#getNumTestsPerEvictionRun()
     */
    public static final int DEFAULT_NUM_TESTS_PER_EVICTION_RUN = 3;

    /**
     * The default value for the {@code testOnCreate} configuration attribute.
     * @see GenericObjectPool#getTestOnCreate()
     * @see GenericKeyedObjectPool#getTestOnCreate()
     *
     * @since 2.2
     */
    public static final boolean DEFAULT_TEST_ON_CREATE = false;

    /**
     * The default value for the {@code testOnBorrow} configuration attribute.
     * @see GenericObjectPool#getTestOnBorrow()
     * @see GenericKeyedObjectPool#getTestOnBorrow()
     */
    public static final boolean DEFAULT_TEST_ON_BORROW = false;

    /**
     * The default value for the {@code testOnReturn} configuration attribute.
     * @see GenericObjectPool#getTestOnReturn()
     * @see GenericKeyedObjectPool#getTestOnReturn()
     */
    public static final boolean DEFAULT_TEST_ON_RETURN = false;

    /**
     * The default value for the {@code testWhileIdle} configuration attribute.
     * @see GenericObjectPool#getTestWhileIdle()
     * @see GenericKeyedObjectPool#getTestWhileIdle()
     */
    public static final boolean DEFAULT_TEST_WHILE_IDLE = false;

    /**
     * The default value for the {@code timeBetweenEvictionRuns}
     * configuration attribute.
     * @see GenericObjectPool#getTimeBetweenEvictionRunsMillis()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRunsMillis()
     * @deprecated Use {@link #DEFAULT_TIME_BETWEEN_EVICTION_RUNS}.
     */
    @Deprecated
    public static final long DEFAULT_TIME_BETWEEN_EVICTION_RUNS_MILLIS = -1L;

    /**
     * The default value for the {@code timeBetweenEvictionRuns}
     * configuration attribute.
     * @see GenericObjectPool#getTimeBetweenEvictionRunsMillis()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRunsMillis()
     */
    public static final Duration DEFAULT_TIME_BETWEEN_EVICTION_RUNS =
            Duration.ofMillis(DEFAULT_TIME_BETWEEN_EVICTION_RUNS_MILLIS);

    /**
     * The default value for the {@code blockWhenExhausted} configuration
     * attribute.
     * @see GenericObjectPool#getBlockWhenExhausted()
     * @see GenericKeyedObjectPool#getBlockWhenExhausted()
     */
    public static final boolean DEFAULT_BLOCK_WHEN_EXHAUSTED = true;

    /**
     * The default value for enabling JMX for pools created with a configuration
     * instance.
     */
    public static final boolean DEFAULT_JMX_ENABLE = true;

    /**
     * The default value for the prefix used to name JMX enabled pools created
     * with a configuration instance.
     * @see GenericObjectPool#getJmxName()
     * @see GenericKeyedObjectPool#getJmxName()
     */
    public static final String DEFAULT_JMX_NAME_PREFIX = "pool";

    /**
     * The default value for the base name to use to name JMX enabled pools
     * created with a configuration instance. The default is {@code null}
     * which means the pool will provide the base name to use.
     * @see GenericObjectPool#getJmxName()
     * @see GenericKeyedObjectPool#getJmxName()
     */
    public static final String DEFAULT_JMX_NAME_BASE = null;

    /**
     * The default value for the {@code evictionPolicyClassName} configuration
     * attribute.
     * @see GenericObjectPool#getEvictionPolicyClassName()
     * @see GenericKeyedObjectPool#getEvictionPolicyClassName()
     */
    public static final String DEFAULT_EVICTION_POLICY_CLASS_NAME = DefaultEvictionPolicy.class.getName();

    private boolean lifo = DEFAULT_LIFO;

    private boolean fairness = DEFAULT_FAIRNESS;

    private Duration maxWaitMillis = DEFAULT_MAX_WAIT;

    private Duration minEvictableIdleTime = DEFAULT_MIN_EVICTABLE_IDLE_TIME;

    private Duration evictorShutdownTimeout = DEFAULT_EVICTOR_SHUTDOWN_TIMEOUT;

    private Duration softMinEvictableIdleTime = DEFAULT_SOFT_MIN_EVICTABLE_IDLE_TIME;

    private int numTestsPerEvictionRun = DEFAULT_NUM_TESTS_PER_EVICTION_RUN;

    private EvictionPolicy<T> evictionPolicy; // Only 2.6.0 applications set this

    private String evictionPolicyClassName = DEFAULT_EVICTION_POLICY_CLASS_NAME;

    private boolean testOnCreate = DEFAULT_TEST_ON_CREATE;

    private boolean testOnBorrow = DEFAULT_TEST_ON_BORROW;

    private boolean testOnReturn = DEFAULT_TEST_ON_RETURN;

    private boolean testWhileIdle = DEFAULT_TEST_WHILE_IDLE;

    private Duration timeBetweenEvictionRuns = DEFAULT_TIME_BETWEEN_EVICTION_RUNS;

    private boolean blockWhenExhausted = DEFAULT_BLOCK_WHEN_EXHAUSTED;

    private boolean jmxEnabled = DEFAULT_JMX_ENABLE;

    // TODO Consider changing this to a single property for 3.x
    private String jmxNamePrefix = DEFAULT_JMX_NAME_PREFIX;

    private String jmxNameBase = DEFAULT_JMX_NAME_BASE;


    /**
     * Gets the value for the {@code blockWhenExhausted} configuration attribute
     * for pools created with this configuration instance.
     *
     * @return  The current setting of {@code blockWhenExhausted} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getBlockWhenExhausted()
     * @see GenericKeyedObjectPool#getBlockWhenExhausted()
     */
    public boolean getBlockWhenExhausted() {
        return blockWhenExhausted;
    }

    /**
     * Gets the value for the {@code evictionPolicyClass} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code evictionPolicyClass} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getEvictionPolicy()
     * @see GenericKeyedObjectPool#getEvictionPolicy()
     * @since 2.6.0
     */
    public EvictionPolicy<T> getEvictionPolicy() {
        return evictionPolicy;
    }

    /**
     * Gets the value for the {@code evictionPolicyClassName} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code evictionPolicyClassName} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getEvictionPolicyClassName()
     * @see GenericKeyedObjectPool#getEvictionPolicyClassName()
     */
    public String getEvictionPolicyClassName() {
        return evictionPolicyClassName;
    }

    /**
     * Gets the value for the {@code evictorShutdownTimeout} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code evictorShutdownTimeout} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getEvictorShutdownTimeout()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeout()
     * @since 2.10.0
     */
    public Duration getEvictorShutdownTimeout() {
        return evictorShutdownTimeout;
    }

    /**
     * Gets the value for the {@code evictorShutdownTimeout} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code evictorShutdownTimeout} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getEvictorShutdownTimeoutMillis()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeoutMillis()
     * @deprecated Use {@link #getEvictorShutdownTimeout()}.
     */
    @Deprecated
    public long getEvictorShutdownTimeoutMillis() {
        return evictorShutdownTimeout.toMillis();
    }

    /**
     * Gets the value for the {@code fairness} configuration attribute for pools
     * created with this configuration instance.
     *
     * @return  The current setting of {@code fairness} for this configuration
     *          instance
     *
     * @see GenericObjectPool#getFairness()
     * @see GenericKeyedObjectPool#getFairness()
     */
    public boolean getFairness() {
        return fairness;
    }

    /**
     * Gets the value of the flag that determines if JMX will be enabled for
     * pools created with this configuration instance.
     *
     * @return  The current setting of {@code jmxEnabled} for this configuration
     *          instance
     */
    public boolean getJmxEnabled() {
        return jmxEnabled;
    }

    /**
     * Gets the value of the JMX name base that will be used as part of the
     * name assigned to JMX enabled pools created with this configuration
     * instance. A value of {@code null} means that the pool will define
     * the JMX name base.
     *
     * @return  The current setting of {@code jmxNameBase} for this
     *          configuration instance
     */
    public String getJmxNameBase() {
        return jmxNameBase;
    }

    /**
     * Gets the value of the JMX name prefix that will be used as part of the
     * name assigned to JMX enabled pools created with this configuration
     * instance.
     *
     * @return  The current setting of {@code jmxNamePrefix} for this
     *          configuration instance
     */
    public String getJmxNamePrefix() {
        return jmxNamePrefix;
    }

    /**
     * Gets the value for the {@code lifo} configuration attribute for pools
     * created with this configuration instance.
     *
     * @return  The current setting of {@code lifo} for this configuration
     *          instance
     *
     * @see GenericObjectPool#getLifo()
     * @see GenericKeyedObjectPool#getLifo()
     */
    public boolean getLifo() {
        return lifo;
    }

    /**
     * Gets the value for the {@code maxWait} configuration attribute for pools
     * created with this configuration instance.
     *
     * @return  The current setting of {@code maxWait} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getMaxWaitMillis()
     * @see GenericKeyedObjectPool#getMaxWaitMillis()
     */
    public long getMaxWaitMillis() {
        return maxWaitMillis.toMillis();
    }

    /**
     * Gets the value for the {@code minEvictableIdleTime} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code minEvictableIdleTime} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTime()
     * @since 2.10.0
     */
    public Duration getMinEvictableIdleTime() {
        return minEvictableIdleTime;
    }

    /**
     * Gets the value for the {@code minEvictableIdleTime} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code minEvictableIdleTime} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTimeMillis()
     * @deprecated Use {@link #getMinEvictableIdleTime()}.
     */
    @Deprecated
    public long getMinEvictableIdleTimeMillis() {
        return minEvictableIdleTime.toMillis();
    }

    /**
     * Gets the value for the {@code numTestsPerEvictionRun} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code numTestsPerEvictionRun} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getNumTestsPerEvictionRun()
     * @see GenericKeyedObjectPool#getNumTestsPerEvictionRun()
     */
    public int getNumTestsPerEvictionRun() {
        return numTestsPerEvictionRun;
    }

    /**
     * Gets the value for the {@code softMinEvictableIdleTime}
     * configuration attribute for pools created with this configuration
     * instance.
     *
     * @return  The current setting of {@code softMinEvictableIdleTime}
     *          for this configuration instance
     *
     * @see GenericObjectPool#getSoftMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTime()
     * @since 2.10.0
     */
    public Duration getSoftMinEvictableIdleTime() {
        return softMinEvictableIdleTime;
    }

    /**
     * Gets the value for the {@code softMinEvictableIdleTime}
     * configuration attribute for pools created with this configuration
     * instance.
     *
     * @return  The current setting of {@code softMinEvictableIdleTime}
     *          for this configuration instance
     *
     * @see GenericObjectPool#getSoftMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTime()
     */
    @Deprecated
    public long getSoftMinEvictableIdleTimeMillis() {
        return softMinEvictableIdleTime.toMillis();
    }

    /**
     * Gets the value for the {@code testOnBorrow} configuration attribute for
     * pools created with this configuration instance.
     *
     * @return  The current setting of {@code testOnBorrow} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getTestOnBorrow()
     * @see GenericKeyedObjectPool#getTestOnBorrow()
     */
    public boolean getTestOnBorrow() {
        return testOnBorrow;
    }

    /**
     * Gets the value for the {@code testOnCreate} configuration attribute for
     * pools created with this configuration instance.
     *
     * @return  The current setting of {@code testOnCreate} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getTestOnCreate()
     * @see GenericKeyedObjectPool#getTestOnCreate()
     *
     * @since 2.2
     */
    public boolean getTestOnCreate() {
        return testOnCreate;
    }

    /**
     * Gets the value for the {@code testOnReturn} configuration attribute for
     * pools created with this configuration instance.
     *
     * @return  The current setting of {@code testOnReturn} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getTestOnReturn()
     * @see GenericKeyedObjectPool#getTestOnReturn()
     */
    public boolean getTestOnReturn() {
        return testOnReturn;
    }

    /**
     * Gets the value for the {@code testWhileIdle} configuration attribute for
     * pools created with this configuration instance.
     *
     * @return  The current setting of {@code testWhileIdle} for this
     *          configuration instance
     *
     * @see GenericObjectPool#getTestWhileIdle()
     * @see GenericKeyedObjectPool#getTestWhileIdle()
     */
    public boolean getTestWhileIdle() {
        return testWhileIdle;
    }

    /**
     * Gets the value for the {@code timeBetweenEvictionRuns} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code timeBetweenEvictionRuns} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getTimeBetweenEvictionRuns()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRuns()
     * @since 2.10.0
     */
    public Duration getTimeBetweenEvictionRuns() {
        return timeBetweenEvictionRuns;
    }

    /**
     * Gets the value for the {@code timeBetweenEvictionRuns} configuration
     * attribute for pools created with this configuration instance.
     *
     * @return  The current setting of {@code timeBetweenEvictionRuns} for
     *          this configuration instance
     *
     * @see GenericObjectPool#getTimeBetweenEvictionRunsMillis()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRunsMillis()
     * @deprecated Use {@link #getTimeBetweenEvictionRuns()}.
     */
    @Deprecated
    public long getTimeBetweenEvictionRunsMillis() {
        return timeBetweenEvictionRuns.toMillis();
    }

    /**
     * Sets the value for the {@code blockWhenExhausted} configuration attribute
     * for pools created with this configuration instance.
     *
     * @param blockWhenExhausted The new setting of {@code blockWhenExhausted}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getBlockWhenExhausted()
     * @see GenericKeyedObjectPool#getBlockWhenExhausted()
     */
    public void setBlockWhenExhausted(final boolean blockWhenExhausted) {
        this.blockWhenExhausted = blockWhenExhausted;
    }

    /**
     * Sets the value for the {@code evictionPolicyClass} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param evictionPolicy The new setting of
     *        {@code evictionPolicyClass} for this configuration instance
     *
     * @see GenericObjectPool#getEvictionPolicy()
     * @see GenericKeyedObjectPool#getEvictionPolicy()
     * @since 2.6.0
     */
    public void setEvictionPolicy(final EvictionPolicy<T> evictionPolicy) {
        this.evictionPolicy = evictionPolicy;
    }

    /**
     * Sets the value for the {@code evictionPolicyClassName} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param evictionPolicyClassName The new setting of
     *        {@code evictionPolicyClassName} for this configuration instance
     *
     * @see GenericObjectPool#getEvictionPolicyClassName()
     * @see GenericKeyedObjectPool#getEvictionPolicyClassName()
     */
    public void setEvictionPolicyClassName(final String evictionPolicyClassName) {
        this.evictionPolicyClassName = evictionPolicyClassName;
    }

    /**
     * Sets the value for the {@code evictorShutdownTimeout} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param evictorShutdownTimeoutMillis The new setting of
     *        {@code evictorShutdownTimeout} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getEvictorShutdownTimeout()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeout()
     * @since 2.10.0
     */
    public void setEvictorShutdownTimeoutMillis(final Duration evictorShutdownTimeoutMillis) {
        this.evictorShutdownTimeout = evictorShutdownTimeoutMillis;
    }

    /**
     * Sets the value for the {@code evictorShutdownTimeout} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param evictorShutdownTimeoutMillis The new setting of
     *        {@code evictorShutdownTimeout} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getEvictorShutdownTimeoutMillis()
     * @see GenericKeyedObjectPool#getEvictorShutdownTimeoutMillis()
     * @deprecated Use {@link #setEvictorShutdownTimeoutMillis(Duration)}.
     */
    @Deprecated
    public void setEvictorShutdownTimeoutMillis(final long evictorShutdownTimeoutMillis) {
        this.evictorShutdownTimeout = Duration.ofMillis(evictorShutdownTimeoutMillis);
    }

    /**
     * Sets the value for the {@code fairness} configuration attribute for pools
     * created with this configuration instance.
     *
     * @param fairness The new setting of {@code fairness}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getFairness()
     * @see GenericKeyedObjectPool#getFairness()
     */
    public void setFairness(final boolean fairness) {
        this.fairness = fairness;
    }

    /**
     * Sets the value of the flag that determines if JMX will be enabled for
     * pools created with this configuration instance.
     *
     * @param jmxEnabled The new setting of {@code jmxEnabled}
     *        for this configuration instance
     */
    public void setJmxEnabled(final boolean jmxEnabled) {
        this.jmxEnabled = jmxEnabled;
    }

    /**
     * Sets the value of the JMX name base that will be used as part of the
     * name assigned to JMX enabled pools created with this configuration
     * instance. A value of {@code null} means that the pool will define
     * the JMX name base.
     *
     * @param jmxNameBase The new setting of {@code jmxNameBase}
     *        for this configuration instance
     */
    public void setJmxNameBase(final String jmxNameBase) {
        this.jmxNameBase = jmxNameBase;
    }

    /**
     * Sets the value of the JMX name prefix that will be used as part of the
     * name assigned to JMX enabled pools created with this configuration
     * instance.
     *
     * @param jmxNamePrefix The new setting of {@code jmxNamePrefix}
     *        for this configuration instance
     */
    public void setJmxNamePrefix(final String jmxNamePrefix) {
        this.jmxNamePrefix = jmxNamePrefix;
    }

    /**
     * Sets the value for the {@code lifo} configuration attribute for pools
     * created with this configuration instance.
     *
     * @param lifo The new setting of {@code lifo}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getLifo()
     * @see GenericKeyedObjectPool#getLifo()
     */
    public void setLifo(final boolean lifo) {
        this.lifo = lifo;
    }

    /**
     * Sets the value for the {@code maxWait} configuration attribute for pools
     * created with this configuration instance.
     *
     * @param maxWaitMillis The new setting of {@code maxWaitMillis}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getMaxWaitMillis()
     * @see GenericKeyedObjectPool#getMaxWaitMillis()
     */
    public void setMaxWaitMillis(final long maxWaitMillis) {
        this.maxWaitMillis = Duration.ofMillis(maxWaitMillis);
    }

    /**
     * Sets the value for the {@code minEvictableIdleTime} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param minEvictableIdleTime The new setting of
     *        {@code minEvictableIdleTime} for this configuration instance
     *
     * @see GenericObjectPool#getMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTime()
     * @since 2.10.0
     */
    public void setMinEvictableIdleTime(final Duration minEvictableIdleTime) {
        this.minEvictableIdleTime = minEvictableIdleTime;
    }

    /**
     * Sets the value for the {@code minEvictableIdleTime} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param minEvictableIdleTimeMillis The new setting of
     *        {@code minEvictableIdleTime} for this configuration instance
     *
     * @see GenericObjectPool#getMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getMinEvictableIdleTimeMillis()
     * @deprecated Use {@link #setSoftMinEvictableIdleTime(Duration)}.
     */
    @Deprecated
    public void setMinEvictableIdleTimeMillis(final long minEvictableIdleTimeMillis) {
        this.minEvictableIdleTime = Duration.ofMillis(minEvictableIdleTimeMillis);
    }

    /**
     * Sets the value for the {@code numTestsPerEvictionRun} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param numTestsPerEvictionRun The new setting of
     *        {@code numTestsPerEvictionRun} for this configuration instance
     *
     * @see GenericObjectPool#getNumTestsPerEvictionRun()
     * @see GenericKeyedObjectPool#getNumTestsPerEvictionRun()
     */
    public void setNumTestsPerEvictionRun(final int numTestsPerEvictionRun) {
        this.numTestsPerEvictionRun = numTestsPerEvictionRun;
    }

    /**
     * Sets the value for the {@code softMinEvictableIdleTime}
     * configuration attribute for pools created with this configuration
     * instance.
     *
     * @param softMinEvictableIdleTime The new setting of
     *        {@code softMinEvictableIdleTime} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getSoftMinEvictableIdleTime()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTime()
     * @since 2.10.0
     */
    public void setSoftMinEvictableIdleTime(final Duration softMinEvictableIdleTime) {
        this.softMinEvictableIdleTime = softMinEvictableIdleTime;
    }

    /**
     * Sets the value for the {@code softMinEvictableIdleTime}
     * configuration attribute for pools created with this configuration
     * instance.
     *
     * @param softMinEvictableIdleTimeMillis The new setting of
     *        {@code softMinEvictableIdleTime} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getSoftMinEvictableIdleTimeMillis()
     * @see GenericKeyedObjectPool#getSoftMinEvictableIdleTimeMillis()
     * @deprecated Use {@link #setSoftMinEvictableIdleTime(Duration)}.
     */
    @Deprecated
    public void setSoftMinEvictableIdleTimeMillis(
            final long softMinEvictableIdleTimeMillis) {
        this.softMinEvictableIdleTime = Duration.ofMillis(softMinEvictableIdleTimeMillis);
    }

    /**
     * Sets the value for the {@code testOnBorrow} configuration attribute for
     * pools created with this configuration instance.
     *
     * @param testOnBorrow The new setting of {@code testOnBorrow}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getTestOnBorrow()
     * @see GenericKeyedObjectPool#getTestOnBorrow()
     */
    public void setTestOnBorrow(final boolean testOnBorrow) {
        this.testOnBorrow = testOnBorrow;
    }

    /**
     * Sets the value for the {@code testOnCreate} configuration attribute for
     * pools created with this configuration instance.
     *
     * @param testOnCreate The new setting of {@code testOnCreate}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getTestOnCreate()
     * @see GenericKeyedObjectPool#getTestOnCreate()
     *
     * @since 2.2
     */
    public void setTestOnCreate(final boolean testOnCreate) {
        this.testOnCreate = testOnCreate;
    }

    /**
     * Sets the value for the {@code testOnReturn} configuration attribute for
     * pools created with this configuration instance.
     *
     * @param testOnReturn The new setting of {@code testOnReturn}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getTestOnReturn()
     * @see GenericKeyedObjectPool#getTestOnReturn()
     */
    public void setTestOnReturn(final boolean testOnReturn) {
        this.testOnReturn = testOnReturn;
    }

    /**
     * Sets the value for the {@code testWhileIdle} configuration attribute for
     * pools created with this configuration instance.
     *
     * @param testWhileIdle The new setting of {@code testWhileIdle}
     *        for this configuration instance
     *
     * @see GenericObjectPool#getTestWhileIdle()
     * @see GenericKeyedObjectPool#getTestWhileIdle()
     */
    public void setTestWhileIdle(final boolean testWhileIdle) {
        this.testWhileIdle = testWhileIdle;
    }

    /**
     * Sets the value for the {@code timeBetweenEvictionRuns} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param timeBetweenEvictionRunsMillis The new setting of
     *        {@code timeBetweenEvictionRuns} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getTimeBetweenEvictionRuns()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRuns()
     * @since 2.10.0
     */
    public void setTimeBetweenEvictionRuns(final Duration timeBetweenEvictionRunsMillis) {
        this.timeBetweenEvictionRuns = timeBetweenEvictionRunsMillis;
    }

    /**
     * Sets the value for the {@code timeBetweenEvictionRuns} configuration
     * attribute for pools created with this configuration instance.
     *
     * @param timeBetweenEvictionRunsMillis The new setting of
     *        {@code timeBetweenEvictionRuns} for this configuration
     *        instance
     *
     * @see GenericObjectPool#getTimeBetweenEvictionRunsMillis()
     * @see GenericKeyedObjectPool#getTimeBetweenEvictionRunsMillis()
     * @deprecated Use {@link #setTimeBetweenEvictionRuns(Duration)}.
     */
    @Deprecated
    public void setTimeBetweenEvictionRunsMillis(final long timeBetweenEvictionRunsMillis) {
        this.timeBetweenEvictionRuns = Duration.ofMillis(timeBetweenEvictionRunsMillis);
    }

    @Override
    protected void toStringAppendFields(final StringBuilder builder) {
        builder.append("lifo=");
        builder.append(lifo);
        builder.append(", fairness=");
        builder.append(fairness);
        builder.append(", maxWaitMillis=");
        builder.append(maxWaitMillis);
        builder.append(", minEvictableIdleTime=");
        builder.append(minEvictableIdleTime);
        builder.append(", softMinEvictableIdleTime=");
        builder.append(softMinEvictableIdleTime);
        builder.append(", numTestsPerEvictionRun=");
        builder.append(numTestsPerEvictionRun);
        builder.append(", evictionPolicyClassName=");
        builder.append(evictionPolicyClassName);
        builder.append(", testOnCreate=");
        builder.append(testOnCreate);
        builder.append(", testOnBorrow=");
        builder.append(testOnBorrow);
        builder.append(", testOnReturn=");
        builder.append(testOnReturn);
        builder.append(", testWhileIdle=");
        builder.append(testWhileIdle);
        builder.append(", timeBetweenEvictionRuns=");
        builder.append(timeBetweenEvictionRuns);
        builder.append(", blockWhenExhausted=");
        builder.append(blockWhenExhausted);
        builder.append(", jmxEnabled=");
        builder.append(jmxEnabled);
        builder.append(", jmxNamePrefix=");
        builder.append(jmxNamePrefix);
        builder.append(", jmxNameBase=");
        builder.append(jmxNameBase);
    }
}
```

## 5、实现借还规则

我们所有应有的类，已充分准备完成，接下来我们看一看具体通用的实现规则

```java
/*
 * 本抽象类作用：1、默认规则实现，2、暴露给用户创建池中物的方式
 */
public abstract class BasePooledObjectFactory<T> extends BaseObject implements PooledObjectFactory<T> {
    /**
     *  无具体实现
     */
    @Override
    public void activateObject(final PooledObject<T> p) throws Exception {
        // The default implementation is a no-op.
    }

    /**
     * 创建实体，需要用户自定义实现
     */
    public abstract T create() throws Exception;

    /**
     * 无具体实现
     */
    @Override
    public void destroyObject(final PooledObject<T> p)
        throws Exception  {
    }

    @Override
    public PooledObject<T> makeObject() throws Exception {
      // 分两步，1、创建出来 2、包装成池中物
        return wrap(create());
    }

    /**
     * 无具体实现
     */
    @Override
    public void passivateObject(final PooledObject<T> p)
        throws Exception {
    }

    /**
     * 无具体实现
     */
    @Override
    public boolean validateObject(final PooledObject<T> p) {
        return true;
    }

    /**
     * 将具体实体包装成池中物
     */
    public abstract PooledObject<T> wrap(T obj);
}
```

借还规则实现（以下是代码片段）

> 通用池

```java

/**
 * @since 2.0
 */
public class GenericObjectPool<T> extends BaseGenericObjectPool<T>
        implements ObjectPool<T>, GenericObjectPoolMXBean, UsageTracking<T> {

    private static final Duration DEFAULT_REMOVE_ABANDONED_TIMEOUT = Duration.ofSeconds(Integer.MAX_VALUE);

    // JMX specific attributes
    private static final String ONAME_BASE =
        "org.apache.commons.pool2:type=GenericObjectPool,name=";

    private volatile String factoryType = null;

    private volatile int maxIdle = GenericObjectPoolConfig.DEFAULT_MAX_IDLE;

    private volatile int minIdle = GenericObjectPoolConfig.DEFAULT_MIN_IDLE;

    private final PooledObjectFactory<T> factory;

    /*
     * All of the objects currently associated with this pool in any state. It
     * excludes objects that have been destroyed. The size of
     * {@link #allObjects} will always be less than or equal to {@link
     * #_maxActive}. Map keys are pooled objects, values are the PooledObject
     * wrappers used internally by the pool.
     */
    private final Map<IdentityWrapper<T>, PooledObject<T>> allObjects =
        new ConcurrentHashMap<>();

    /*
     * The combined count of the currently created objects and those in the
     * process of being created. Under load, it may exceed {@link #_maxActive}
     * if multiple threads try and create a new object at the same time but
     * {@link #create()} will ensure that there are never more than
     * {@link #_maxActive} objects created at any one time.
     */
    private final AtomicLong createCount = new AtomicLong(0);

    private long makeObjectCount;

    private final Object makeObjectCountLock = new Object();

    private final LinkedBlockingDeque<PooledObject<T>> idleObjects;

    // Additional configuration properties for abandoned object tracking
    private volatile AbandonedConfig abandonedConfig;

    /**
     * Creates a new {@code GenericObjectPool} using defaults from
     * {@link GenericObjectPoolConfig}.
     *
     * @param factory The object factory to be used to create object instances
     *                used by this pool
     */
    public GenericObjectPool(final PooledObjectFactory<T> factory) {
        this(factory, new GenericObjectPoolConfig<>());
    }

    /**
     * Creates a new {@code GenericObjectPool} using a specific
     * configuration.
     *
     * @param factory   The object factory to be used to create object instances
     *                  used by this pool
     * @param config    The configuration to use for this pool instance. The
     *                  configuration is used by value. Subsequent changes to
     *                  the configuration object will not be reflected in the
     *                  pool.
     */
    public GenericObjectPool(final PooledObjectFactory<T> factory,
            final GenericObjectPoolConfig<T> config) {

        super(config, ONAME_BASE, config.getJmxNamePrefix());

        if (factory == null) {
            jmxUnregister(); // tidy up
            throw new IllegalArgumentException("factory may not be null");
        }
        this.factory = factory;

        idleObjects = new LinkedBlockingDeque<>(config.getFairness());

        setConfig(config);
    }

    /**
     * Creates a new {@code GenericObjectPool} that tracks and destroys
     * objects that are checked out, but never returned to the pool.
     *
     * @param factory   The object factory to be used to create object instances
     *                  used by this pool
     * @param config    The base pool configuration to use for this pool instance.
     *                  The configuration is used by value. Subsequent changes to
     *                  the configuration object will not be reflected in the
     *                  pool.
     * @param abandonedConfig  Configuration for abandoned object identification
     *                         and removal.  The configuration is used by value.
     */
    public GenericObjectPool(final PooledObjectFactory<T> factory,
            final GenericObjectPoolConfig<T> config, final AbandonedConfig abandonedConfig) {
        this(factory, config);
        setAbandonedConfig(abandonedConfig);
    }

    /**
     * Adds the provided wrapped pooled object to the set of idle objects for
     * this pool. The object must already be part of the pool.  If {@code p}
     * is null, this is a no-op (no exception, but no impact on the pool).
     *
     * @param p The object to make idle
     *
     * @throws Exception If the factory fails to passivate the object
     */
    private void addIdleObject(final PooledObject<T> p) throws Exception {
        if (p != null) {
            factory.passivateObject(p);
            if (getLifo()) {
                idleObjects.addFirst(p);
            } else {
                idleObjects.addLast(p);
            }
        }
    }

    /**
     * Creates an object, and place it into the pool. addObject() is useful for
     * "pre-loading" a pool with idle objects.
     * <p>
     * If there is no capacity available to add to the pool, this is a no-op
     * (no exception, no impact to the pool). </p>
     */
    @Override
    public void addObject() throws Exception {
        assertOpen();
        if (factory == null) {
            throw new IllegalStateException(
                    "Cannot add objects without a factory.");
        }
        final PooledObject<T> p = create();
        addIdleObject(p);
    }

    /**
     * Equivalent to <code>{@link #borrowObject(long)
     * borrowObject}({@link #getMaxWaitMillis()})</code>.
     * <p>
     * {@inheritDoc}
     * </p>
     */
    @Override
    public T borrowObject() throws Exception {
        return borrowObject(getMaxWaitMillis());
    }

    /**
     * Borrows an object from the pool using the specific waiting time which only
     * applies if {@link #getBlockWhenExhausted()} is true.
     * <p>
     * If there is one or more idle instance available in the pool, then an
     * idle instance will be selected based on the value of {@link #getLifo()},
     * activated and returned. If activation fails, or {@link #getTestOnBorrow()
     * testOnBorrow} is set to {@code true} and validation fails, the
     * instance is destroyed and the next available instance is examined. This
     * continues until either a valid instance is returned or there are no more
     * idle instances available.
     * </p>
     * <p>
     * If there are no idle instances available in the pool, behavior depends on
     * the {@link #getMaxTotal() maxTotal}, (if applicable)
     * {@link #getBlockWhenExhausted()} and the value passed in to the
     * {@code borrowMaxWaitMillis} parameter. If the number of instances
     * checked out from the pool is less than {@code maxTotal,} a new
     * instance is created, activated and (if applicable) validated and returned
     * to the caller. If validation fails, a {@code NoSuchElementException}
     * is thrown.
     * </p>
     * <p>
     * If the pool is exhausted (no available idle instances and no capacity to
     * create new ones), this method will either block (if
     * {@link #getBlockWhenExhausted()} is true) or throw a
     * {@code NoSuchElementException} (if
     * {@link #getBlockWhenExhausted()} is false). The length of time that this
     * method will block when {@link #getBlockWhenExhausted()} is true is
     * determined by the value passed in to the {@code borrowMaxWaitMillis}
     * parameter.
     * </p>
     * <p>
     * When the pool is exhausted, multiple calling threads may be
     * simultaneously blocked waiting for instances to become available. A
     * "fairness" algorithm has been implemented to ensure that threads receive
     * available instances in request arrival order.
     * </p>
     *
     * @param borrowMaxWait The time to wait for an object
     *                            to become available
     *
     * @return object instance from the pool
     *
     * @throws NoSuchElementException if an instance cannot be returned
     *
     * @throws Exception if an object instance cannot be returned due to an
     *                   error
     * @since 2.10.0
     */
    public T borrowObject(final Duration borrowMaxWait) throws Exception {
        assertOpen();

        final AbandonedConfig ac = this.abandonedConfig;
        if (ac != null && ac.getRemoveAbandonedOnBorrow() && (getNumIdle() < 2) &&
                (getNumActive() > getMaxTotal() - 3)) {
            removeAbandoned(ac);
        }

        PooledObject<T> p = null;

        // Get local copy of current config so it is consistent for entire
        // method execution
        final boolean blockWhenExhausted = getBlockWhenExhausted();

        boolean create;
        final long waitTimeMillis = System.currentTimeMillis();

        while (p == null) {
            create = false;
            p = idleObjects.pollFirst();
            if (p == null) {
                p = create();
                if (p != null) {
                    create = true;
                }
            }
            if (blockWhenExhausted) {
                if (p == null) {
                    if (borrowMaxWait.isNegative()) {
                        p = idleObjects.takeFirst();
                    } else {
                        p = idleObjects.pollFirst(borrowMaxWait);
                    }
                }
                if (p == null) {
                    throw new NoSuchElementException("Timeout waiting for idle object");
                }
            } else if (p == null) {
                throw new NoSuchElementException("Pool exhausted");
            }
            if (!p.allocate()) {
                p = null;
            }

            if (p != null) {
                try {
                    factory.activateObject(p);
                } catch (final Exception e) {
                    try {
                        destroy(p, DestroyMode.NORMAL);
                    } catch (final Exception e1) {
                        // Ignore - activation failure is more important
                    }
                    p = null;
                    if (create) {
                        final NoSuchElementException nsee = new NoSuchElementException("Unable to activate object");
                        nsee.initCause(e);
                        throw nsee;
                    }
                }
                if (p != null && getTestOnBorrow()) {
                    boolean validate = false;
                    Throwable validationThrowable = null;
                    try {
                        validate = factory.validateObject(p);
                    } catch (final Throwable t) {
                        PoolUtils.checkRethrow(t);
                        validationThrowable = t;
                    }
                    if (!validate) {
                        try {
                            destroy(p, DestroyMode.NORMAL);
                            destroyedByBorrowValidationCount.incrementAndGet();
                        } catch (final Exception e) {
                            // Ignore - validation failure is more important
                        }
                        p = null;
                        if (create) {
                            final NoSuchElementException nsee = new NoSuchElementException("Unable to validate object");
                            nsee.initCause(validationThrowable);
                            throw nsee;
                        }
                    }
                }
            }
        }

        updateStatsBorrow(p, Duration.ofMillis(System.currentTimeMillis() - waitTimeMillis));

        return p.getObject();
    }

    /**
     * Borrows an object from the pool using the specific waiting time which only
     * applies if {@link #getBlockWhenExhausted()} is true.
     * <p>
     * If there is one or more idle instance available in the pool, then an
     * idle instance will be selected based on the value of {@link #getLifo()},
     * activated and returned. If activation fails, or {@link #getTestOnBorrow()
     * testOnBorrow} is set to {@code true} and validation fails, the
     * instance is destroyed and the next available instance is examined. This
     * continues until either a valid instance is returned or there are no more
     * idle instances available.
     * </p>
     * <p>
     * If there are no idle instances available in the pool, behavior depends on
     * the {@link #getMaxTotal() maxTotal}, (if applicable)
     * {@link #getBlockWhenExhausted()} and the value passed in to the
     * {@code borrowMaxWaitMillis} parameter. If the number of instances
     * checked out from the pool is less than {@code maxTotal,} a new
     * instance is created, activated and (if applicable) validated and returned
     * to the caller. If validation fails, a {@code NoSuchElementException}
     * is thrown.
     * </p>
     * <p>
     * If the pool is exhausted (no available idle instances and no capacity to
     * create new ones), this method will either block (if
     * {@link #getBlockWhenExhausted()} is true) or throw a
     * {@code NoSuchElementException} (if
     * {@link #getBlockWhenExhausted()} is false). The length of time that this
     * method will block when {@link #getBlockWhenExhausted()} is true is
     * determined by the value passed in to the {@code borrowMaxWaitMillis}
     * parameter.
     * </p>
     * <p>
     * When the pool is exhausted, multiple calling threads may be
     * simultaneously blocked waiting for instances to become available. A
     * "fairness" algorithm has been implemented to ensure that threads receive
     * available instances in request arrival order.
     * </p>
     *
     * @param borrowMaxWaitMillis The time to wait in milliseconds for an object
     *                            to become available
     *
     * @return object instance from the pool
     *
     * @throws NoSuchElementException if an instance cannot be returned
     *
     * @throws Exception if an object instance cannot be returned due to an
     *                   error
     */
    public T borrowObject(final long borrowMaxWaitMillis) throws Exception {
        return borrowObject(Duration.ofMillis(borrowMaxWaitMillis));
    }

    /**
     * Clears any objects sitting idle in the pool by removing them from the
     * idle instance pool and then invoking the configured
     * {@link PooledObjectFactory#destroyObject(PooledObject)} method on each
     * idle instance.
     * <p>
     * Implementation notes:
     * </p>
     * <ul>
     * <li>This method does not destroy or effect in any way instances that are
     * checked out of the pool when it is invoked.</li>
     * <li>Invoking this method does not prevent objects being returned to the
     * idle instance pool, even during its execution. Additional instances may
     * be returned while removed items are being destroyed.</li>
     * <li>Exceptions encountered destroying idle instances are swallowed
     * but notified via a {@link SwallowedExceptionListener}.</li>
     * </ul>
     */
    @Override
    public void clear() {
        PooledObject<T> p = idleObjects.poll();

        while (p != null) {
            try {
                destroy(p, DestroyMode.NORMAL);
            } catch (final Exception e) {
                swallowException(e);
            }
            p = idleObjects.poll();
        }
    }

    /**
     * Closes the pool. Once the pool is closed, {@link #borrowObject()} will
     * fail with IllegalStateException, but {@link #returnObject(Object)} and
     * {@link #invalidateObject(Object)} will continue to work, with returned
     * objects destroyed on return.
     * <p>
     * Destroys idle instances in the pool by invoking {@link #clear()}.
     * </p>
     */
    @Override
    public void close() {
        if (isClosed()) {
            return;
        }

        synchronized (closeLock) {
            if (isClosed()) {
                return;
            }

            // Stop the evictor before the pool is closed since evict() calls
            // assertOpen()
            stopEvictor();

            closed = true;
            // This clear removes any idle objects
            clear();

            jmxUnregister();

            // Release any threads that were waiting for an object
            idleObjects.interuptTakeWaiters();
        }
    }

    /**
     * Attempts to create a new wrapped pooled object.
     * <p>
     * If there are {@link #getMaxTotal()} objects already in circulation
     * or in process of being created, this method returns null.
     * </p>
     *
     * @return The new wrapped pooled object
     *
     * @throws Exception if the object factory's {@code makeObject} fails
     */
    private PooledObject<T> create() throws Exception {
        int localMaxTotal = getMaxTotal();
        // This simplifies the code later in this method
        if (localMaxTotal < 0) {
            localMaxTotal = Integer.MAX_VALUE;
        }

        final long localStartTimeMillis = System.currentTimeMillis();
        final long localMaxWaitTimeMillis = Math.max(getMaxWaitMillis(), 0);

        // Flag that indicates if create should:
        // - TRUE:  call the factory to create an object
        // - FALSE: return null
        // - null:  loop and re-test the condition that determines whether to
        //          call the factory
        Boolean create = null;
        while (create == null) {
            synchronized (makeObjectCountLock) {
                final long newCreateCount = createCount.incrementAndGet();
                if (newCreateCount > localMaxTotal) {
                    // The pool is currently at capacity or in the process of
                    // making enough new objects to take it to capacity.
                    createCount.decrementAndGet();
                    if (makeObjectCount == 0) {
                        // There are no makeObject() calls in progress so the
                        // pool is at capacity. Do not attempt to create a new
                        // object. Return and wait for an object to be returned
                        create = Boolean.FALSE;
                    } else {
                        // There are makeObject() calls in progress that might
                        // bring the pool to capacity. Those calls might also
                        // fail so wait until they complete and then re-test if
                        // the pool is at capacity or not.
                        makeObjectCountLock.wait(localMaxWaitTimeMillis);
                    }
                } else {
                    // The pool is not at capacity. Create a new object.
                    makeObjectCount++;
                    create = Boolean.TRUE;
                }
            }

            // Do not block more if maxWaitTimeMillis is set.
            if (create == null &&
                (localMaxWaitTimeMillis > 0 &&
                 System.currentTimeMillis() - localStartTimeMillis >= localMaxWaitTimeMillis)) {
                create = Boolean.FALSE;
            }
        }

        if (!create.booleanValue()) {
            return null;
        }

        final PooledObject<T> p;
        try {
            p = factory.makeObject();
            if (getTestOnCreate() && !factory.validateObject(p)) {
                createCount.decrementAndGet();
                return null;
            }
        } catch (final Throwable e) {
            createCount.decrementAndGet();
            throw e;
        } finally {
            synchronized (makeObjectCountLock) {
                makeObjectCount--;
                makeObjectCountLock.notifyAll();
            }
        }

        final AbandonedConfig ac = this.abandonedConfig;
        if (ac != null && ac.getLogAbandoned()) {
            p.setLogAbandoned(true);
            p.setRequireFullStackTrace(ac.getRequireFullStackTrace());
        }

        createdCount.incrementAndGet();
        allObjects.put(new IdentityWrapper<>(p.getObject()), p);
        return p;
    }

    /**
     * Destroys a wrapped pooled object.
     *
     * @param toDestroy The wrapped pooled object to destroy
     * @param mode DestroyMode context provided to the factory
     *
     * @throws Exception If the factory fails to destroy the pooled object
     *                   cleanly
     */
    private void destroy(final PooledObject<T> toDestroy, final DestroyMode mode) throws Exception {
        toDestroy.invalidate();
        idleObjects.remove(toDestroy);
        allObjects.remove(new IdentityWrapper<>(toDestroy.getObject()));
        try {
            factory.destroyObject(toDestroy, mode);
        } finally {
            destroyedCount.incrementAndGet();
            createCount.decrementAndGet();
        }
    }

    /**
     * Tries to ensure that {@code idleCount} idle instances exist in the pool.
     * <p>
     * Creates and adds idle instances until either {@link #getNumIdle()} reaches {@code idleCount}
     * or the total number of objects (idle, checked out, or being created) reaches
     * {@link #getMaxTotal()}. If {@code always} is false, no instances are created unless
     * there are threads waiting to check out instances from the pool.
     * </p>
     *
     * @param idleCount the number of idle instances desired
     * @param always true means create instances even if the pool has no threads waiting
     * @throws Exception if the factory's makeObject throws
     */
    private void ensureIdle(final int idleCount, final boolean always) throws Exception {
        if (idleCount < 1 || isClosed() || (!always && !idleObjects.hasTakeWaiters())) {
            return;
        }

        while (idleObjects.size() < idleCount) {
            final PooledObject<T> p = create();
            if (p == null) {
                // Can't create objects, no reason to think another call to
                // create will work. Give up.
                break;
            }
            if (getLifo()) {
                idleObjects.addFirst(p);
            } else {
                idleObjects.addLast(p);
            }
        }
        if (isClosed()) {
            // Pool closed while object was being added to idle objects.
            // Make sure the returned object is destroyed rather than left
            // in the idle object pool (which would effectively be a leak)
            clear();
        }
    }

    @Override
    void ensureMinIdle() throws Exception {
        ensureIdle(getMinIdle(), true);
    }

    /**
     * {@inheritDoc}
     * <p>
     * Successive activations of this method examine objects in sequence,
     * cycling through objects in oldest-to-youngest order.
     * </p>
     */
    @Override
    public void evict() throws Exception {
        assertOpen();

        if (!idleObjects.isEmpty()) {

            PooledObject<T> underTest = null;
            final EvictionPolicy<T> evictionPolicy = getEvictionPolicy();

            synchronized (evictionLock) {
                final EvictionConfig evictionConfig = new EvictionConfig(
                        getMinEvictableIdleTime(),
                        getSoftMinEvictableIdleTime(),
                        getMinIdle());

                final boolean testWhileIdle = getTestWhileIdle();

                for (int i = 0, m = getNumTests(); i < m; i++) {
                    if (evictionIterator == null || !evictionIterator.hasNext()) {
                        evictionIterator = new EvictionIterator(idleObjects);
                    }
                    if (!evictionIterator.hasNext()) {
                        // Pool exhausted, nothing to do here
                        return;
                    }

                    try {
                        underTest = evictionIterator.next();
                    } catch (final NoSuchElementException nsee) {
                        // Object was borrowed in another thread
                        // Don't count this as an eviction test so reduce i;
                        i--;
                        evictionIterator = null;
                        continue;
                    }

                    if (!underTest.startEvictionTest()) {
                        // Object was borrowed in another thread
                        // Don't count this as an eviction test so reduce i;
                        i--;
                        continue;
                    }

                    // User provided eviction policy could throw all sorts of
                    // crazy exceptions. Protect against such an exception
                    // killing the eviction thread.
                    boolean evict;
                    try {
                        evict = evictionPolicy.evict(evictionConfig, underTest,
                                idleObjects.size());
                    } catch (final Throwable t) {
                        // Slightly convoluted as SwallowedExceptionListener
                        // uses Exception rather than Throwable
                        PoolUtils.checkRethrow(t);
                        swallowException(new Exception(t));
                        // Don't evict on error conditions
                        evict = false;
                    }

                    if (evict) {
                        destroy(underTest, DestroyMode.NORMAL);
                        destroyedByEvictorCount.incrementAndGet();
                    } else {
                        if (testWhileIdle) {
                            boolean active = false;
                            try {
                                factory.activateObject(underTest);
                                active = true;
                            } catch (final Exception e) {
                                destroy(underTest, DestroyMode.NORMAL);
                                destroyedByEvictorCount.incrementAndGet();
                            }
                            if (active) {
                                if (!factory.validateObject(underTest)) {
                                    destroy(underTest, DestroyMode.NORMAL);
                                    destroyedByEvictorCount.incrementAndGet();
                                } else {
                                    try {
                                        factory.passivateObject(underTest);
                                    } catch (final Exception e) {
                                        destroy(underTest, DestroyMode.NORMAL);
                                        destroyedByEvictorCount.incrementAndGet();
                                    }
                                }
                            }
                        }
                        if (!underTest.endEvictionTest(idleObjects)) {
                            // TODO - May need to add code here once additional
                            // states are used
                        }
                    }
                }
            }
        }
        final AbandonedConfig ac = this.abandonedConfig;
        if (ac != null && ac.getRemoveAbandonedOnMaintenance()) {
            removeAbandoned(ac);
        }
    }

    /**
     * Gets a reference to the factory used to create, destroy and validate
     * the objects used by this pool.
     *
     * @return the factory
     */
    public PooledObjectFactory<T> getFactory() {
        return factory;
    }

    /**
     * Gets the type - including the specific type rather than the generic -
     * of the factory.
     *
     * @return A string representation of the factory type
     */
    @Override
    public String getFactoryType() {
        // Not thread safe. Accept that there may be multiple evaluations.
        if (factoryType == null) {
            final StringBuilder result = new StringBuilder();
            result.append(factory.getClass().getName());
            result.append('<');
            final Class<?> pooledObjectType =
                    PoolImplUtils.getFactoryType(factory.getClass());
            result.append(pooledObjectType.getName());
            result.append('>');
            factoryType = result.toString();
        }
        return factoryType;
    }

    /**
     * Gets whether this pool identifies and logs any abandoned objects.
     *
     * @return {@code true} if abandoned object removal is configured for this
     *         pool and removal events are to be logged otherwise {@code false}
     *
     * @see AbandonedConfig#getLogAbandoned()
     */
    @Override
    public boolean getLogAbandoned() {
        final AbandonedConfig ac = this.abandonedConfig;
        return ac != null && ac.getLogAbandoned();
    }

    /**
     * Gets the cap on the number of "idle" instances in the pool. If maxIdle
     * is set too low on heavily loaded systems it is possible you will see
     * objects being destroyed and almost immediately new objects being created.
     * This is a result of the active threads momentarily returning objects
     * faster than they are requesting them, causing the number of idle
     * objects to rise above maxIdle. The best value for maxIdle for heavily
     * loaded system will vary but the default is a good starting point.
     *
     * @return the maximum number of "idle" instances that can be held in the
     *         pool or a negative value if there is no limit
     *
     * @see #setMaxIdle
     */
    @Override
    public int getMaxIdle() {
        return maxIdle;
    }

    /**
     * Gets the target for the minimum number of idle objects to maintain in
     * the pool. This setting only has an effect if it is positive and
     * {@link #getTimeBetweenEvictionRunsMillis()} is greater than zero. If this
     * is the case, an attempt is made to ensure that the pool has the required
     * minimum number of instances during idle object eviction runs.
     * <p>
     * If the configured value of minIdle is greater than the configured value
     * for maxIdle then the value of maxIdle will be used instead.
     * </p>
     *
     * @return The minimum number of objects.
     *
     * @see #setMinIdle(int)
     * @see #setMaxIdle(int)
     * @see #setTimeBetweenEvictionRunsMillis(long)
     */
    @Override
    public int getMinIdle() {
        final int maxIdleSave = getMaxIdle();
        if (this.minIdle > maxIdleSave) {
            return maxIdleSave;
        }
        return minIdle;
    }

    @Override
    public int getNumActive() {
        return allObjects.size() - idleObjects.size();
    }

    @Override
    public int getNumIdle() {
        return idleObjects.size();
    }

    /**
     * Calculates the number of objects to test in a run of the idle object
     * evictor.
     *
     * @return The number of objects to test for validity
     */
    private int getNumTests() {
        final int numTestsPerEvictionRun = getNumTestsPerEvictionRun();
        if (numTestsPerEvictionRun >= 0) {
            return Math.min(numTestsPerEvictionRun, idleObjects.size());
        }
        return (int) (Math.ceil(idleObjects.size() /
                Math.abs((double) numTestsPerEvictionRun)));
    }

    /**
     * Gets an estimate of the number of threads currently blocked waiting for
     * an object from the pool. This is intended for monitoring only, not for
     * synchronization control.
     *
     * @return The estimate of the number of threads currently blocked waiting
     *         for an object from the pool
     */
    @Override
    public int getNumWaiters() {
        if (getBlockWhenExhausted()) {
            return idleObjects.getTakeQueueLength();
        }
        return 0;
    }

    /**
     * Gets whether a check is made for abandoned objects when an object is borrowed
     * from this pool.
     *
     * @return {@code true} if abandoned object removal is configured to be
     *         activated by borrowObject otherwise {@code false}
     *
     * @see AbandonedConfig#getRemoveAbandonedOnBorrow()
     */
    @Override
    public boolean getRemoveAbandonedOnBorrow() {
        final AbandonedConfig ac = this.abandonedConfig;
        return ac != null && ac.getRemoveAbandonedOnBorrow();
    }


    //--- Usage tracking support -----------------------------------------------

    /**
     * Gets whether a check is made for abandoned objects when the evictor runs.
     *
     * @return {@code true} if abandoned object removal is configured to be
     *         activated when the evictor runs otherwise {@code false}
     *
     * @see AbandonedConfig#getRemoveAbandonedOnMaintenance()
     */
    @Override
    public boolean getRemoveAbandonedOnMaintenance() {
        final AbandonedConfig ac = this.abandonedConfig;
        return ac != null && ac.getRemoveAbandonedOnMaintenance();
    }


    //--- JMX support ----------------------------------------------------------

    /**
     * Gets the timeout before which an object will be considered to be
     * abandoned by this pool.
     *
     * @return The abandoned object timeout in seconds if abandoned object
     *         removal is configured for this pool; Integer.MAX_VALUE otherwise.
     *
     * @see AbandonedConfig#getRemoveAbandonedTimeout()
     * @see AbandonedConfig#getRemoveAbandonedTimeoutDuration()
     * @deprecated Use {@link #getRemoveAbandonedTimeoutDuration()}.
     */
    @Override
    @Deprecated
    public int getRemoveAbandonedTimeout() {
        final AbandonedConfig ac = this.abandonedConfig;
        return ac != null ? ac.getRemoveAbandonedTimeout() : Integer.MAX_VALUE;
    }

    /**
     * Gets the timeout before which an object will be considered to be
     * abandoned by this pool.
     *
     * @return The abandoned object timeout in seconds if abandoned object
     *         removal is configured for this pool; Integer.MAX_VALUE otherwise.
     *
     * @see AbandonedConfig#getRemoveAbandonedTimeout()
     * @see AbandonedConfig#getRemoveAbandonedTimeoutDuration()
     */
    public Duration getRemoveAbandonedTimeoutDuration() {
        final AbandonedConfig ac = this.abandonedConfig;
        return ac != null ? ac.getRemoveAbandonedTimeoutDuration() : DEFAULT_REMOVE_ABANDONED_TIMEOUT;
    }

    /**
     * {@inheritDoc}
     * <p>
     * Activation of this method decrements the active count and attempts to
     * destroy the instance, using the default (NORMAL) {@link DestroyMode}.
     * </p>
     *
     * @throws Exception             if an exception occurs destroying the
     *                               object
     * @throws IllegalStateException if obj does not belong to this pool
     */
    @Override
    public void invalidateObject(final T obj) throws Exception {
        invalidateObject(obj, DestroyMode.NORMAL);
    }

    /**
     * {@inheritDoc}
     * <p>
     * Activation of this method decrements the active count and attempts to
     * destroy the instance, using the provided {@link DestroyMode}.
     * </p>
     *
     * @throws Exception             if an exception occurs destroying the
     *                               object
     * @throws IllegalStateException if obj does not belong to this pool
     * @since 2.9.0
     */
    @Override
    public void invalidateObject(final T obj, final DestroyMode mode) throws Exception {
        final PooledObject<T> p = allObjects.get(new IdentityWrapper<>(obj));
        if (p == null) {
            if (isAbandonedConfig()) {
                return;
            }
            throw new IllegalStateException(
                    "Invalidated object not currently part of this pool");
        }
        synchronized (p) {
            if (p.getState() != PooledObjectState.INVALID) {
                destroy(p, mode);
            }
        }
        ensureIdle(1, false);
    }

    // --- configuration attributes --------------------------------------------

    /**
     * Gets whether or not abandoned object removal is configured for this pool.
     *
     * @return true if this pool is configured to detect and remove
     * abandoned objects
     */
    @Override
    public boolean isAbandonedConfig() {
        return abandonedConfig != null;
    }
    /**
     * Provides information on all the objects in the pool, both idle (waiting
     * to be borrowed) and active (currently borrowed).
     * <p>
     * Note: This is named listAllObjects so it is presented as an operation via
     * JMX. That means it won't be invoked unless the explicitly requested
     * whereas all attributes will be automatically requested when viewing the
     * attributes for an object in a tool like JConsole.
     * </p>
     *
     * @return Information grouped on all the objects in the pool
     */
    @Override
    public Set<DefaultPooledObjectInfo> listAllObjects() {
        final Set<DefaultPooledObjectInfo> result =
                new HashSet<>(allObjects.size());
        for (final PooledObject<T> p : allObjects.values()) {
            result.add(new DefaultPooledObjectInfo(p));
        }
        return result;
    }
    /**
     * Tries to ensure that {@link #getMinIdle()} idle instances are available
     * in the pool.
     *
     * @throws Exception If the associated factory throws an exception
     * @since 2.4
     */
    public void preparePool() throws Exception {
        if (getMinIdle() < 1) {
            return;
        }
        ensureMinIdle();
    }


    // --- internal attributes -------------------------------------------------

    /**
     * Recovers abandoned objects which have been checked out but
     * not used since longer than the removeAbandonedTimeout.
     *
     * @param abandonedConfig The configuration to use to identify abandoned objects
     */
    @SuppressWarnings("resource") // PrintWriter is managed elsewhere
    private void removeAbandoned(final AbandonedConfig abandonedConfig) {
        // Generate a list of abandoned objects to remove
        final long nowMillis = System.currentTimeMillis();
        final long timeoutMillis =
                nowMillis - abandonedConfig.getRemoveAbandonedTimeoutDuration().toMillis();
        final ArrayList<PooledObject<T>> remove = new ArrayList<>();
        final Iterator<PooledObject<T>> it = allObjects.values().iterator();
        while (it.hasNext()) {
            final PooledObject<T> pooledObject = it.next();
            synchronized (pooledObject) {
                if (pooledObject.getState() == PooledObjectState.ALLOCATED &&
                        pooledObject.getLastUsedTime() <= timeoutMillis) {
                    pooledObject.markAbandoned();
                    remove.add(pooledObject);
                }
            }
        }

        // Now remove the abandoned objects
        final Iterator<PooledObject<T>> itr = remove.iterator();
        while (itr.hasNext()) {
            final PooledObject<T> pooledObject = itr.next();
            if (abandonedConfig.getLogAbandoned()) {
                pooledObject.printStackTrace(abandonedConfig.getLogWriter());
            }
            try {
                invalidateObject(pooledObject.getObject(), DestroyMode.ABANDONED);
            } catch (final Exception e) {
                e.printStackTrace();
            }
        }
    }
    /**
     * {@inheritDoc}
     * <p>
     * If {@link #getMaxIdle() maxIdle} is set to a positive value and the
     * number of idle instances has reached this value, the returning instance
     * is destroyed.
     * </p>
     * <p>
     * If {@link #getTestOnReturn() testOnReturn} == true, the returning
     * instance is validated before being returned to the idle instance pool. In
     * this case, if validation fails, the instance is destroyed.
     * </p>
     * <p>
     * Exceptions encountered destroying objects for any reason are swallowed
     * but notified via a {@link SwallowedExceptionListener}.
     * </p>
     */
    @Override
    public void returnObject(final T obj) {
        final PooledObject<T> p = allObjects.get(new IdentityWrapper<>(obj));

        if (p == null) {
            if (!isAbandonedConfig()) {
                throw new IllegalStateException(
                        "Returned object not currently part of this pool");
            }
            return; // Object was abandoned and removed
        }

        markReturningState(p);

        final Duration activeTime = p.getActiveTime();

        if (getTestOnReturn() && !factory.validateObject(p)) {
            try {
                destroy(p, DestroyMode.NORMAL);
            } catch (final Exception e) {
                swallowException(e);
            }
            try {
                ensureIdle(1, false);
            } catch (final Exception e) {
                swallowException(e);
            }
            updateStatsReturn(activeTime);
            return;
        }

        try {
            factory.passivateObject(p);
        } catch (final Exception e1) {
            swallowException(e1);
            try {
                destroy(p, DestroyMode.NORMAL);
            } catch (final Exception e) {
                swallowException(e);
            }
            try {
                ensureIdle(1, false);
            } catch (final Exception e) {
                swallowException(e);
            }
            updateStatsReturn(activeTime);
            return;
        }

        if (!p.deallocate()) {
            throw new IllegalStateException(
                    "Object has already been returned to this pool or is invalid");
        }

        final int maxIdleSave = getMaxIdle();
        if (isClosed() || maxIdleSave > -1 && maxIdleSave <= idleObjects.size()) {
            try {
                destroy(p, DestroyMode.NORMAL);
            } catch (final Exception e) {
                swallowException(e);
            }
            try {
                ensureIdle(1, false);
            } catch (final Exception e) {
                swallowException(e);
            }
        } else {
            if (getLifo()) {
                idleObjects.addFirst(p);
            } else {
                idleObjects.addLast(p);
            }
            if (isClosed()) {
                // Pool closed while object was being added to idle objects.
                // Make sure the returned object is destroyed rather than left
                // in the idle object pool (which would effectively be a leak)
                clear();
            }
        }
        updateStatsReturn(activeTime);
    }
    /**
     * Sets the abandoned object removal configuration.
     *
     * @param abandonedConfig the new configuration to use. This is used by value.
     *
     * @see AbandonedConfig
     */
    @SuppressWarnings("resource") // PrintWriter is managed elsewhere
    public void setAbandonedConfig(final AbandonedConfig abandonedConfig) {
        if (abandonedConfig == null) {
            this.abandonedConfig = null;
        } else {
            this.abandonedConfig = new AbandonedConfig();
            this.abandonedConfig.setLogAbandoned(abandonedConfig.getLogAbandoned());
            this.abandonedConfig.setLogWriter(abandonedConfig.getLogWriter());
            this.abandonedConfig.setRemoveAbandonedOnBorrow(abandonedConfig.getRemoveAbandonedOnBorrow());
            this.abandonedConfig.setRemoveAbandonedOnMaintenance(abandonedConfig.getRemoveAbandonedOnMaintenance());
            this.abandonedConfig.setRemoveAbandonedTimeout(abandonedConfig.getRemoveAbandonedTimeoutDuration());
            this.abandonedConfig.setUseUsageTracking(abandonedConfig.getUseUsageTracking());
            this.abandonedConfig.setRequireFullStackTrace(abandonedConfig.getRequireFullStackTrace());
        }
    }
    /**
     * Sets the base pool configuration.
     *
     * @param conf the new configuration to use. This is used by value.
     *
     * @see GenericObjectPoolConfig
     */
    public void setConfig(final GenericObjectPoolConfig<T> conf) {
        super.setConfig(conf);
        setMaxIdle(conf.getMaxIdle());
        setMinIdle(conf.getMinIdle());
        setMaxTotal(conf.getMaxTotal());
    }
    /**
     * Sets the cap on the number of "idle" instances in the pool. If maxIdle
     * is set too low on heavily loaded systems it is possible you will see
     * objects being destroyed and almost immediately new objects being created.
     * This is a result of the active threads momentarily returning objects
     * faster than they are requesting them, causing the number of idle
     * objects to rise above maxIdle. The best value for maxIdle for heavily
     * loaded system will vary but the default is a good starting point.
     *
     * @param maxIdle
     *            The cap on the number of "idle" instances in the pool. Use a
     *            negative value to indicate an unlimited number of idle
     *            instances
     *
     * @see #getMaxIdle
     */
    public void setMaxIdle(final int maxIdle) {
        this.maxIdle = maxIdle;
    }

    /**
     * Sets the target for the minimum number of idle objects to maintain in
     * the pool. This setting only has an effect if it is positive and
     * {@link #getTimeBetweenEvictionRunsMillis()} is greater than zero. If this
     * is the case, an attempt is made to ensure that the pool has the required
     * minimum number of instances during idle object eviction runs.
     * <p>
     * If the configured value of minIdle is greater than the configured value
     * for maxIdle then the value of maxIdle will be used instead.
     * </p>
     *
     * @param minIdle
     *            The minimum number of objects.
     *
     * @see #getMinIdle()
     * @see #getMaxIdle()
     * @see #getTimeBetweenEvictionRunsMillis()
     */
    public void setMinIdle(final int minIdle) {
        this.minIdle = minIdle;
    }

    @Override
    public void use(final T pooledObject) {
        final AbandonedConfig abandonedCfg = this.abandonedConfig;
        if (abandonedCfg != null && abandonedCfg.getUseUsageTracking()) {
            final PooledObject<T> wrapper = allObjects.get(new IdentityWrapper<>(pooledObject));
            wrapper.use();
        }
    }

}
```