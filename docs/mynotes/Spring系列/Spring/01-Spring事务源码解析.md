# Spring事务源码解析

[TOC]

## 介绍

### 什么是事务？

> 事务是逻辑上的一组操作，要么都执行，要么都不执行

### MySQL事务特性

- **原子性：**事务中的操作要么全部成功，要么全部失败
- **一致性：**事务必须使数据库从一个一致性状态变换到另外一个一致性状态
- **隔离性：**每一个用户开启的事务，不能被其他事务的操作数据所干扰
- **持久性：**持久性是指一个事务一旦被提交，它对数据库中数据的改变就是永久性的，接下来即使数据库发生故障也不应该对其有任何影响

### Spring事务 VS MySQL 事物

本质上其实是同一个概念,spring的事务是对数据库的事务的封装,最后本质的实现还是在数据库,假如数据库不支持事务的话,spring的事务是没有作用的。

- MySQL事务说简单就只有开启,回滚和关闭
- Spring对数据库事务的包装

**Spring事务原理：**拿一个数据**连接**,根据Spring的事务配置,操作这个数据连接对数据库进行事务开启,回滚或关闭操作；还配合Spring的传播行为对事务进行了更广泛的管理.

**我们由此做一下总结：**

- Spring事务本质是对连接的打开、提交、回滚、关闭的管理
- Spring事务做了多事务之间传播特性规则总结

**暂时能想到的问题：**

Spring事务如何感知配置？

Spring事务如何对隔离级别进行封装？

Spring事务如何做的传播特性？

## Spring 事务管理方式

### 编程式事务

通过 `TransactionTemplate`或者`TransactionManager`手动管理事务，实际应用中很少使用，但是对于你理解 Spring 事务管理原理有帮助。

使用`TransactionTemplate`

```java
		@Autowired
    TransactionTemplate template;
    /**
     * 编程式事务2
     */
    public void transfer2() {
        template.setIsolationLevel(TransactionDefinition.ISOLATION_DEFAULT);
        // 定义默认事务属性
        template.execute(new TransactionCallbackWithoutResult() {
            @Override
            protected void doInTransactionWithoutResult(TransactionStatus status) {
                try {
                    jdbcTemplate.update("update xinwenzaixian set title = ? where id = ?", "我公司网格OAO模式创新取得阶段性成果", "-1009585447157150574");
//                    int a = 1 / 0;
                    // 这里成功的话，会自动提交
                } catch (Exception e) {
                    status.setRollbackOnly();
                    e.printStackTrace();
                }
            }
        });
    }
```

使用 `TransactionManager`

```java
/**
 * 编程式事务
 */
public void transfer() {
    // 定义默认事务属性
    DefaultTransactionDefinition defaultTransactionDefinition = new DefaultTransactionDefinition();
    defaultTransactionDefinition.setIsolationLevel(TransactionDefinition.ISOLATION_DEFAULT);
    // 获取 TransactionStatus
    TransactionStatus status = transactionManager.getTransaction(defaultTransactionDefinition);
    try {
        jdbcTemplate.update("update xinwenzaixian set title = ? where id = ?", "我公司网格OAO模式创新取得阶段性成果", "-1009585447157150574");
        int a = 1 / 0;
        transactionManager.commit(status);
    } catch (Exception e) {
        e.printStackTrace();
        transactionManager.rollback(status);
    }
}
```

`TransactionTemplate` **VS** `TransactionManager`

**TransactionManager：**生成一个事务，并管理事物的提交和回滚。

需要手动的去生成事务的定义

```java
public interface PlatformTransactionManager extends TransactionManager {
  // 生成事务
  TransactionStatus getTransaction(@Nullable TransactionDefinition definition)
    throws TransactionException;
  // 提交
  void commit(TransactionStatus status) throws TransactionException;
  // 回滚
  void rollback(TransactionStatus status) throws TransactionException;
}
```

**TransactionTemplate：**本质上是对事务定义以及管理类`PlatformTransactionManager`的一个封装类。默认是事务自动提交的

