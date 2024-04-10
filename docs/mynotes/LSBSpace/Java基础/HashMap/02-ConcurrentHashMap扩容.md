1. Cmap 支持并发扩容，实现方式是，将表拆分，让每个线程处理自己的区间。如下图： 

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h53xvmyz6aj213s0c2ab6.jpg)

假设总长度是 64 ，每个线程可以分到 16 个桶，各自处理，不会互相影响。

1. 而每个线程在处理自己桶中的数据的时候，是下图这样的：

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h53xvra005j21760u0tad.jpg)

扩容前的状态。

当对 4 号桶或者 10 号桶进行转移的时候，会将链表拆成两份，规则是根据节点的 hash 值取于 length，如果结果是 0，放在低位，否则放在高位。

因此，10 号桶的数据，黑色节点会放在新表的 10 号位置，白色节点会放在新桶的 26 号位置。

下图是循环处理桶中数据的逻辑 

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h53xvvfru5j213c0homzp.jpg)

处理完之后，新桶的数据是这样的 

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h53xvz6a8zj21h20nqjsu.jpg)