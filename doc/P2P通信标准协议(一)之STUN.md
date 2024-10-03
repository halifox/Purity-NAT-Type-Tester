> https://www.cnblogs.com/pannengzhi/p/5041546.html

## STUN简介

在前言里我们看到，RFC3489和RFC5389的名称都是STUN，但其全称是不同的。在RFC3489里，  
STUN的全称是**Simple Traversal of User Datagram Protocol (UDP) Through Network Address Translators (NATs)**，  
即穿越NAT的简单UDP传输，是一个轻量级的协议，允许应用程序发现自己和公网之间的中间件类型，  
同时也能允许应用程序发现自己被NAT分配的公网IP。这个协议在2003年3月被提出，其介绍页面里  
说到已经被[STUN/RFC5389](http://www.rfc-editor.org/info/rfc5389)所替代，后者才是我们要详细介绍的。

RFC5389中，STUN的全称为**Session Traversal Utilities for NAT**，即NAT环境下的会话传输工具，  
是一种处理NAT传输的协议，但主要作为一个工具来服务于其他协议。和STUN/RFC3489  
类似，可以被终端用来发现其公网IP和端口，同时可以检测端点间的连接性，也可以作为一种保活（keep-alive）协议来维持NAT的绑定。  
和RFC3489最大的不同点在于，STUN本身不再是一个完整的NAT传输解决方案，而是在NAT传输环境中作为一个辅助的解决方法，  
同时也增加了TCP的支持。RFC5389废弃了RFC3489，因此后者通常称为**classic STUN**，但依旧是后向兼容的。  
而完整的NAT传输解决方案则使用STUN的工具性质，[ICE](http://www.rfc-editor.org/info/rfc5245)就是一个基于[offer/answer](http://www.rfc-editor.org/info/rfc3264)方法的完整NAT传输方案，如[SIP](http://www.rfc-editor.org/info/rfc3261)。

STUN是一个C/S架构的协议，支持两种传输类型。一种是请求/响应（request/respond）类型，由客户端给服务器发送请求，  
并等待服务器返回响应；另一种是指示类型（indication transaction），由服务器或者客户端发送指示，另一方不产生响应。  
两种类型的传输都包含一个96位的随机数作为事务ID（transaction ID），对于请求/响应类型，事务ID允许客户端将响应和产生响应的请求连接起来；  
对于指示类型，事务ID通常作为debugging aid使用。

所有的STUN报文信息都含有一个固定头部，包含了方法，类和事务ID。方法表示是具体哪一种传输类型（两种传输类型又分了很多具体类型），  
STUN中只定义了一个方法，即binding（绑定），其他的方法可以由使用者自行拓展；Binding方法可以用于请求/响应类型和指示类型，  
用于前者时可以用来确定一个NAT给客户端分配的具体绑定，用于后者时可以保持绑定的激活状态。类表示报文类型是请求/成功响应/错误响应/指示。  
在固定头部之后是零个或者多个属性（attribute），长度也是不固定的。

## STUN报文结构

STUN报文和大多数网络类型的格式一样，是以大端编码(big-endian)的，即最高有效位在左边。所有的STUN报文都以20字节的头部开始，后面跟着若干个属性。下面来详细说说。

### STUN报文头部

STUN头部包含了STUN消息类型，magic cookie，事务ID和消息长度，如下：

```cmake
   0                   1                   2                   3
   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |0 0|     STUN Message Type     |         Message Length        |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                         Magic Cookie                          |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                                                               |
  |                     Transaction ID (96 bits)                  |
  |                                                               |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

最高的2位必须置零，这可以在当STUN和其他协议复用的时候，用来区分STUN包和其他数据包。  
`STUN Message Type`字段定义了消息的类型（请求/成功响应/失败响应/指示）和消息的主方法。  
虽然我们有4个消息类别，但在STUN中只有两种类型的事务，即请求/响应类型和指示类型。  
响应类型分为成功和出错两种，用来帮助快速处理STUN信息。Message Type字段又可以进一步分解为如下结构：

```diff
 0                 1
 2  3  4 5 6 7 8 9 0 1 2 3 4 5
+--+--+-+-+-+-+-+-+-+-+-+-+-+-+
|M |M |M|M|M|C|M|M|M|C|M|M|M|M|
|11|10|9|8|7|1|6|5|4|0|3|2|1|0|
+--+--+-+-+-+-+-+-+-+-+-+-+-+-+
```

其中显示的位为从最高有效位M11到最低有效位M0，M11到M0表示方法的12位编码。C1和C0两位表示类的编码。比如对于binding方法来说，  
0b00表示request，0b01表示indication，0b10表示success response，0b11表示error response，每一个method都有可能对应不同的传输类别。  
拓展定义新方法的时候注意要指定该方法允许哪些类型的消息。

`Magic Cookie`字段包含固定值**0x2112A442**，这是为了前向兼容RFC3489，因为在classic STUN中，这一区域是事务ID的一部分。  
另外选择固定数值也是为了服务器判断客户端是否能识别特定的属性。还有一个作用就是在协议多路复用时候也可以将其作为判断标志之一。

`Transaction ID`字段是个96位的标识符，用来区分不同的STUN传输事务。对于request/response传输，事务ID由客户端选择，  
服务器收到后以同样的事务ID返回response；对于indication则由发送方自行选择。事务ID的主要功能是把request和response联系起来，  
同时也在防止攻击方面有一定作用。服务端也把事务ID当作一个Key来识别不同的STUN客户端，因此必须格式化且随机在0~2^(96-1)之间。  
重发同样的request请求时可以重用相同的事务ID，但是客户端进行新的传输时，**必须**选择一个新的事务ID。

`Message Length`字段存储了信息的长度，以字节为单位，不包括20字节的STUN头部。由于所有的STUN属性都是都是4字节对齐（填充）的，  
因此这个字段最后两位应该恒等于零，这也是辨别STUN包的一个方法之一。

### STUN属性

在STUN报文头部之后，通常跟着0个或者多个属性，每个属性必须是TLV编码的（Type-Length-Value）。其中Type字段和Length字段都是16位，  
Value字段为为32位表示，如下：

```vhdl
   0                   1                   2                   3
   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |         Type                  |            Length             |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |                         Value (variable)                ....
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

`Length`字段必须包含Value部分需要补齐的长度，以字节为单位。由于STUN属性以32bit边界对齐，因此属性内容不足4字节的都会以padding bit进行补齐。  
padding bit会被忽略，但可以是任何值。

`Type`字段为属性的类型。任何属性类型都有可能在一个STUN报文中出现超过一次。除非特殊指定，否则其出现的顺序是有意义的：  
即只有第一次出现的属性会被接收端解析，而其余的将被忽略。为了以后版本的拓展和改进，属性区域被分为两个部分。  
Type值在0x0000-0x7FFF之间的属性被指定为**强制理解**，意思是STUN终端必须要理解此属性，否则将返回错误信息；而0x8000-0xFFFF  
之间的属性为选择性理解，即如果STUN终端不识别此属性则将其忽略。目前STUN的属性类型由IANA维护。

这里简要介绍几个常见属性的Value结构：

- MAPPED-ADDRESS

MAPPED-ADDRESS同时也是classic STUN的一个属性，之所以还存在也是为了前向兼容。其包含了NAT客户端的反射地址，  
Family为IP类型，即IPV4(0x01)或IPV6(0x02)，Port为端口，Address为32位或128位的IP地址。注意高8位必须全部置零，  
而且接收端必须要将其忽略掉。

```diff
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|0 0 0 0 0 0 0 0|    Family     |           Port                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                 Address (32 bits or 128 bits)                 |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- XOR-MAPPED-ADDRESS

XOR-MAPPED-ADDRESS和MAPPED-ADDRESS基本相同，不同点是反射地址部分经过了一次异或（XOR）处理。对于X-Port字段，  
是将NAT的映射端口以小端形式与magic cookie的高16位进行异或，再将结果转换成大端形式而得到的，X-Address也是类似。  
之所以要经过这么一次转换，是因为在实践中发现很多NAT会修改payload中自身公网IP的32位数据，从而导致NAT打洞失败。

```smalltalk
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |x x x x x x x x|    Family     |         X-Port                |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                X-Address (Variable)
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- ERROR-CODE

ERROR-CODE属性用于error response报文中。其包含了300-699表示的错误代码，以及一个UTF-8格式的文字出错信息（Reason Phrase）。

```java
   0                   1                   2                   3
   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |           Reserved, should be 0         |Class|     Number    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |      Reason Phrase (variable)                                ..
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

另外，错误代码在语义上还与[SIP](http://www.rfc-editor.org/info/rfc3261)和HTTP协议保持一致。比如：

```scss
300：尝试代替(Try Alternate)，客户端应该使用该请求联系一个代替的服务器。这个错误响应仅在请求包括一个
```

USERNAME属性和一个有效的MESSAGE-INTEGRITY属性时发送；否则它不会被发送，而是发送错误代码为400的错误响应；  
400：错误请求(Bad Request)，请求变形了，客户端在修改先前的尝试前不应该重试该请求。  
401：未授权(Unauthorized)，请求未包括正确的资格来继续。客户端应该采用一个合适的资格来重试该请求。  
420：未知属性(Unknown Attribute)，服务器收到一个STUN包包含一个强制理解的属性但是它不会理解。  
服务器必须将不认识的属性放在错误响应的UNKNOWN-ATTRIBUTE属性中。  
438：过期Nonce(Stale Nonce)，客户端使用的Nonce不再有效，应该使用响应中提供的Nonce来重试。  
500：服务器错误(Server Error)，服务器遇到临时错误，客户端应该再次尝试。

此外还有很多属性，如USERNAME，NONCE，REALM，SOFTWARE等，具体可以翻阅[RFC3489](http://www.rfc-editor.org/info/rfc3489)。

## STUN 通信过程

### 1. 产生一个Request或Indication

当产生一个Request或者Indication报文时，终端必须根据上文提到的规则来生成头部，class字段必须是Request或者Indication，  
而method字段为Binding或者其他用户拓展的方法。属性部分选择该方法所需要的对应属性，比如在一些  
情景下我们会需要authenticaton属性或FINGERPRINT属性，注意在发送Request报文时候，需要加上SOFTWARE属性（内含软件版本描述）。

### 2. 发送Requst或Indication

目前，STUN报文可以通过UDP，TCP以及TLS-over-TCP的方法发送，其他方法在以后也会添加进来。STUN的使用者必须指定其使用的传输协议，  
以及终端确定接收端IP地址和端口的方式，比如通过基于DNS的方法来确定服务器的IP和端口。

2.1 通过UDP发送

当使用UDP协议运行STUN时，STUN的报文可能会由于网络问题而丢失。可靠的STUN请求/响应传输是通过客户端重发request请求来实现的，  
因此，在UDP运行时，Indication报文是不可靠的。STUN客户端通过RTO（Retransmission TimeOut）  
来决定是否重传Requst，并且在每次重传后将RTO翻倍。具体重传时间的选取可以参考相关文章，如RFC2988。  
重传直到接收到Response才停止，或者重传次数到达指定次数Rc，Rc应该是可配置的，且默认值为7。

2.2 通过TCP或者TCP-over-TLS发送

对于这种情景，客户端打开对服务器的连接。在某些情况下，此TCP链接只传输STUN报文，而在其他拓展中，  
在一个TCP链接里可能STUN报文和其他协议的报文会进行多路复用（Multiplexed）。数据传输的可靠性由TCP协议本身来保证。  
值得一提的是，在一次TCP连接中，STUN客户端可能发起多个传输，有可能在前一个Request的Response还没收到时就再次发送了一个新的Request，  
因此客户端应该保持TCP链接打开，认所有STUN事务都已完成。

### 3. 接收STUN消息

当STUN终端接收到一个STUN报文时，首先检查报文的规则是否合法，即前两位是否为0，magic cookie是否为0x2112A442，报文长度是否正确以及对应的方法是否支持。  
如果消息类别为Success/Error Response，终端会检测其事务ID是否与当前正在处理的事务ID相同。如果使用了FINGERPRINT拓展的话还会检查FINGERPRINT属性是否正确。  
完成身份认证检查之后，STUN终端会接着检查其余未知属性。

**3.1 处理Request**

如果请求包含一个或者多个强制理解的未知属性，接收端会返回error response，错误代码420（ERROR-CODE属性），  
而且包含一个UNKNOWN-ATTRIBUTES属性来告知发送方哪些强制理解的属性是未知的。服务端接着检查方法和其他指定要求，如果所有检查都成功，  
则会产生一个Success Response给客户端。

- 3.1.1 生成Success Response或Error Response
    
    - 如果服务器通过某种`验证方法（authentication mechanism）`通过了请求方的验证，那么在响应报文里最好也加上对应的验证属性。
    - 服务器端也应该加上指定方法所需要的属性信息，另外协议建议服务器返回时也加上SOFTWARE属性。
    - 对于Binding方法，除非特别指明，一般不要求进行额外的检查。当生成Success Response时，服务器在响应里加上XOR-MAPPED-ADDRESS属性。  
        对于UDP，这是其源IP和端口信息，对于TCP或TLS-over-TCP，这就是服务器端所看见的此次TCP连接的源IP和端口。
- 3.1.2 发送Success Response或Error Response
    
    - 发送响应时候如果是用UDP协议，则发往其源IP和端口，如果是TCP则直接用相同的TCP链接回发即可。

**3.2 处理Indication**

如果Indication报文包含未知的强制理解属性，则此报文会被接收端忽略并丢弃。如果对Indication报文的检查都没有错误，则服务端会进行相应的处理，  
但是不会返回Response。对于Binding方法，一般不需要额外的检查或处理。收到信息的服务端仅需要刷新对应NAT的端口绑定。

由于Indication报文在用UDP协议传输时不会进行重传，因此发送方也不需要处理重传的情况。

**3.3 处理Success Response**

如果Success Response包含了未知的强制理解属性，则响应会被忽略并且认为此次传输失败。客户端对报文进行检查通过之后，就可以开始处理此次报文。

以Binding方法为例，客户端会检查报文中是否包含XOR-MAPPED-ADDRESS属性，然后是地址类型，如果是不支持的地址类型，则这个属性会被忽略掉。

**3.4 处理Error Response**

如果Error Response包含了未知的强制理解属性，或者没有包含ERROR-CODE属性，则响应会被忽略并且认为此次传输失败。  
随后客户端会对验证方法进行处理，这有可能会产生新的传输。

- 到目前为止，对错误响应的处理主要基于ERROR-CODE属性的值，并遵循如下规则：
    
    - 如果error code在300到399之间，客户端被建议认为此次传输失败，除非用了ALTERNATE-SERVER拓展；
    - 如果error code在400到499之间，客户端认为此次传输失败；
    - 如果error code在500到599之间，客户端可能会需要重传请求，并且必须限制重传的次数。

任何其他的error code值都会导致客户端认为此次传输失败。

## 后记

上面只是介绍了[STUN/RFC5389](http://www.rfc-editor.org/info/rfc5389)协议的基础部分，协议本身还包含了许多mechanism，如身份验证（Authentication），DNS Discovery，FINGERPRINT Mechanisms，  
ALTERNATE-SERVER Mechanism等，身份验证又分为长期验证和短期验证，从而保证了传输的灵活性并减少服务器的负担。具体可以详细阅读白皮书。  
我本来打算一篇文章把P2P通信的所有协议都介绍完不过现在看来似乎篇幅过长了，所以关于TURN和ICE就放在下一篇介绍好了。  
另外由于SourceForge的StunServer的源代码已经长期不更新，因此我从svn的仓库中整理了一下放到了[GitHub](https://github.com/pannzh/TurnServer)上面，  
需要的可以自行去取来参考一下STUN交互的实现，当然了虽然实现的是TurnServer，但除了Relay部分基本上都是和STUN类似的。  
另外在[P2P原理与实现](https://evilpan.com/2015/10/31/p2p-over-middle-box/)所做的一个P2P聊天应用时, 顺便也做了个基于RFC3489的STUN客户端, 基于Python3,  
用于检测用户的NAT类型, 可以参见[p2p-over-middleboxes](https://github.com/pannzh/P2P-Over-MiddleBoxes-Demo/tree/master/stun).