```java
// 具有事务的定义、操作、以及内部封装类的初始化
public class TransactionTemplate extends DefaultTransactionDefinition implements TransactionOperations, InitializingBean
  
  // 该类没有管理器则会直接报错
public void afterPropertiesSet() {
		if (this.transactionManager == null) {
			throw new IllegalArgumentException("Property 'transactionManager' is required");
		}
	}

// 事务操作：内部是对事务管理的操作封装
public <T> T execute(TransactionCallback<T> action) throws TransactionException {
  Assert.state(this.transactionManager != null, "No PlatformTransactionManager set");

		if (this.transactionManager instanceof CallbackPreferringPlatformTransactionManager) {
			return ((CallbackPreferringPlatformTransactionManager) this.transactionManager).execute(this, action);
		}
		else {
			TransactionStatus status = this.transactionManager.getTransaction(this);
			T result;
			try {
				result = action.doInTransaction(status);
			}
			catch (RuntimeException | Error ex) {
				// Transactional code threw application exception -> rollback
				rollbackOnException(status, ex);
				throw ex;
			}
			catch (Throwable ex) {
				// Transactional code threw unexpected exception -> rollback
				rollbackOnException(status, ex);
				throw new UndeclaredThrowableException(ex, "TransactionCallback threw undeclared checked exception");
			}
			this.transactionManager.commit(status);
			return result;
		}
}
```

### 声明式事务

> 推荐使用（**代码侵入性最小，但细粒度无法到代码块级别**），实际是通过 **AOP 实现**（基于`@Transactional` 的全注解方式使用最多）

使用 `@Transactional`注解

```java
@Transactional(propagation=propagation.PROPAGATION_REQUIRED)
public void aMethod {
  //do something
  B b = new B();
  C c = new C();
  b.bMethod();
  c.cMethod();
}
```

### 区别总结

**声明式事务管理建立在AOP之上**的，本质是对方法前后进行拦截，然后在目标方法开始之前创建或者加入一个事务，在执行完目标方法之后根据执行情况提交或者回滚事务。**优点就是代码侵入性最小；不足就是最细粒度只能作用到方法级别**，而像**编程式事务可以作用到代码块级别**。显然基于注解的方式更简单易用，更清爽

## Spring 事务主要管理接口

事务管理相关最重要的 3 个接口：

**`PlatformTransactionManager`**： （平台）事务管理器，Spring 事务操作策略的核心。【上层管理者】

**`TransactionDefinition`**： 事务定义信息(事务隔离级别、传播行为、超时、只读、回滚规则)。【事务属性】

**`TransactionStatus`**： 事务运行状态。【事务的描述】

**具体流程理解：**

**`PlatformTransactionManager`** 会根据 **`TransactionDefinition`** 的定义比如事务超时时间、隔离级别、传播行为等来进行事务管理 ，而 **`TransactionStatus`** 接口则提供了一些方法来获取事务相应的状态比如是否新事务、是否可以回滚等等

### PlatformTransactionManager:事务管理接口

**Spring 并不直接管理事务，而是提供了多种事务管理器** 。Spring 事务管理器的接口是： **`PlatformTransactionManager`** 。

通过这个接口，Spring 为各个平台如 JDBC(`DataSourceTransactionManager`)、Hibernate(`HibernateTransactionManager`)、JPA(`JpaTransactionManager`)等都提供了对应的事务管理器，但是具体的实现就是各个平台自己的事情了。

这样我们可以保证提供给外部的行为不变，方便我们扩展（这也是定义为接口的理由）

### TransactionDefinition:事务属性

**什么是事务属性呢？** 事务属性可以理解成事务的一些基本配置，描述了事务策略如何应用到方法上。

事务属性包含了 5 个方面：

- 隔离级别
- 传播行为
- 回滚规则
- 是否只读
- 事务超时

`TransactionDefinition` 接口中定义了 5 个方法以及一些表示事务属性的常量比如隔离级别、传播行为等等。

```java
package org.springframework.transaction;

import org.springframework.lang.Nullable;

public interface TransactionDefinition {
    int PROPAGATION_REQUIRED = 0;
    int PROPAGATION_SUPPORTS = 1;
    int PROPAGATION_MANDATORY = 2;
    int PROPAGATION_REQUIRES_NEW = 3;
    int PROPAGATION_NOT_SUPPORTED = 4;
    int PROPAGATION_NEVER = 5;
    int PROPAGATION_NESTED = 6;
    int ISOLATION_DEFAULT = -1;
    int ISOLATION_READ_UNCOMMITTED = 1;
    int ISOLATION_READ_COMMITTED = 2;
    int ISOLATION_REPEATABLE_READ = 4;
    int ISOLATION_SERIALIZABLE = 8;
    int TIMEOUT_DEFAULT = -1;
    // 返回事务的传播行为，默认值为 REQUIRED。
    int getPropagationBehavior();
    //返回事务的隔离级别，默认值是 DEFAULT
    int getIsolationLevel();
    // 返回事务的超时时间，默认值为-1。如果超过该时间限制但事务还没有完成，则自动回滚事务。
    int getTimeout();
    // 返回是否为只读事务，默认值为 false
    boolean isReadOnly();

    @Nullable
    String getName();
}
```

