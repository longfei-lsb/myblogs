# Spring面试题

[TOC]

## <font size = '4' color = 'pink'>什么是Spring的IOP？</font>

> AOP(Aspect-Oriented Programming)是面向切面编程
>
> 它可以在已有的代码上增加额外的行为，却不需要修改已有的代码

面向对象编程大多数对象都遵循单一职责原则，自己做好自己的事情，实际上它们之间有一些共同的事情要做。

比如日志，事务，认证操作

虽然利用OOP的方式也可以实现，但是相较于AOP来说，本身还是在代码中比AOP耦合的更多，AOP基本不需要侵入修改原本的代码，而是通过指定代码的切点来实现

- **pointcut：**切点的定义会匹配通知所要织入的一个或多个连接点

```xml
<aop:config>
        <!-- 定义切点 -->
        <aop:pointcut id="hello" expression="execution(public * * (..))"></aop:pointcut>
       ...
</aop:config>
```

- **advice：**就是我们要具体做的事情，也就在原有的方法之上添加新的能力
  - MthodBeforeAdvice：目标方法实施前增强
  - AfterReturningAdvice：目标方法实施后增强
  - ThrowsAdvice 异常抛出增强
  - IntroductionAdvice 引介增强，为目标类添加新的属性和方法。可以构建组合对象来实现多继承
  - MethodInterceptor 方法拦截器，环绕增强，在方法的前后实施操作