# Scrapy笔记

## 安装

1. 安装: 通过`pip install scrapy` 即可安装
2.  Scrapy官方文档:  https://scrapy.org/en/latest 

>注意:
>
>1. 在ubuntu上安装scrapy之前需要安装以下依赖:
>
>   sudo apt-get install python-dev python-pip libxml2-dev libxslt1-dev zlibig-dev libffi-dev libssl-dev, 然后在通过pip install scrapy安装
>
>2. 如果是windows系统,需要使用pip install pypiwin32安装pypiwin32,否则可能出现错误
>
>

## 快速入门

1. 创建`scrapy`工程:  `scrapy startproject 项目名`

2. 初始化工程: `scrapy genspider 爬虫名称  需要爬取的网站`

3.  启动`scrapy`项目: `scrapy crawl 爬虫名称`

   开始更改ROBOTSTXT_OBEY = False,打开request_headers

**目录结构:**

![image-20200405161045601](Scrapy笔记.assets/image-20200405161045601.png)

## 项目目录结构

1. items.py:用来存放爬虫爬取下来数据的模型。
2. middlewares.py:用来存放各种中间件的文件。
3. pipelines.py:用来将items 的模型存储到本地磁盘中。
4. settings.py:本爬虫的一-些配置信息(比如请求头、多久发送一-次请求、ip代理池等)。
5. scrapy.cfg: 项目的配置文件。
6. spiders包:以后所有的爬虫,都是存放到这个里面。

## 爬虫笔记

1. response是一个scrapy.http.response.html.HTMLResponse对象,可以使用xpath和css来提取数据

2. 提取出来的数据是一个Seletor或则是一个SelectorList对象,如果想要获取字符串,那么应该执行getall 或则get方法

3. getall方法:获取的是Selector中的文本,返回的是一个列表

4. get方法:获取的是Selector中的第一个文本,返回的是一个str类型

5. 如果数据解析回来,要传给pipline处理,那么可以使用yield来返回,或则是收集所有的item,最后统一使用return返回

6. item:建议在items.py定义好模型

7. pipeline: 专门用来保存数据的,其中三个方法是经常用的

   - open-spider(self, spider):当爬虫被打开的时候执行

   - process_item(self, item,spider): 当爬虫有itme传过来的时候会被调用

   - close_spider(self,spider):当爬虫关闭的时候会调用

     要激活pipline,应该再settings.py中,设置ITEM_PIPELINES

### JsonItemExporter和JsonLinesItemExporter

保存json数据的时候,可以使用这两个类,让操作变得更加简单

1. JsonItemExporter:这个是每次把数据添加到内存中,最后一次写入磁盘中,好处是储存的数据是一个json规则的数据,坏处是如果数据量大,会比较耗内存

   示例:

   ``` python
   from scrapy.exporters import JsonItemExporter
   #
   # class DoubanCrawlPipeline(object):
   #     def __init__(self):
   #         self.fp = open("douban.json", "wb")
   #         self.exporter = JsonItemExporter(self.fp,ensure_ascii=False, encoding='utf-8')
   #         self.exporter.start_exporting()
   #     def open_spider(self, spider):
   #         print("crawl starting...")
   #
   #     def process_item(self, item, spider):
   #         self.exporter.export_item(item)
   #         return item
   #
   #     def close_spider(self, spider):
   #         self.exporter.finish_exporting()
   #         self.fp.close()
   #         print("crawl finish.")
   
   ```

   

2. JsonLinesItemExporter:每次调用export_item的时候就把这个item储存到硬盘中,坏处是每一个字典是一行,整个文件不是一个满足json格式的文件,好处是每次处理数据就储存到硬盘中,不会耗费内存

   实例:

   ``` python
   
   from scrapy.exporters import JsonLinesItemExporter
   class DoubanCrawlPipeline(object):
       def __init__(self):
           self.fp = open("douban.json", "wb")
           self.exporter = JsonLinesItemExporter(self.fp,ensure_ascii=False, encoding='utf-8')
   
       def open_spider(self, spider):
           print("crawl starting...")
   
       def process_item(self, item, spider):
           self.exporter.export_item(item)
           return item
   
       def close_spider(self, spider):
           self.fp.close()
           print("crawl finish.")
   ```

   

	开始更改ROBOTSTXT_OBEY = False,打开request_headers
	
	
### **案例1**:

爬取www.yicommunity.com中的数据,原本打算爬取douban的,结果发现豆瓣有反爬机制

1. 创建工程

   * 切换到python工程文件夹,打开cmd输入:

   scrapy startproject douban

   * 切换到douban目录:cd douban
   * 创建爬虫文件: scrapy genspider douban_spider http://www.yicommunity.com/
   * 

