# Spring AOP源码解析（1）

[TOC]

## 顶层接口分析

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

#### 其他通知类型

```java
public interface BeforeAdvice extends Advice{}// 前置通知规范接口，内部无实现
public interface AfterAdvice extends Advice {}// 后置通知规范接口，内部无实现
public interface ThrowsAdvice extends AfterAdvice{}// 异常后通知规范接口，内部无实现
// 方法调用后正常通知规范接口，内部无实现
public interface AfterReturningAdvice extends AfterAdvice {
  // 根据返回的值，方法，类，参数进行增强
  void afterReturning(@Nullable Object returnValue, Method method, Object[] args, @Nullable Object target) throws Throwable;
}
// 方法前通知
public interface MethodBeforeAdvice extends BeforeAdvice {
  void before(Method method, Object[] args, @Nullable Object target) throws Throwable;
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

> MethodMatcher 通过重载，定义了两个 matches 方法，而这两个方法的分界线就是 isRuntime 方法，这里要特别注意！
>
> 注意到三参数的matches方法中，最后一个参数是args，因此也就可以想到：两个 mathcers 方法的区别在于，在进行方法拦截
>
> 的时候，是否匹配方法的参数
>
> 　　比如：现在要对 登录方法 login(String username, String passwod) 进行拦截 
> 　　1. 只想在 login 方法之前插入计数功能，那么 login 方法的参数对于 Joinpoint 捕捉就是可以忽略的。 
> 　　1.  在用户登录的时候对某个用户做单独处理（拒绝登录 或 给予特殊权限），那么方法的参数在匹配 Joinpoint 时必须要考虑到**
>
> 　　**根据是否对方法的参数进行匹配，Pointcut可以分为StaticMethodMatcher和DynamicMethodMatcher**
>
> **当isRuntime()返回false**，表明不对参数进行匹配，为StaticMethodMatcher，返回true时，表示要对参数进行匹配，为DynamicMethodMatcher
> 　　**一般情况下，DynamicMethodMatcher会影响性能，所以我们一般使用StaticMethodMatcher就行了**

```java
public interface MethodMatcher {
  // 是否匹配
  boolean matches(Method method, Class<?> targetClass);
  boolean matches(Method method, Class<?> targetClass, Object... args);
  // 是否运行时
  boolean isRuntime();
  // 匹配所有方法的规范实例
  MethodMatcher TRUE = TrueMethodMatcher.INSTANCE;
}
```

##### StaticMethodMatcher

> 不关心运行时的参数

```java
public abstract class StaticMethodMatcher implements MethodMatcher {
  // false表示，不需要匹配方法的参数
  public final boolean isRuntime() {
		return false;
	}
  public final boolean matches(Method method, Class<?> targetClass, Object... args) {
		// should never be invoked because isRuntime() returns false
		throw new UnsupportedOperationException("Illegal MethodMatcher usage");
	}
}
```

##### DynamicMethodMatcher

> 关心运行时的参数（care about arguments at runtime）

```java
public abstract class DynamicMethodMatcher implements MethodMatcher {
public final boolean isRuntime() {
		return true;
	}
  public boolean matches(Method method, Class<?> targetClass) {
		return true;
	}
}
```
