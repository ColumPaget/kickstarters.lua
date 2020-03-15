SYNOPSIS
========

kickstarter.lua is a search tool for kickstarter projects that runs from the linux console. It requries lua, libUseful and libUseful-lua to be installed.



LICENSE 
======= 
 
castclient.lua is released under the GPLv3 and is copyright Colum Paget 2019



USAGE
=====

```

kickstarter.lua [options] <search term>
kickstarter.lua -cat-list

```


OPTIONS
=======

```

-cat-list                      list categories rather than doing a search
-pages <count>                 get <count> pages of results, rather than just the first page
-p <count>                     get <count> pages of results, rather than just the first page
-proxy <url>                   use network proxy at <url>
-P <url>                       use network proxy at <url>
-category <category name>      return results for this category
-c <category name>             return results for this category

```




PROXIES
=======

kickstarter.lua uses several environment variables to set a proxy to use. These are `socks_proxy` `SOCKS_PROXY` `HTTPS_PROXY` `https_proxy ` `all_proxy` and `kickstarter_proxy`. These can be set to urls like `socks5:127.0.0.1:8080` and `https://user:password@proxyhost.com`. A proxy can also be set using the `-proxy` or `-P` command-line options which override the environment variables.



EXAMPLES
========

```
kickstarter.lua cake
kickstarter.lua -c "games/video games" strategy
```
