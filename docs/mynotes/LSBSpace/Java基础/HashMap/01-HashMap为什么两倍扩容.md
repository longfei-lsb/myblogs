# HashMap为什么两倍扩容？

```java
// table的长度（2倍扩容）
n = (tab = resize()).length;
// (n - 1) & hash 来计算在table中的索引位置
tab[i = (n - 1) & hash]
```

HashMap的容量为什么是2的n次幂，和这个(n - 1) & hash的计算方法有着千丝万缕的关系

**想一想：**n为2的倍数，则n二进制 10000000000……；(n - 1) 的二进制 0111111111……

当HashMap的容量是16时，它的二进制是10000，(n-1)的二进制是01111，与hash值按位&得计算结果如下：

![HashMap为什么2倍扩容](https://tva1.sinaimg.cn/large/e6c9d24ely1h4uv1t260xj20jg08u0t4.jpg)

再来看看容量为10的情况下：

![HashMap为什么2倍扩容](https://tva1.sinaimg.cn/large/e6c9d24ely1h4uv761wxij20jg091mxn.jpg)

**结论说明：**如果是二倍扩容，不同的hash值计算出来的结果必然不同，并且与hash值相同，那就意味着，同样的hash，不管在则怎么扩容，hash不变，索引位置不变

**所以二倍扩容的作用：**

- **减少hash碰撞**
- **尽可能的减少元素位置的移动**