### TransactionStatus:事务状态

`TransactionStatus`接口用来记录事务的状态 该接口定义了一组方法,用来获取或判断事务的相应状态信息。

`PlatformTransactionManager.getTransaction(…)`方法返回一个 `TransactionStatus` 对象。

**TransactionStatus 接口接口内容如下：**

```java
// TransactionStatus类
public interface TransactionStatus extends TransactionExecution, SavepointManager, Flushable {
    boolean hasSavepoint(); // 是否有恢复点 	
}

// TransactionExecution类
boolean isNewTransaction(); // 是否是新的事务
void setRollbackOnly();  // 设置为只回滚
boolean isRollbackOnly(); // 是否为只回滚
boolean isCompleted; // 是否已完成

// SavepointManager类
Object createSavepoint() throws TransactionException;// 新建恢复标记点
void rollbackToSavepoint(Object savepoint) throws TransactionException;// 回滚至事务标记点
void releaseSavepoint(Object savepoint) throws TransactionException;// 释放事务标记点

// Flushable类
void flush() throws IOException;// 刷新
```

## Spring事务使用

大家一般都是使用 `@Transactional` 注解来开启事务，很多人并不清楚这个参数里面的参数是什么意思，有什么用。为了更好的在项目中使用事务管理，强烈推荐好好阅读一下下面的内容。

### 事务传播行为

> 事务传播行为用来描述由某一个事务传播行为修饰的方法被嵌套进另一个方法的时事务如何传播。
>
> **事务传播行为是为了解决业务层方法之间互相调用的事务问题**。

当事务方法被另一个事务方法调用时，必须指定事务应该如何传播。例如：方法可能继续在现有事务中运行，也可能开启一个新事务，并在自己的事务中运行。

举个例子：我们在 A 类的`aMethod（）`方法中调用了 B 类的 `bMethod()` 方法。这个时候就涉及到业务层方法之间互相调用的事务问题。如果我们的 `bMethod()`如果发生异常需要回滚，如何配置事务传播行为才能让 `aMethod()`也跟着回滚呢？这个时候就需要事务传播行为的知识了，如果你不知道的话一定要好好看一下。

```java
Class A {
    @Transactional(propagation=propagation.xxx)
    public void aMethod {
        //do something
        B b = new B();
        b.bMethod();
    }
}

Class B {
    @Transactional(propagation=propagation.xxx)
    public void bMethod {
       //do something
    }
}
```

在`TransactionDefinition`定义中包括了如下几个表示传播行为的常量：

```java
public interface TransactionDefinition {
    int PROPAGATION_REQUIRED = 0;
    int PROPAGATION_SUPPORTS = 1;
    int PROPAGATION_MANDATORY = 2;
    int PROPAGATION_REQUIRES_NEW = 3;
    int PROPAGATION_NOT_SUPPORTED = 4;
    int PROPAGATION_NEVER = 5;
    int PROPAGATION_NESTED = 6;
    ......
}
```

