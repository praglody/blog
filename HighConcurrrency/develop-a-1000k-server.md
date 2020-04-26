---
title: 构建C1000K的服务器
date: 2018-12-14 14:16:17
tags:
---

著名的 C10K 问题提出的时候, 正是 2001 年, 到如今 C10K 已经不是问题了, 任何一个普通的程序员, 都能利用手边的语言和库, 轻松地写出 C10K 的服务器. 这既得益于软件的进步, 也得益于硬件性能的提高.

现在, 该是考虑 C1000K, 也就是百万连接的问题的时候了. 像 Twitter, weibo, Facebook 这些网站, 它们的同时在线用户有上千万, 同时又希望消息能接近实时地推送给用户, 这就需要服务器能维持和上千万用户的 TCP 网络连接, 虽然可以使用成百上千台服务器来支撑这么多用户, 但如果每台服务器能支持一百万连接(C1000K), 那么只需要十台服务器.

有很多技术声称能解决 C1000K 问题, 例如 Erlang, Java NIO 等等, 不过, 我们应该首先弄明白, 什么因素限制了 C1000K 问题的解决. 主要是这几点:

- 操作系统能否支持百万连接?
- 操作系统维持百万连接需要多少内存?
- 应用程序维持百万连接需要多少内存?
- 百万连接的吞吐量是否超过了网络限制?

下面来分别对这几个问题进行分析.

## 1. 操作系统能否支持百万连接?

对于绝大部分 Linux 操作系统, 默认情况下确实不支持 C1000K! 因为操作系统包含最大打开文件数(Max Open Files)限制, 分为系统全局的, 和进程级的限制.

- 全局限制

在 Linux 下执行:
```shell
[root@centos ~]# cat /proc/sys/fs/file-nr
1568	0	184278
```

第三个数字 184278 就是当前系统的全局最大打开文件数(Max Open Files), 可以看到, 只有 18 万, 所以, 在这台服务器上无法支持 C1000K. 很多系统的这个数值更小, 为了修改这个数值, 用 root 权限修改 `/etc/sysctl.conf` 文件:

```shell
fs.file-max = 1020000
net.ipv4.ip_conntrack_max = 1020000
net.ipv4.netfilter.ip_conntrack_max = 1020000
```

如何生效：
```shell
# Linux
$ sudo sysctl -p /etc/sysctl.conf

# BSD
$ sudo /etc/rc.d/sysctl reload
```

- 进程限制

执行：
```
[root@centos ~]# ulimit -n
1024
```

说明当前 Linux 系统的每一个进程只能最多打开 1024 个文件. 为了支持 C1000K, 你同样需要修改这个限制.

临时修改：
```
ulimit -n 1020000
```

不过, 如果你不是 root, 可能不能修改超过 1024, 否则会报错:
```
[zhudp@centos ~]$ ulimit -n 1025
-bash: ulimit: open files: cannot modify limit: Operation not permitted
```

永久修改：

编辑 /etc/security/limits.conf 文件, 加入如下行:

```
# /etc/security/limits.conf
root         hard    nofile      1020000
root         soft    nofile      1020000
```

第一列的 root 表示 root 用户, 你可以填 *, 或者其他用户名. 然后保存退出, 重新登录服务器.

注意: Linux 内核源码中有一个常量(NR_OPEN in /usr/include/linux/fs.h), 限制了最大打开文件数, 如 RHEL 5 是 1048576(2^20), 所以, 要想支持 C1000K, 你可能还需要重新编译内核.


## 2. 操作系统维持百万连接需要多少内存?





## 3. 应用程序维持百万连接需要多少内存?


## 4. 百万连接的吞吐量是否超过了网络限制?