2. 编写代码

   * 修改settings.py

     ``` python
     #开启后会自动读取robots.txt中的规则
     ROBOTSTXT_OBEY = False   
     #开启延时,防止速度太快,被服务区封ip
     DOWNLOAD_DELAY = 1		
     #添加请求头信息,将爬虫伪装成正常的浏览器访问
     DEFAULT_REQUEST_HEADERS = {
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
     'Accept-Language': 'en',
          }
     #开启后才可以使用进行保存文件
     ITEM_PIPELINES = {
        'douban_crawl.pipelines.DoubanCrawlPipeline': 300,
     }
     ```

   * 编写douban.py文件

     ``` python
     # -*- coding: utf-8 -*-
     import scrapy
     from scrapy.http.response.html import HtmlResponse
     from scrapy.selector.unified import SelectorList
     from douban_crawl.items import DoubanCrawlItem
     
     class DoubanSpider(scrapy.Spider):
     # 原本打算 爬取豆瓣的发现爬不了
         name = 'douban'
         allowed_domains = ['http://www.yicommunity.com/']
         start_urls = ['http://www.yicommunity.com/remen/']
         base_url = 'http://www.yicommunity.com'
     
         def parse(self, response):
             print("=="*40)
             doubandivs = response.xpath("//div[@class='col1']/div")
             for doubandiv in doubandivs:
                 author = doubandiv.xpath(".//div[@class='author']/text()").get()
                 content = doubandiv.xpath(".//div[@class='content']/text()").getall()
                 content = "".join(content).strip()
                 # print(content)
                 # douban = {"author": author, "content": content}
                 item = DoubanCrawlItem(author=author, content=content)
                 yield item
                 next_url = response.xpath("//div[@class='pagebar']/a[last()]/@href").get()
                 print("url"+next_url)
                 if not next_url:
                     return
                 else:
                     yield scrapy.Request(self.base_url + next_url, callback=self.parse, dont_filter=True)
     
     ```

   - 修改item.py,将保存的文件以对象形式进行保存

     ``` python
     import scrapy
     
     class DoubanCrawlItem(scrapy.Item):
         author = scrapy.Field()
         content = scrapy.Field()
     ```

   - 修改pipelines.py

     ``` python
     # -*- coding: utf-8 -*-
     
     # Define your item pipelines here
     #
     # Don't forget to add your pipeline to the ITEM_PIPELINES setting
     # See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html
     import json
     
     ### 法一:
     # class DoubanCrawlPipeline(object):
     #     def __init__(self):
     #         self.fp = open("douban.json", "w", encoding="utf-8")
     #
     #     def open_spider(self, spider):
     #         print("crawl starting...")
     #
     #     def process_item(self, item, spider):
     #         item_json = json.dumps(dict(item), ensure_ascii=False)
     #         self.fp.write(item_json + "\n")
     #         return item
     #
     #     def close_spider(self, spider):
     #         self.fp.close()
     #         print("crawl finish.")
     
     
     ## 法二
     from scrapy.exporters import JsonItemExporter
     #
     # class DoubanCrawlPipeline(object):
     #     def __init__(self):
     #         self.fp = open("douban.json", "wb")
     #         self.exporter = JsonItemExporter(self.fp,ensure_ascii=False, encoding='utf-8')
     #         self.exporter.start_exporting()
     #     def open_spider(self, spider):
     #         print("crawl starting...")
     #
     #     def process_item(self, item, spider):
     #         self.exporter.export_item(item)
     #         return item
     #
     #     def close_spider(self, spider):
     #         self.exporter.finish_exporting()
     #         self.fp.close()
     #         print("crawl finish.")
     
     ### 法三
     from scrapy.exporters import JsonLinesItemExporter
     class DoubanCrawlPipeline(object):
         def __init__(self):
             self.fp = open("douban.json", "wb")
             self.exporter = JsonLinesItemExporter(self.fp,ensure_ascii=False, encoding='utf-8')
     
         def open_spider(self, spider):
             print("crawl starting...")
     
         def process_item(self, item, spider):
             self.exporter.export_item(item)
             return item
     
         def close_spider(self, spider):
             self.fp.close()
             print("crawl finish.")
     ```

   
   - 编写启动文件
   
     ``` python
     from scrapy import cmdline
     cmdline.execute("scrapy crawl douban".split())
     ```
   
     

### CrawlSpider

首先创建crawlspider工程:
	- scrapy startproject wxapp
	- scrapy genspider -t crawl wxapp_spider wxapp-union.com
需要使用`LinkExtractor` 和`Rule`这两个东西来决定爬虫的具体走向

1. allow设置规则的方法,要能够限制在我们想要url上面,不要更其他的url产生相同的正则表达式
2. 什么情况下使用follow,如果在爬取页面的时候,需要将满足当前条件的url在进行更进,那么就设置为true,否则设置为false
3. 什么情况下使用callback,如果这个url对应的页面,只是为了获取更多的url,并不需要里面的数据,那么可以不指定callback,如果想要获取url对应页面的数据,那么就需要指定一个callback