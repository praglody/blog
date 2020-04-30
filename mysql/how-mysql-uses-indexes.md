---
title: How MySQL Uses Indexes
date: 2020-04-28 04:28
categories: mysql
tags: mysql
---

提升 MYSQL 查询性能最好的方法就是针对查询语句创建合适的索引。

<!--more-->

## MySQL 是如何利用索引的

MySQL 索引可以快速的检索指定的字段。如果没有建立索引，MySQL 需要从数据表的第一行扫描到最后一行，越大的表，查询成本越大。

MySQL 的大多数索引类型都使用 B-trees 数据结构存储，包括 PRIMARY KEY、UNIQUE、INDEX、和 FULLTEXT。除此之外，空间索引使用R-trees；MEMORY表额外支持Hash-indexs；InnoDB引擎使用倒排索引（interted lists）结构存储FULLTEXT。
