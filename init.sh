#! /bin/bash

hexo=$(which hexo)

rm -f ../categories/index.md ../tags/index.md

# 增加分类页面
$hexo new page categories
sed -i "/date/atype: categories" ../categories/index.md

# 增加标签页面
$hexo new page tags
sed -i "/date/atype: tags" ../tags/index.md