![图片](https://tva1.sinaimg.cn/large/e6c9d24ely1h55cfd5xtjj20u00eaabt.jpg)

不过如此，为了方便使用，Spring 会相应地定义了一个枚举类：`Propagation`

```java
package org.springframework.transaction.annotation;

import org.springframework.transaction.TransactionDefinition;

public enum Propagation {

    REQUIRED(TransactionDefinition.PROPAGATION_REQUIRED),

    SUPPORTS(TransactionDefinition.PROPAGATION_SUPPORTS),

    MANDATORY(TransactionDefinition.PROPAGATION_MANDATORY),

    REQUIRES_NEW(TransactionDefinition.PROPAGATION_REQUIRES_NEW),

    NOT_SUPPORTED(TransactionDefinition.PROPAGATION_NOT_SUPPORTED),

    NEVER(TransactionDefinition.PROPAGATION_NEVER),

    NESTED(TransactionDefinition.PROPAGATION_NESTED);

    private final int value;

    Propagation(int value) {
        this.value = value;
    }

    public int value() {
        return this.value;
    }

}
```

**正确的事务传播行为可能的值如下** ：

**1.`TransactionDefinition.PROPAGATION_REQUIRED`**

使用的最多的一个事务传播行为，我们平时经常使用的`@Transactional`注解默认使用就是这个事务传播行为。如果当前存在事务，则加入该事务；如果当前没有事务，则创建一个新的事务。也就是说：

- 如果外部方法没有开启事务的话，`Propagation.REQUIRED`修饰的内部方法会新开启自己的事务，且开启的事务相互独立，互不干扰。
- 如果外部方法开启事务并且被`Propagation.REQUIRED`的话，所有`Propagation.REQUIRED`修饰的内部方法和外部方法均属于同一事务 ，只要一个方法回滚，整个事务均回滚。

举个例子：如果我们上面的`aMethod()`和`bMethod()`使用的都是`PROPAGATION_REQUIRED`传播行为的话，两者使用的就是同一个事务，只要其中一个方法回滚，整个事务均回滚。

```java
Class A {
    @Transactional(propagation=propagation.PROPAGATION_REQUIRED)
    public void aMethod {
        //do something
        B b = new B();
        b.bMethod();
    }
}

Class B {
    @Transactional(propagation=propagation.PROPAGATION_REQUIRED)
    public void bMethod {
       //do something
    }
}
```

**`2.TransactionDefinition.PROPAGATION_REQUIRES_NEW`**

创建一个新的事务，如果当前存在事务，则把当前事务挂起。也就是说不管外部方法是否开启事务，`Propagation.REQUIRES_NEW`修饰的内部方法会新开启自己的事务，且开启的事务相互独立，互不干扰。

举个例子：如果我们上面的`bMethod()`使用`PROPAGATION_REQUIRES_NEW`事务传播行为修饰，`aMethod`还是用`PROPAGATION_REQUIRED`修饰的话。如果`aMethod()`发生异常回滚，`bMethod()`不会跟着回滚，因为 `bMethod()`开启了独立的事务。但是，如果 `bMethod()`抛出了未被捕获的异常并且这个异常满足事务回滚规则的话,`aMethod()`同样也会回滚，因为这个异常被 `aMethod()`的事务管理机制检测到了。

```java
Class A {
    @Transactional(propagation=propagation.PROPAGATION_REQUIRED)
    public void aMethod {
        //do something
        B b = new B();
        b.bMethod();
    }
}

Class B {
    @Transactional(propagation=propagation.REQUIRES_NEW)
    public void bMethod {
       //do something
    }
}
```

**3.`TransactionDefinition.PROPAGATION_NESTED`**:

如果当前存在事务，就在嵌套事务内执行；如果当前没有事务，就执行与`TransactionDefinition.PROPAGATION_REQUIRED`类似的操作。也就是说：

- 在外部方法开启事务的情况下,在内部开启一个新的事务，作为嵌套事务存在。
- 如果外部方法无事务，则单独开启一个事务，与 `PROPAGATION_REQUIRED` 类似。

这里还是简单举个例子：如果 `bMethod()` 回滚的话，`aMethod()`也会回滚。

```java
Class A {
    @Transactional(propagation=propagation.PROPAGATION_REQUIRED)
    public void aMethod {
        //do something
        B b = new B();
        b.bMethod();
    }
}

Class B {
    @Transactional(propagation=propagation.PROPAGATION_NESTED)
    public void bMethod {
       //do something
    }
}
```

**4.`TransactionDefinition.PROPAGATION_MANDATORY`**

如果当前存在事务，则加入该事务；如果当前没有事务，则抛出异常。（mandatory：强制性）

这个使用的很少，就不举例子来说了。

**若是错误的配置以下 3 种事务传播行为，事务将不会发生回滚，这里不对照案例讲解了，使用的很少。**

- **`TransactionDefinition.PROPAGATION_SUPPORTS`**: 如果当前存在事务，则加入该事务；如果当前没有事务，则以非事务的方式继续运行。
- **`TransactionDefinition.PROPAGATION_NOT_SUPPORTED`**: 以非事务方式运行，如果当前存在事务，则把当前事务挂起。
- **`TransactionDefinition.PROPAGATION_NEVER`**: 以非事务方式运行，如果当前存在事务，则抛出异常。

### 事务隔离级别

`TransactionDefinition` 接口中定义了五个表示隔离级别的常量：

```java
public interface TransactionDefinition {
    ......
    int ISOLATION_DEFAULT = -1;
    int ISOLATION_READ_UNCOMMITTED = 1;
    int ISOLATION_READ_COMMITTED = 2;
    int ISOLATION_REPEATABLE_READ = 4;
    int ISOLATION_SERIALIZABLE = 8;
    ......
}
```

和事务传播行为这块一样，为了方便使用，Spring 也相应地定义了一个枚举类：`Isolation`

```java
public enum Isolation {

  DEFAULT(TransactionDefinition.ISOLATION_DEFAULT),

  READ_UNCOMMITTED(TransactionDefinition.ISOLATION_READ_UNCOMMITTED),

  READ_COMMITTED(TransactionDefinition.ISOLATION_READ_COMMITTED),

  REPEATABLE_READ(TransactionDefinition.ISOLATION_REPEATABLE_READ),

  SERIALIZABLE(TransactionDefinition.ISOLATION_SERIALIZABLE);

  private final int value;

  Isolation(int value) {
    this.value = value;
  }

  public int value() {
    return this.value;
  }

}
```

下面我依次对每一种事务隔离级别进行介绍：

- **`TransactionDefinition.ISOLATION_DEFAULT`** :使用后端数据库默认的隔离级别，MySQL 默认采用的 `REPEATABLE_READ` 隔离级别 Oracle 默认采用的 `READ_COMMITTED` 隔离级别.
- **`TransactionDefinition.ISOLATION_READ_UNCOMMITTED`** :最低的隔离级别，使用这个隔离级别很少，因为它允许读取尚未提交的数据变更，**可能会导致脏读、幻读或不可重复读**
- **`TransactionDefinition.ISOLATION_READ_COMMITTED`** : 允许读取并发事务已经提交的数据，**可以阻止脏读，但是幻读或不可重复读仍有可能发生**
- **`TransactionDefinition.ISOLATION_REPEATABLE_READ`** : 对同一字段的多次读取结果都是一致的，除非数据是被本身事务自己所修改，**可以阻止脏读和不可重复读，但幻读仍有可能发生。**
- **`TransactionDefinition.ISOLATION_SERIALIZABLE`** : 最高的隔离级别，完全服从 ACID 的隔离级别。所有的事务依次逐个执行，这样事务之间就完全不可能产生干扰，也就是说，**该级别可以防止脏读、不可重复读以及幻读**。但是这将严重影响程序的性能。通常情况下也不会用到该级别。

### 事务超时属性

在 `TransactionDefinition` 中以 int 的值来表示超时时间，其单位是秒，默认值为-1

### 事务只读属性

```java
package org.springframework.transaction;

import org.springframework.lang.Nullable;

public interface TransactionDefinition {
    ......
    // 返回是否为只读事务，默认值为 false
    boolean isReadOnly();

}
```

对于只有读取数据查询的事务，可以指定事务类型为 readonly，即只读事务。只读事务不涉及数据的修改，数据库会提供一些优化手段，适合用在有多条数据库查询操作的方法中。

### 事务回滚规则

这些规则定义了哪些异常会导致事务回滚而哪些不会。默认情况下，事务只有遇到运行期异常（`RuntimeException` 的子类）时才会回滚，`Error` 也会导致事务回滚，但是，在遇到检查型（Checked）异常时不会回滚。

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h55cm3vxejj21ns0p0tf2.jpg)

