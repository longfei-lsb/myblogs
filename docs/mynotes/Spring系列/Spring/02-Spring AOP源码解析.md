# Spring AOP源码解析

[TOC]

## 顶层接口与类的分析

### 介绍

![image-20220820080424678](https://tva1.sinaimg.cn/large/e6c9d24ely1h5cwp6zsf9j20js0mmdh4.jpg)

**三个包：**

**aop、intercept、springframework.aop**

`AOP`顶层结构图

![image-20220820080818059](https://tva1.sinaimg.cn/large/e6c9d24ely1h5cwt6x7atj20u00uatab.jpg)

```properties
Advice（通知）:个人理解是任何对横切点会做改动的类或接口都称为通知

Joinpoint:程序执行的某个特定位置（如：某个方法调用前、调用后，方法抛出异常后）,Spring仅支持方法的连接点

Interceptor（拦截器）:通知的一种,对横切点会做改动

Invocation（调用）:表示程序中的调用,调用是一个连接点，可以被Interceptor拦截

# 以下是：Interceptor 拦截 Invocation（因为Advice 可以在某个连接点做改动）

ConstructorInterceptor:拦截构造函数的调用（字面意思）

MethodInterceptor:拦截方法的调用
```

### Joinpoint

```java
// 这个接口代表一个通用的运行时连接点
public interface Joinpoint {
  /**
   * 作为连接点而言，可能会有多个拦截器进行拦截，所以需要有一个获取下一个`interceptor`的功能方	 * 法，所以有了
	 */
  @Nullable
	Object proceed() throws Throwable;
  // 自然是需要获取到连接点对象的，不一定都是类中的this，所以提供了一个方法交给子类自己实现
  @Nullable
	Object getThis();
  // 暂时未知（本篇只是用来分析源码，最后我们可以再重新看一下，说不定会有新的认识）
  // 静态部分是安装了拦截器链的可访问对象（Spring官方解释）
  @Nonnull
	AccessibleObject getStaticPart();
}
```

#### 连接点子实现：Invocation（各种调用）

> Spring中函数的调用就是连接点，包括构造函数调用、普通方法调用、代理方法调用等

```java
public interface Invocation extends Joinpoint{
	// 获取方法调用参数
	Object[] getArguments();
}
```

##### MethodInvocation（方法调用）

```java
Method getMethod();
```

##### ConstructorInvocation（构造函数调用）

```java
// 获取构造函数
Constructor<?> getConstructor();
```

##### ProxyMethodInvocation（代理方法调用）

```java
// 获取代理对象
Object getProxy();
// 
MethodInvocation invocableClone();
//
MethodInvocation invocableClone(Object... arguments);
// 设置参数
void setArguments(Object... arguments);
// 设置用户属性
void setUserAttribute(String key, @Nullable Object value);
// 获取用户属性
Object getUserAttribute(String key);
```

### Advice

> 通过Advice对连接点进行增强

#### Interceptor

> 拦截器：通过拦截器对连接点进行增强

##### ConstructorInterceptor

```java
// 构造函数拦截器
public interface ConstructorInterceptor extends Interceptor  {
  // 可以在构造方法前后做增强
	Object construct(ConstructorInvocation invocation) throws Throwable;
}
```

##### MethodInterceptor

```java
@FunctionalInterface
public interface MethodInterceptor extends Interceptor {
  // 可以通过调用，获取方法，然后在方法前后做增强
  Object invoke(@Nonnull MethodInvocation invocation) throws Throwable;
}
```

### Pointcut

> 用来标注在方法上来定义切入点

```java
// 定义切入点信息，用于选择在哪里做增强
public interface Pointcut {
  // 类过滤器
  ClassFilter getClassFilter();
  // 方法匹配器
  MethodMatcher getMethodMatcher();
  // 始终匹配的规范切入点实例
  Pointcut TRUE = TruePointcut.INSTANCE;
}
```

#### ClassFilter

```java
@FunctionalInterface
public interface ClassFilter {
  // 类是否匹配
	boolean matches(Class<?> clazz);
	ClassFilter TRUE = TrueClassFilter.INSTANCE;
}
```

#### MethodMatcher

```java
public interface MethodMatcher {
  // 是否匹配
  boolean matches(Method method, Class<?> targetClass);
  // 是否动态
  boolean isRuntime();
  boolean matches(Method method, Class<?> targetClass, Object... args);
  // 匹配所有方法的规范实例
  MethodMatcher TRUE = TrueMethodMatcher.INSTANCE;
}
```
