# Spring AOP源码解析（2）

[TOC]

## AOP基础类封装相关

### Advisor

```java
public interface Advisor {
  // 空通知
  Advice EMPTY_ADVICE = new Advice() {};
  // 可以获取到通知（例如：拦截器）
  Advice getAdvice();
  // 暂时未知
  boolean isPerInstance();
}
```

#### PointcutAdvisor

```java
// 切入点通知器（个人理解：可以找到切入点，然后做通知增强）
public interface PointcutAdvisor extends Advisor {
	// 拥有了获取切入点的功能
  Pointcut getPointcut();
}
```

#### AbstractPointcutAdvisor

> 实现了可以执行顺序

```java
public abstract class AbstractPointcutAdvisor implements PointcutAdvisor, Ordered, Serializable {
  
}
```

### StaticMethodMatcherPointcut

> 本身为方法匹配器的切入点实现
>
> 该抽象类的子实现可以**提供**判断**是否是切入点**，并判断**是否需要切入点方法的参数**的功能

```java
public abstract class StaticMethodMatcherPointcut extends StaticMethodMatcher implements Pointcut {
	// 类过滤
	public ClassFilter getClassFilter() {
		return this.classFilter;
	}

  // 方法匹配器
	public final MethodMatcher getMethodMatcher() {
		return this;
	}
}
```

### 例子：

#### TransactionAttributeSourcePointcut

> 事务属性元切入点，有属性元的会匹配到

```java
// 继承了StaticMethodMatcherPointcut，说明可以提供判断切入点的功能，并切不需要切入点的方法参数
abstract class TransactionAttributeSourcePointcut extends StaticMethodMatcherPointcut implements Serializable {
	// 遍历所有方法，匹配拥有事务属性的方法
  public boolean matches(Method method, Class<?> targetClass) {
		TransactionAttributeSource tas = getTransactionAttributeSource();
		return (tas == null || tas.getTransactionAttribute(method, targetClass) != null);
	}
  
  // 由子类实现该方法
  protected abstract TransactionAttributeSource getTransactionAttributeSource();
  
  // 内部（类过滤器）
  private class TransactionAttributeSourceClassFilter implements ClassFilter {

		public boolean matches(Class<?> clazz) {
      // <1> 目标类是 Spring 内部的事务相关类，则跳过，不需要创建代理对象
			if (TransactionalProxy.class.isAssignableFrom(clazz) ||
					TransactionManager.class.isAssignableFrom(clazz) ||
					PersistenceExceptionTranslator.class.isAssignableFrom(clazz)) {
				return false;
			}
      // <2 获取 AnnotationTransactionAttributeSource 对象
			TransactionAttributeSource tas = getTransactionAttributeSource();
      // <3> 解析该方法相应的 @Transactional 注解，并将元信息封装成一个 TransactionAttribute 对象
      // 且缓存至 AnnotationTransactionAttributeSource 对象中
			// <4> 如果有对应的 TransactionAttribute 对象，则表示匹配，需要进行事务的拦截处理
			return (tas == null || tas.isCandidateClass(clazz));
		}
	}
}
```