如果你想要回滚你定义的特定的异常类型的话，可以这样：

```java
@Transactional(rollbackFor= MyException.class)
```

## @Transactional 注解使用详解

### `@Transactional`作用范围

1. **方法** ：推荐将注解使用于方法上，不过需要注意的是：**该注解只能应用到 public 方法上，否则不生效。**
2. **类** ：如果这个注解使用在类上的话，表明该注解对该类中所有的 public 方法都生效。
3. **接口** ：不推荐在接口上使用。

### `@Transactional` 常用配置参数

`@Transactional`注解源码如下，里面包含了基本事务属性的配置：

```java
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
@Documented
public @interface Transactional {

	@AliasFor("transactionManager")
	String value() default "";

	@AliasFor("value")
	String transactionManager() default "";

	Propagation propagation() default Propagation.REQUIRED;

	Isolation isolation() default Isolation.DEFAULT;

	int timeout() default TransactionDefinition.TIMEOUT_DEFAULT;

	boolean readOnly() default false;

	Class<? extends Throwable>[] rollbackFor() default {};

	String[] rollbackForClassName() default {};

	Class<? extends Throwable>[] noRollbackFor() default {};

	String[] noRollbackForClassName() default {};

}
```

**`@Transactional` 的常用配置参数总结（只列出了 5 个我平时比较常用的）：**

