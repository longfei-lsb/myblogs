# Spring AOP徒手扒源码（1）

[TOC]

## 前沿

> 源码目录结构

![image-20220820080424678](https://tva1.sinaimg.cn/large/e6c9d24ely1h5cwp6zsf9j20js0mmdh4.jpg)

### 源码目录解释

**个人理解：**

> 名词解释：
>
> alliance：结盟团体

`org.aopalliance` VS `org.springframework.aop`

前者是最核心的同盟（需要揉杂在一块使用）规范，后者是功能框架规范实现

`org.aopalliance`下分为`aop`与`intercept`两个包：

- aop：AOP本质是增强，我们知道增强的术语`Advice`，所以只有`Advice`相关，是最核心的AOP标识
- intercept：增强规范的实现主要是通过拦截器，而拦截器与连接点密不可分，这也是为什么叫alliance的原因

### 核心接口解释

> 以下代码从0到1实现顺序手扒、翻译

```java
package org.aopalliance.aop;

/**
 * aop核心规范：通知增强 （顶级标识）
 */
public interface Advice {
}
```

```java
package org.aopalliance.aop.intercept;

/**
 * 1、静态连接点：程序中的位置（如：方法、构造函数、字段）<p>
 * 2、运行时连接点：发生在静态连接点的事件（如：方法、构造函数、字段调用前后）<p>
 * 3、该接口代表一个运行时连接点<p>
 * 4、可以用{@link #getStaticPart()}获取静态连接点
 * ----------------------------------------------------------------------
 * 用法：在 {@link Interceptor} 拦截器框架上下文中，运行时连接点是对可访问对象（方法、构造函数、字段）的访问的具体化，即连接点的静态部分。
 * 它被传递给安装在静态连接点上的拦截器。
 * ----------------------------------------------------------------------
 * 理解： 针对于 {@link MethodInvocation} 来说
 * <p>1）调用staticPart：获取 {@link MethodInvocation} 所调用的的具体方法；
 * <p>2）调用this：获取 {@link MethodInvocation} 实例本身；
 * <p>3）调用proceed：获取下一个安装在此连接点上的拦截器；
 */
public interface Joinpoint {

    /**
     * 继续到链中的下一个拦截器
     * -----------------------------------------------------------------
     * 此方法的实现和语义取决于实际的连接点类型（请参阅子接口）
     */
    Object proceed() throws Throwable;

    /**
     * 返回包含当前连接点静态部分的对象
     *
     * @return
     */
    Object getThis();

    /**
     * 获取静态连接点
     *
     * @return
     */
    Object getStaticPart();
}
```

```java
package org.aopalliance.aop.intercept;

import org.aopalliance.aop.Advice;

/**
 * 拦截运行时事件规范接口，通过连接点{@link Joinpoint}实现
 */
public interface Interceptor extends Advice {

}
```

```java
package org.aopalliance.aop.intercept;

/**
 * 1、表示程序中的调用
 * 2、调用是一个连接点，可以被拦截器拦截
 */
public interface Invocation extends Joinpoint {
    /**
     * 将参数作为数组对象获取。更改此数组中的元素值以更改参数
     */
    Object[] getArguments();
}
```

```java
package org.aopalliance.aop.intercept;

import java.lang.reflect.Constructor;

/**
 * 构造函数调用的描述，在构造函数调用时提供给拦截器
 */
public interface ConstructorInvocation extends Invocation {
    /**
     * 获取被调用的构造函数。
     * <p>此方法是 {@link Joinpoint#getStaticPart()} 方法的友好实现（结果相同）
     */
    Constructor<?> getConstructor();
}
```

```java
package org.aopalliance.aop.intercept;

import java.lang.reflect.Method;

/**
 * 方法调用的描述，在方法调用时提供给拦截器
 */
public interface MethodInvocation extends Invocation {
    /**
     * 获取被调用的方法。
     * <p>此方法是 {@link Joinpoint#getStaticPart()} 方法的友好实现（结果相同）
     */
    Method getMethod();
}
```

```java
package org.aopalliance.aop.intercept;

/**
 * 作用：拦截新对象的构造
 * <p>用户应该实现 {@link #construct(ConstructorInvocation)} 方法来修改原始行为。
 * <p>例如：
 * <pre class=code>
 * class DebuggingInterceptor implements ConstructorInterceptor {
 *   Object instance=null;
 *
 *   Object construct(ConstructorInvocation i) throws Throwable {
 *     if(instance==null) {
 *       return instance=i.proceed();
 *     } else {
 *       throw new Exception("singleton does not allow multiple instance");
 *     }
 *   }
 * }
 * </pre>
 */
public interface ConstructorInterceptor extends Interceptor  {
    /**
     * 实现此方法以在构建新对象之前和之后执行额外的处理。
     * <p>规范的实现是需要调用：{@link Joinpoint#proceed()}
     * @return 修改后的对象，因为Joinpoint.proceed()的结果，返回可能会被拦截器取代；
     */
    Object construct(ConstructorInvocation invocation) throws Throwable;
}
```

```java
package org.aopalliance.aop.intercept;

/**
 *
 */
@FunctionalInterface
public interface MethodInterceptor extends Interceptor {
    Object invoke(MethodInvocation invocation) throws Throwable;
}
```

### 实践

#### 预览

![image-20220901213324008](https://tva1.sinaimg.cn/large/e6c9d24ely1h5rfqz6qixj20iw0ju75a.jpg)

#### 实践代码

> model 包作用：基于接口的动态代理

```java
@Data
@AllArgsConstructor
public class User {
    private String userId;
    private String name;
}
// 一个接口两个方法的目的是为了AOP增强做对比
public interface UserClient {
    String addUser(User user);

    String updateUser(User user);
}
// UserClient 实现类
public class UserController implements UserClient {

    @Override
    public String addUser(User user) {
        return user.getName();
    }

    @Override
    public String updateUser(User user) {
        return "update success";
    }
}
```

> invocation包作用：在基于接口动态代理调用原来的方法时，对某些方法进行包装，生成调用实例

```java
public class UserAddInvocation implements MethodInvocation {
    /**
     * 拦截器（作为连接点，能够装在多个Advice增强）
     */
    private Queue<Interceptor> queue = new LinkedList<>();
    /**
     * 调用对象
     */
    private Object target;
    /**
     * 调用方法（静态连接点）
     */
    private Method method;
    /**
     * 调用参数
     */
    private Object[] args;

    private UserAddInvocation() {
    }

    public UserAddInvocation(Object target, Method method, Object[] args) {
        // 有顺序（我们决定调用时利用AOP增加事务以及日志Advice）
        queue.add(new TransactionInterceptor());
        queue.add(new LogInterceptor());
        this.target = target;
        this.method = method;
        this.args = args;
    }

    /**
     * 调用此初始化（动态代理方法执行时调用）
     *
     * @return
     */
    public static UserAddInvocation init(Object target, Method method, Object[] args) {
        return new UserAddInvocation(target, method, args);
    }

    @Override
    public Object[] getArguments() {
        return args;
    }

    @Override
    public Object proceed() throws Throwable {
        return queue.poll();
    }

    @Override
    public Object getThis() {
        return this;
    }

    @Override
    public Object getStaticPart() {
        return method;
    }

    @Override
    public Method getMethod() {
        return method;
    }

    public Object getTarget() {
        return target;
    }
    // 动态代理方法执行时调用（需要优先执行init()方法）
    public void start() {
        try {
            // 我们决定对addUser做增强，对其他方法选择原有逻辑不变
            if (getMethod().getName().equals("addUser")) {
                ((MethodInterceptor) proceed()).invoke((MethodInvocation) getThis());
            } else {
                Object invoke = getMethod().invoke(getTarget(), getArguments());
                System.out.println("other res: " + invoke);
            }
        } catch (Throwable throwable) {
            throwable.printStackTrace();
        }
    }
}
```

这里我们可以看到在进行`start()`方法调用时，里面包含了对其他方法的判断，这其实是不合理的，我们应该在这个类外部进行判断，也就是我们需要用到之后才会讲到的`Pointcut`来过滤出来目标方法，这里暂且在里面判断

> 拦截器包作用：对拦截到的方法进行增强

```java
// 日志增强
public class LogInterceptor implements MethodInterceptor {
    @Override
    public Object invoke(MethodInvocation invocation) throws Throwable {
        System.out.println("log advice success!");
        return null;
    }
}
// 事务增强
public class TransactionInterceptor implements MethodInterceptor {
    @Override
    public Object invoke(MethodInvocation invocation) throws Throwable {
        System.out.println("start transaction success!");
        Object invoke = invocation.getMethod().invoke(((UserAddInvocation) invocation).getTarget(), invocation.getArguments());
        System.out.println("exec success! userAdd() result is :" + invoke);
        System.out.println("end transaction success!");
        Object proceed = invocation.proceed();
        if (proceed != null) {
            return ((MethodInterceptor) proceed).invoke(invocation);
        }
        return null;
    }
}
```

> reflect包作用：用于动态代理

```java
public class UserClientInvocationHandler implements InvocationHandler {
    private UserClient userClient;

    public UserClientInvocationHandler(UserClient userClient) {
        this.userClient = userClient;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
      // 这里我们在即将调用到我们的原方法时，包装所有目标方法，生成调用实例（即：原方法调用连接点的描述）
        UserAddInvocation invocation = UserAddInvocation.init(userClient, method, args);
        invocation.start();
        return null;
    }
}
```

> 测试类

```java
public class JoinpointAdviceTest {
    private UserClient userClient;


    @Before
    public void init() {
        //
        userClient = new UserController();
    }

    @Test
    public void testUserAddAOP() {
        // 装配运行时调用
        System.out.println("基于接口创建代理");
        UserClient client = (UserClient) Proxy.newProxyInstance(UserController.class.getClassLoader(), new Class[]{UserClient.class}, new UserClientInvocationHandler(userClient));
        System.out.println("创建代理成功，针对addUser创建AOP");
        client.addUser(new User("1", "张三"));
        client.addUser(new User("1", "张三"));
        System.out.println("来看下updateUser是否有AOP");
        client.updateUser(new User("1", "李四"));
    }
}
// -------------------------输出
基于接口创建代理
创建代理成功，针对addUser创建AOP
start transaction success!
exec success! userAdd() result is :张三
end transaction success!
log advice success!
start transaction success!
exec success! userAdd() result is :张三
end transaction success!
log advice success!
来看下updateUser是否有AOP
other res: update success
```

### 总结

- **通知时机需要抽象化：**我们可以看到我们虽然是对`addUser`方法做了通知增强，但是我们应该知道AOP中具体定义了通知的时机（前置通知、后置通知、方法返回后通知、异常后通知等等），这使得我们只是实现这些代表着运行时通知时机的接口，就可以完成相应的通知
- **切入点需要抽象化：**对于拦截方法的过滤，我们希望可以尽量从简，不侵入的的方式达到目的，所以后续也会需要切入点的抽象

