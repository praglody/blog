---
title: 经典的客户端最多能发起65536个连接的误解
date: 2018-12-14 14:16:17
tags: 
  - tcp
  - network
categories:
  - network
---

"因为 TCP 端口号是 16 位无符号整数, 最大 65535, 所以一台服务器最多支持 65536 个TCP socket连接." - 一个非常经典的误解! 即使是有多年网络编程经验的人, 也会持有这个错误结论.

要戳破这个错误结论, 可以从理论和实践两方面来.

**理论：**

系统通过一个四元组来唯一标识一条 TCP 连接. 这个四元组的结构是(local_ip, local_port, remote_ip, remote_port), 对于 IPv4, 系统理论上最多可以管理 2^(32+16+32+16), 2 的 96 次方个连接.

对于一个 tcp client而言，本地 ip 是确定的，server 的 ip 和 port 也是确定的，那么客户端能够维持的 TCP 连接数量是 2^16（65536）个。如果我们在 server 上再多监听一个端口，那么理论上 client 到 server 之间就能够维持 2^16 * 2 个 TCP 连接。

**实践：**

TCP 客户端（TCP 的主动发起者）可以在同一 ip:port 上向不同的服务器发起主动连接, 只需在 Bind 之前对 socket 设置 SO_REUSEADDR 选项即可。

服务器端代码：
```go
func main() {
	// 同时监听两个端口
	go startServer(8000)
	startServer(8001)
}

func startServer(port int) {
	var fd int
	var err error
	var ServerAddr syscall.SockaddrInet4
	if fd, err = syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, syscall.IPPROTO_IP); err != nil {
		panic(err)
	}

	ServerAddr.Port = port
	ServerAddr.Addr = [4]byte{0, 0, 0, 0}
	if err = syscall.Bind(fd, &ServerAddr); err != nil {
		panic(err)
	}

	if err = syscall.Listen(fd, 512); err != nil {
		panic(err)
	}

	for {
		// accept 一个连接
		nfd, sa, err := syscall.Accept(fd)
		fmt.Println(nfd, sa, err)

		time.Sleep(time.Second * 3)
		syscall.Close(nfd)
		fmt.Println("close conn")
	}
}
```

客户端代码：

```go
var mu sync.Mutex

func main() {
	var localPort = 3000 // 本地端口

	// 连接到服务器 8000 端口
	go userConnect(localPort, 8000)

	// 连接到服务器 8001 端口
	userConnect(localPort, 8001)
}

func userConnect(localPort, serverPort int) {
	var fd int
	var err error
	var ServerAddr syscall.SockaddrInet4

	if fd, err = syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, syscall.IPPROTO_IP); err != nil {
		panic(err)
	}

	if err = syscall.SetsockoptInt(fd, syscall.SOL_SOCKET, syscall.SO_REUSEADDR, 1); err != nil {
		panic(err)
	}

	ServerAddr.Port = localPort
	ServerAddr.Addr = [4]byte{127, 0, 0, 1}

	// 绑定本地端口
	mu.Lock()
	if err = syscall.Bind(fd, &ServerAddr); err != nil {
		panic(err)
	} else {
		fmt.Printf("Bind port %d\n", localPort)
	}
	mu.Unlock()

	ServerAddr.Port = serverPort
	ServerAddr.Addr = [4]byte{127, 0, 0, 1}

	if err = syscall.Connect(fd, &ServerAddr); err != nil {
		panic(err)
	} else {
		fmt.Printf("Connect success\n")
	}

	time.Sleep(time.Second * 10)
}
```

**是什么限制了服务器的 TCP 连接数：**

1. 端口范围

如果某个客户端向同一个 TCP 端点 (ip:port) 发起主动连接, 那么每一条连接都必须使用不同的本地TCP端点, 如果客户端只有一个IP则是使用不同的本地端口, 该端口的范围在 linux 系统上的一个例子是32768到61000, 可以通过如下命令查看:

```
[root@VM_0_13_centos ~]# cat /proc/sys/net/ipv4/ip_local_port_range
32768	60999
```

也就是说, 一个客户端连接同一个服务器的同一个ip:port(比如进行压力测试), 最多可以发起30000个左右的连接.

TCP客户端(TCP的主动发起者)可以在同一ip:port上向不同的服务器发起主动连接, 只需在bind之前对socket设置 `SO_REUSEADDR` 选项.

2. 系统支持的最大打开文件描述符数

全局限制：
```
[root@VM_0_13_centos ~]# cat /proc/sys/fs/file-max
183994
```

进程限制：
```
[root@VM_0_13_centos ~]# ulimit -n
10240
```

**结论：**

无论是对于服务器还是客户端, 认为“一台机器最多建立65536个TCP连接”是没有根据的, 理论上远远超过这个值.

另外, 对于client端, 操作系统会自动根据不同的远端 ip:port, 决定是否重用本地端口.