| 属性名      | 说明                                                         |
| ----------- | ------------------------------------------------------------ |
| propagation | 事务的传播行为，默认值为 REQUIRED，可选的值在上面介绍过      |
| isolation   | 事务的隔离级别，默认值采用 DEFAULT，可选的值在上面介绍过     |
| timeout     | 事务的超时时间，默认值为-1（不会超时）。如果超过该时间限制但事务还没有完成，则自动回滚事务。 |
| readOnly    | 指定事务是否为只读事务，默认值为 false。                     |
| rollbackFor | 用于指定能够触发事务回滚的异常类型，并且可以指定多个异常类型。 |

### `@Transactional` 事务注解原理

我们先来最先从解析该注解的属性开始，可以看到Spring定义了一个获取方法上注解事务属性的方式

```java
// 代表事务属性
public interface TransactionAttributeSource {
	// 目标类是否为候选类
	default boolean isCandidateClass(Class<?> targetClass) {
		return true;
	}
	// 是的话，就得到事务属性，否的话就没必要执行这个了
	@Nullable
	TransactionAttribute getTransactionAttribute(Method method, @Nullable Class<?> 		targetClass);
}
```

注解事务属性中维护了一个`annotationParsers`用来解析事务注解

```java
public class AnnotationTransactionAttributeSource {
// 注解解析器集合
	private final Set<TransactionAnnotationParser> annotationParsers;
}
```

解析器集合轮询解析注解

```java
// AnnotationTransactionAttributeSource
@Nullable
protected TransactionAttribute determineTransactionAttribute(AnnotatedElement element) {
  // 解析器遍历
   for (TransactionAnnotationParser parser : this.annotationParsers) {
      TransactionAttribute attr = parser.parseTransactionAnnotation(element);
      if (attr != null) {
         return attr;
      }
   }
   return null;
}
```

解析出来的信息会放在代表注解的属性类中`TransactionAttribute`

```java
// 将解析出来的属性封装成对象元素
protected TransactionAttribute parseTransactionAnnotation(AnnotationAttributes attributes) {
   RuleBasedTransactionAttribute rbta = new RuleBasedTransactionAttribute();

   Propagation propagation = attributes.getEnum("propagation");
   rbta.setPropagationBehavior(propagation.value());
   Isolation isolation = attributes.getEnum("isolation");
   rbta.setIsolationLevel(isolation.value());

   rbta.setTimeout(attributes.getNumber("timeout").intValue());
   String timeoutString = attributes.getString("timeoutString");
   Assert.isTrue(!StringUtils.hasText(timeoutString) || rbta.getTimeout() < 0,
         "Specify 'timeout' or 'timeoutString', not both");
   rbta.setTimeoutString(timeoutString);

   rbta.setReadOnly(attributes.getBoolean("readOnly"));
   rbta.setQualifier(attributes.getString("value"));
   rbta.setLabels(Arrays.asList(attributes.getStringArray("label")));

   List<RollbackRuleAttribute> rollbackRules = new ArrayList<>();
   for (Class<?> rbRule : attributes.getClassArray("rollbackFor")) {
      rollbackRules.add(new RollbackRuleAttribute(rbRule));
   }
   for (String rbRule : attributes.getStringArray("rollbackForClassName")) {
      rollbackRules.add(new RollbackRuleAttribute(rbRule));
   }
   for (Class<?> rbRule : attributes.getClassArray("noRollbackFor")) {
      rollbackRules.add(new NoRollbackRuleAttribute(rbRule));
   }
   for (String rbRule : attributes.getStringArray("noRollbackForClassName")) {
      rollbackRules.add(new NoRollbackRuleAttribute(rbRule));
   }
   rbta.setRollbackRules(rollbackRules);

   return rbta;
}
```