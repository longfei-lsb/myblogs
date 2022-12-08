# 棒子的空间

[TOC]

## 安装git

https://git-scm.com/downloads

## 克隆项目

```shell
git clone https://github.com/longfei-lsb/myblogs.git
```

并用 IDEA 打开项目

## 项目操作

> <font color = red size = 4>**以下所有步骤请在 “myblogs” 目录下操作！！！**</font>

**拉取最新项目代码：**

```shell
git pull
```

**创建并切换到自己的分支：**

```
git checkout -b <自己的分支名>
```

**与自己的远程分支建立关联：**

```
git push --set-upstream origin <自己的分支名>
```

**提交修改的东西：**

```shell
# 暂存
git add .
# 提交
git commit -am <本次提交的描述>
# 推送到远程仓库
git push
```

