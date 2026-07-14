# マンページ

[i[man pages]<]

Unix の世界にはマニュアルがたくさんある。使える個々の関数を説明する小さなセクションに分かれている。

もちろん `manual` なんて全部打つのは面倒だ。Unix 界隈の人間、自分を含めて、そんなに打つのは好きじゃない。簡潔さの好みについて延々と語ることもできるが、代わりに短くまとめて、あらゆる状況でどれだけ簡潔であることを好むかについての長々とした説教で退屈させることはしない。

_[拍手]_

ありがとう。言いたいのは、Unix ではこれらのページのことを "man pages"（マンページ）と呼ぶ、ということだ。読みやすいように、ここでは自分なりの省略版を載せてある。実際にはこれらの関数の多くは、ここで書いている以上に汎用的だが、インターネットソケットプログラミングに関係する部分だけを紹介する。

でも待て！ このマンページの問題はそれだけじゃない：

* 不完全で、ガイドの基本だけを示している。
* 現実にはもっとたくさんのマンページがある。
* 自分のシステム上のものとは違う。
* 関数によっては、システムごとにヘッダファイルが違うかもしれない。
* 関数によっては、システムごとにパラメータが違うかもしれない。

本物の情報が欲しければ、ローカルの Unix マンページを `man whatever` と打って確認してほしい。"whatever" は、例えば "`accept`" のように、ものすごく興味のあるものだ。（Microsoft Visual Studio にもヘルプで似たものがあるだろう。でも "man" の方が "help" より 1 バイト短い。Unix の勝ちだ！）

じゃあ、こんなに欠点があるのに、なぜガイドに載せるのか？ 理由はいくつかあるが、一番いいのは (a) これらの版はネットワークプログラミング向けに特化していて、本物より読みやすいこと、(b) サンプルコードが入っていること、だ。

あ！ サンプルの話をすると、エラーチェックを全部入れるとコードがかなり長くなるので、あまり入れない傾向がある。でも、失敗しないと 100% 確信できる場合を除いて、システムコールを呼ぶたびにだいたいエラーチェックをすべきだ。たぶんその場合でもやった方がいい！

[i[man pages]>]

[[manbreak]]
## `accept()` {#acceptman}

[i[`accept()` function]i]

待ち受けソケットで入ってくる接続を受け付ける

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int accept(int s, struct sockaddr *addr, socklen_t *addrlen);
```

### 説明 {.unnumbered .unlisted}

`SOCK_STREAM` ソケットを用意し、`listen()` で入ってくる接続の待ち受け設定を済ませたら、次は `accept()` を呼んで、新しく接続したクライアントとの通信に使う新しいソケット記述子を手に入れる。

待ち受けに使っていた古いソケットはそのまま残り、次の `accept()` 呼び出しにも使われる。

| パラメータ | 説明                                                   |
|-----------|---------------------------------------------------------------|
| `s`       | `listen()` しているソケット記述子。                          | 
| `addr`    | 接続してきた相手のアドレスがここに入る。|
| `addrlen` | `addr` パラメータに返される構造体の `sizeof()` がここに入る。`addr` に `struct sockaddr_in` が返ってくると決め打ちできるなら無視しても安全だ。実際その型を渡しているので、そうだと分かっているはず。|

`accept()` は通常ブロックする。待ち受けソケット記述子に対して事前に `select()` で覗いて、"読み取り可能" かどうか確認できる。そうなら、`accept()` 待ちの新しい接続がある！ やった！ 別の方法として、待ち受けソケットに [i[`fcntl()` function]] `fcntl()` で [i[`O_NONBLOCK` macro]] `O_NONBLOCK` フラグを設定すれば、ブロックせず、代わりに `-1` を返して `errno` が `EWOULDBLOCK` になる。

`accept()` が返すソケット記述子は、リモートホストに接続済みの本物のソケット記述子だ。使い終わったら `close()` する必要がある。

### 戻り値 {.unnumbered .unlisted}

`accept()` は新しく接続されたソケット記述子を返す。エラー時は `-1` で、`errno` が適切に設定される。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
struct sockaddr_storage their_addr;
socklen_t addr_size;
struct addrinfo hints, *res;
int sockfd, new_fd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_STREAM;
hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

getaddrinfo(NULL, MYPORT, &hints, &res);

// make a socket, bind it, and listen on it:

sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
bind(sockfd, res->ai_addr, res->ai_addrlen);
listen(sockfd, BACKLOG);

// now accept an incoming connection:

addr_size = sizeof their_addr;
new_fd = accept(sockfd, (struct sockaddr *)&their_addr, &addr_size);

// ready to communicate on socket descriptor new_fd!
```

### 関連項目 {.unnumbered .unlisted}

[`socket()`](#socketman), [`getaddrinfo()`](#getaddrinfoman),
[`listen()`](#listenman), [`struct sockaddr_in`](#structsockaddrman)


[[manbreak]]
## `bind()` {#bindman}

[i[`bind()` function]i]

ソケットを IP アドレスとポート番号に関連付ける

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int bind(int sockfd, struct sockaddr *my_addr, socklen_t addrlen);
```

### 説明 {.unnumbered .unlisted}

リモートマシンがサーバープログラムに接続したいとき、必要な情報は 2 つ：IP アドレスとポート番号。`bind()` 呼び出しでまさにそれができる。

まず `getaddrinfo()` を呼んで、接続先アドレスとポート情報を `struct sockaddr` に詰める。次に `socket()` でソケット記述子を取得し、ソケットとアドレスを `bind()` に渡すと、IP アドレスとポートが魔法（本物の魔法）でソケットに結び付けられる！

IP アドレスが分からない、マシンに IP が 1 つしかない、どの IP を使うか気にしない、という場合は、`getaddrinfo()` の `hints` パラメータに `AI_PASSIVE` フラグを渡せばいい。こうすると `struct sockaddr` の IP アドレス部分に特別な値が入り、`bind()` にこのホストの IP アドレスを自動入力させるよう指示できる。

え、何？ `struct sockaddr` の IP アドレスにどんな特別な値が入って、現在のホストのアドレスを自動入力させるの？ 教えるが、`struct sockaddr` を手で埋めている場合だけだ。そうでなければ上記のとおり `getaddrinfo()` の結果を使え。IPv4 では `struct sockaddr_in` の `sin_addr.s_addr` フィールドに `INADDR_ANY` を設定する。IPv6 では `struct sockaddr_in6` の `sin6_addr` フィールドにグローバル変数 `in6addr_any` を代入する。あるいは新しい `struct in6_addr` を宣言するなら `IN6ADDR_ANY_INIT` で初期化できる。

最後に、`addrlen` パラメータは `sizeof my_addr` に設定する。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// modern way of doing things with getaddrinfo()

struct addrinfo hints, *res;
int sockfd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_STREAM;
hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

getaddrinfo(NULL, "3490", &hints, &res);

// make a socket:
// (you should actually walk the "res" linked list and error-check!)

sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

// bind it to the port we passed in to getaddrinfo():

bind(sockfd, res->ai_addr, res->ai_addrlen);
```

```{.c .numberLines}
// example of packing a struct by hand, IPv4

struct sockaddr_in myaddr;
int s;

myaddr.sin_family = AF_INET;
myaddr.sin_port = htons(3490);

// you can specify an IP address:
inet_pton(AF_INET, "63.161.169.137", &(myaddr.sin_addr));

// or you can let it automatically select one:
myaddr.sin_addr.s_addr = INADDR_ANY;

s = socket(PF_INET, SOCK_STREAM, 0);
bind(s, (struct sockaddr*)&myaddr, sizeof myaddr);
```

### 関連項目 {.unnumbered .unlisted}

[`getaddrinfo()`](#getaddrinfoman), [`socket()`](#socketman), [`struct
sockaddr_in`](#structsockaddrman), [`struct in_addr`](#structsockaddrman)


[[manbreak]]
## `connect()` {#connectman}

[i[`connect()` function]i]

ソケットをサーバーに接続する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int connect(int sockfd, const struct sockaddr *serv_addr,
            socklen_t addrlen);
```

### 説明 {.unnumbered .unlisted}

`socket()` 呼び出しでソケット記述子を作ったら、名前のとおり `connect()` システムコールでそのソケットをリモートサーバーに `connect()` できる。ソケット記述子と、接続したいサーバーのアドレスを渡すだけ（あと、この種の関数によく渡されるアドレスの長さも）。

通常この情報は `getaddrinfo()` の結果として得られるが、自分で `struct sockaddr` を埋めてもいい。

ソケット記述子にまだ `bind()` を呼んでいなければ、自動的に自分の IP アドレスとランダムなローカルポートに結び付けられる。サーバーでなければ、ローカルポートが何番かはたいてい気にしないので問題ない。気になるのはリモートポートで、それを `serv_addr` パラメータに入れる。特定の IP とポートにクライアントソケットを置きたければ `bind()` もできるが、かなりレア。

ソケットが `connect()` されたら、好きなだけ `send()` や `recv()` でデータをやり取りできる。

[i[`connect()`-->on datagram sockets]] 特記：`SOCK_DGRAM` UDP ソケットをリモートホストに `connect()` すると、`sendto()` や `recvfrom()` に加えて `send()` や `recv()` も使える。好きなら。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// connect to www.example.com port 80 (http)

struct addrinfo hints, *res;
int sockfd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_STREAM;

// we could put "80" instead on "http" on the next line:
getaddrinfo("www.example.com", "http", &hints, &res);

// make a socket:

sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

// connect it to the address and port we passed in to getaddrinfo():

connect(sockfd, res->ai_addr, res->ai_addrlen);
```

### 関連項目 {.unnumbered .unlisted}

[`socket()`](#socketman), [`bind()`](#bindman)


[[manbreak]]
## `close()` {#closeman}

[i[`close()` function]i]

ソケット記述子を閉じる

### 概要 {.unnumbered .unlisted}

```{.c}
#include <unistd.h>

int close(int s);
```

### 説明 {.unnumbered .unlisted}

考えついた狂った用途でソケットを使い終わり、もう `send()` や `recv()`、いやソケットで _何も_ したくないなら、`close()` すれば解放され、二度と使えなくなる。

リモート側は 2 通りでこれに気づける。1：`recv()` を呼ぶと `0` が返る。2：`send()` を呼ぶと [i[`SIGPIPE` macro]] `SIGPIPE` シグナルを受け取り、`send()` は `-1` を返して `errno` が [i[`EPIPE` macro]] `EPIPE` になる。

[i[Windows]] **Windows ユーザー**：使う関数は `close()` ではなく [i[`closesocket()` function]i] `closesocket()` だ。ソケット記述子に `close()` を使うと Windows が怒るかもしれない……怒った Windows は見たくないだろう。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
s = socket(PF_INET, SOCK_DGRAM, 0);
.
.
.
// a whole lotta stuff...*BRRRONNNN!*
.
.
.
close(s);  // not much to it, really.
```

### 関連項目 {.unnumbered .unlisted}

[`socket()`](#socketman), [`shutdown()`](#shutdownman)


[[manbreak]]
## `getaddrinfo()`, `freeaddrinfo()`, `gai_strerror()` {#getaddrinfoman}

[i[`getaddrinfo()` function]i]
[i[`freeaddrinfo()` function]i]
[i[`gai_strerror()` function]i]

ホスト名やサービスに関する情報を取得し、結果を `struct sockaddr` に詰める。

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

int getaddrinfo(const char *nodename, const char *servname,
                const struct addrinfo *hints,
                struct addrinfo **res);

void freeaddrinfo(struct addrinfo *ai);

const char *gai_strerror(int ecode);

struct addrinfo {
  int     ai_flags;          // AI_PASSIVE, AI_CANONNAME, ...
  int     ai_family;         // AF_xxx
  int     ai_socktype;       // SOCK_xxx
  int     ai_protocol;       // 0 (auto) or IPPROTO_TCP, IPPROTO_UDP 

  socklen_t  ai_addrlen;     // length of ai_addr
  char   *ai_canonname;      // canonical name for nodename
  struct sockaddr  *ai_addr; // binary address
  struct addrinfo  *ai_next; // next structure in linked list
};
```

### 説明 {.unnumbered .unlisted}

`getaddrinfo()` は優秀な関数で、特定のホスト名（IP アドレスなど）の情報を返し、細かい部分（IPv4 か IPv6 かなど）を面倒見て `struct sockaddr` を用意してくれる。古い `gethostbyname()` と `getservbyname()` の代わりだ。以下の説明は情報量が多くて少し圧倒されるかもしれないが、実際の使い方はかなりシンプル。まずサンプルを見る価値はある。

関心のあるホスト名は `nodename` パラメータに入れる。アドレスは "www.example.com" のようなホスト名でも、文字列として渡された IPv4/IPv6 アドレスでもよい。下記の `AI_PASSIVE` フラグを使うなら、このパラメータは `NULL` でもよい。

`servname` パラメータは基本的にポート番号。"80" のように文字列のポート番号でも、"http" や "tftp" や "smtp" や "pop" などのサービス名でもよい。よく知られたサービス名は [fl[IANA Port List|https://www.iana.org/assignments/port-numbers]] や `/etc/services` にある。

最後に入力パラメータとして `hints` がある。ここで `getaddrinfo()` に何をさせるか定義する。使う前に `memset()` で構造体全体をゼロにしよう。使う前に設定するフィールドを見ていく。

`ai_flags` にはいろいろ設定できるが、重要なものをいくつか。（複数フラグは `|` でビット OR できる。完全なリストはマンページを確認。）

`AI_CANONNAME` は結果の `ai_canonname` にホストの正規（本当の）名前を入れる。`AI_PASSIVE` は結果の IP アドレスを `INADDR_ANY`（IPv4）または `in6addr_any`（IPv6）で埋める。続く `bind()` で `struct sockaddr` の IP アドレスを現在のホストのアドレスで自動入力させる。アドレスをハードコードしたくないサーバー設定に最適。

`AI_PASSIVE` フラグを使うなら、`nodename` に `NULL` を渡せる（後で `bind()` が埋めてくれるから）。

入力パラメータの続きとして、`ai_family` は `AF_UNSPEC` にすると IPv4 と IPv6 の両方を探す。`AF_INET` か `AF_INET6` で片方に限定もできる。

次に `socktype` フィールドは、欲しいソケットの種類に応じて `SOCK_STREAM` か `SOCK_DGRAM` を設定する。

最後に `ai_protocol` は `0` のままで、プロトコル種別を自動選択させればよい。

ここまで詰めたら、_ついに_ `getaddrinfo()` を呼べる！

もちろんここからが本番。`res` は `struct addrinfo` のリンクリストを指し、`hints` で渡した条件に合うアドレスを全部たどれる。

理由のいずれかで使えないアドレスが混ざることもある。Linux のマンページでは、リストをループして `socket()` と `connect()`（`AI_PASSIVE` でサーバーを立てるなら `bind()`）を成功するまで呼ぶ、というやり方をしている。

最後にリンクリストを使い終わったら `freeaddrinfo()` でメモリを解放する（しないとリークして、Some People が怒る）。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は非ゼロ。非ゼロなら `gai_strerror()` で返り値のエラーコードを表示可能な文字列にできる。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// code for a client connecting to a server
// namely a stream socket to www.example.com on port 80 (http)
// either IPv4 or IPv6

int sockfd;  
struct addrinfo hints, *servinfo, *p;
int rv;

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC; // use AF_INET6 to force IPv6
hints.ai_socktype = SOCK_STREAM;

rv = getaddrinfo("www.example.com", "http", &hints, &servinfo);
if (rv != 0) {
    fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
    exit(1);
}

// loop through all the results and connect to the first we can
for(p = servinfo; p != NULL; p = p->ai_next) {
    if ((sockfd = socket(p->ai_family, p->ai_socktype,
            p->ai_protocol)) == -1) {
        perror("socket");
        continue;
    }

    if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
        perror("connect");
        close(sockfd);
        continue;
    }

    break; // if we get here, we must have connected successfully
}

if (p == NULL) {
    // looped off the end of the list with no connection
    fprintf(stderr, "failed to connect\n");
    exit(2);
}

freeaddrinfo(servinfo); // all done with this structure
```

```{.c .numberLines}
// code for a server waiting for connections
// namely a stream socket on port 3490, on this host's IP
// either IPv4 or IPv6.

int sockfd;  
struct addrinfo hints, *servinfo, *p;
int rv;

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC; // use AF_INET6 to force IPv6
hints.ai_socktype = SOCK_STREAM;
hints.ai_flags = AI_PASSIVE; // use my IP address

if ((rv = getaddrinfo(NULL, "3490", &hints, &servinfo)) != 0) {
    fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
    exit(1);
}

// loop through all the results and bind to the first we can
for(p = servinfo; p != NULL; p = p->ai_next) {
    if ((sockfd = socket(p->ai_family, p->ai_socktype,
            p->ai_protocol)) == -1) {
        perror("socket");
        continue;
    }

    if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
        close(sockfd);
        perror("bind");
        continue;
    }

    break; // if we get here, we must have connected successfully
}

if (p == NULL) {
    // looped off the end of the list with no successful bind
    fprintf(stderr, "failed to bind socket\n");
    exit(2);
}

freeaddrinfo(servinfo); // all done with this structure
```

### 関連項目 {.unnumbered .unlisted}

[`gethostbyname()`](#gethostbynameman), [`getnameinfo()`](#getnameinfoman)


[[manbreak]]
## `gethostname()` {#gethostnameman}

[i[`gethostname()` function]i]

システムの名前を返す

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/unistd.h>

int gethostname(char *name, size_t len);
```

### 説明 {.unnumbered .unlisted}

システムには名前がある。みんなそうだ。ここまで話してきたネットワーク系より Unix っぽい話だが、用途はある。

例えばホスト名を取得してから [i[`gethostbyname()` function]] `gethostbyname()` を呼べば、自分の IP アドレスが分かる。

パラメータ `name` はホスト名を入れるバッファを指し、`len` はそのバッファのバイト数。`gethostname()` はバッファ末尾を上書きしない（エラーを返すか、書き込みを止める）。バッファに余裕があれば文字列は `NUL` 終端される。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
char hostname[128];

gethostname(hostname, sizeof hostname);
printf("My hostname: %s\n", hostname);
```

### 関連項目 {.unnumbered .unlisted}

[`gethostbyname()`](#gethostbynameman)


[[manbreak]]
## `gethostbyname()`, `gethostbyaddr()` {#gethostbynameman}

[i[`gethostbyname()` function]i]
[i[`gethostbyaddr()` function]i]

ホスト名から IP アドレスを、またはその逆を取得する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>
#include <netdb.h>

struct hostent *gethostbyname(const char *name); // DEPRECATED!
struct hostent *gethostbyaddr(const char *addr, int len, int type);
```

### 説明 {.unnumbered .unlisted}

_注意：これら 2 関数は `getaddrinfo()` と `getnameinfo()` に置き換えられた！_ 特に `gethostbyname()` は IPv6 向きではない。

これらの関数はホスト名と IP アドレスを相互に変換する。例えば "www.example.com" があれば、`gethostbyname()` で IP アドレスを取得して `struct in_addr` に保存できる。

逆に `struct in_addr` や `struct in6_addr` があれば、`gethostbyaddr()` でホスト名を取り戻せる。`gethostbyaddr()` は IPv6 対応だが、新しい `getnameinfo()` を使うべき。

（ドット区切り数字形式の IP 文字列からホスト名を調べたいなら、`AI_CANONNAME` フラグ付きの `getaddrinfo()` の方がよい。）

`gethostbyname()` は "www.yahoo.com" のような文字列を受け取り、IP アドレスを含む大量の情報が入った `struct hostent` を返す。（他に正規ホスト名、エイリアス一覧、アドレス型、アドレス長、アドレス一覧など——一度構造が分かれば目的にはかなり使いやすい汎用構造体だ。）

`gethostbyaddr()` は `struct in_addr` か `struct in6_addr` を受け取り、対応するホスト名（あれば）を返す。`gethostbyname()` の逆だ。パラメータとして `addr` は `char*` だが、実際には `struct in_addr` へのポインタを渡す。`len` は `sizeof(struct in_addr)`、`type` は `AF_INET` にする。

返ってくる [i[`struct hostent` type]i] `struct hostent` とは？ ホストに関する情報が入ったフィールドの集まりだ。

| フィールド                | 説明                                       |
|----------------------|---------------------------------------------------|
| `char *h_name`       | 正規のホスト名。                     |
| `char **h_aliases`   | エイリアス一覧。配列でアクセス——最後の要素は `NULL` |
| `int h_addrtype`     | 結果のアドレス型。ここではたいてい `AF_INET`。 |
| `int length`         | アドレスのバイト長。IP（バージョン 4）なら 4。 |
| `char **h_addr_list` | このホストの IP アドレス一覧。`char**` だが、実体は `struct in_addr*` の配列の変装。最後は `NULL`。 |
| `h_addr`             | `h_addr_list[0]` のよくある別名。このホストの IP が複数あっても、とにかく 1 つ欲しければこのフィールドでよい。 |

### 戻り値 {.unnumbered .unlisted}

成功時は `struct hostent` へのポインタ、エラー時は `NULL`。

通常の `perror()` などではなく、これらの関数は `h_errno` 変数に並行する結果を持つ。[i[`herror()` function]i] `herror()` や [i[`hstrerror()` function]i] `hstrerror()` で表示できる。おなじみの `errno`、`perror()`、`strerror()` と同じ要領だ。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// THIS IS A DEPRECATED METHOD OF GETTING HOST NAMES
// use getaddrinfo() instead!

#include <stdio.h>
#include <errno.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char *argv[])
{
    int i;
    struct hostent *he;
    struct in_addr **addr_list;

    if (argc != 2) {
        fprintf(stderr,"usage: ghbn hostname\n");
        return 1;
    }

    if ((he = gethostbyname(argv[1])) == NULL) {  // get host info
        herror("gethostbyname");
        return 2;
    }

    // print information about this host:
    printf("Official name is: %s\n", he->h_name);
    printf("    IP addresses: ");
    addr_list = (struct in_addr **)he->h_addr_list;
    for(i = 0; addr_list[i] != NULL; i++) {
        printf("%s ", inet_ntoa(*addr_list[i]));
    }
    printf("\n");

    return 0;
}
```

```{.c .numberLines}
// THIS HAS BEEN SUPERSEDED
// use getnameinfo() instead!

struct hostent *he;
struct in_addr ipv4addr;
struct in6_addr ipv6addr;

inet_pton(AF_INET, "192.0.2.34", &ipv4addr);
he = gethostbyaddr(&ipv4addr, sizeof ipv4addr, AF_INET);
printf("Host name: %s\n", he->h_name);

inet_pton(AF_INET6, "2001:db8:63b3:1::beef", &ipv6addr);
he = gethostbyaddr(&ipv6addr, sizeof ipv6addr, AF_INET6);
printf("Host name: %s\n", he->h_name);
```

### 関連項目 {.unnumbered .unlisted}

[`getaddrinfo()`](#getaddrinfoman), [`getnameinfo()`](#getnameinfoman),
[`gethostname()`](#gethostnameman), [`errno`](#errnoman),
[`perror()`](#perrorman), [`strerror()`](#perrorman), [`struct
in_addr`](#structsockaddrman)


[[manbreak]]
## `getnameinfo()` {#getnameinfoman}

[i[`getnameinfo()` function]i]

与えられた `struct sockaddr` についてホスト名とサービス名を調べる。

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>
#include <netdb.h>

int getnameinfo(const struct sockaddr *sa, socklen_t salen,
                char *host, size_t hostlen,
                char *serv, size_t servlen, int flags);
```

### 説明 {.unnumbered .unlisted}

`getaddrinfo()` の逆で、すでに埋まった `struct sockaddr` から名前とサービス名のルックアップを行う。古い `gethostbyaddr()` と `getservbyport()` の代わり。

`sa` には（実際はたいていキャストした `struct sockaddr_in` か `struct sockaddr_in6` だろう）`struct sockaddr` へのポインタを、`salen` にはその `struct` の長さを渡す。

結果のホスト名とサービス名は `host` と `serv` が指す領域に書き込まれる。`hostlen` と `servlen` で各バッファの最大長を指定する必要がある。

最後に渡せるフラグがいくつかあるが、よく使うものを 2 つ。`NI_NOFQDN` は `host` にドメイン全体ではなくホスト名だけを入れる。`NI_NAMEREQD` は DNS で名前が見つからないと関数を失敗させる（このフラグを付けずに名前が見つからない場合、`getnameinfo()` は代わりに `host` に IP アドレスの文字列版を入れる）。

いつものように、詳細はローカルのマンページを確認。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は非ゼロ。非ゼロなら `gai_strerror()` に渡して人間が読める文字列にできる。詳細は `getaddrinfo` を参照。

[[book-pagebreak]]

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
struct sockaddr_in6 sa; // could be IPv4 if you want
char host[1024];
char service[20];

// pretend sa is full of good information about the host and port...

getnameinfo(&sa, sizeof sa, host, sizeof host, service,
            sizeof service, 0);

printf("   host: %s\n", host);    // e.g. "www.example.com"
printf("service: %s\n", service); // e.g. "http"
```

### 関連項目 {.unnumbered .unlisted}

[`getaddrinfo()`](#getaddrinfoman), [`gethostbyaddr()`](#gethostbynameman)


[[manbreak]]
## `getpeername()` {#getpeernameman}

[i[`getpeername()` function]i]

接続のリモート側についてアドレス情報を返す

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>

int getpeername(int s, struct sockaddr *addr, socklen_t *len);
```

### 説明 {.unnumbered .unlisted}

リモート接続を `accept()` したか、サーバーに `connect()` したら、いわゆる _ピア_ ができる。ピアとは接続先のコンピュータで、IP アドレスとポートで識別される。だから……

`getpeername()` は、接続している相手の情報が入った `struct sockaddr_in` を返すだけだ。

なぜ "name" なのか？ ソケットにはこのガイドで使っているインターネットソケット以外にもいろいろあり、"name" はすべてのケースをカバーする汎用語として都合がよかった。ここではピアの "name" は IP アドレスとポートだ。

関数は `len` に結果のアドレスサイズを返すが、`len` には事前に `addr` のサイズを入れておく必要がある。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// assume s is a connected socket

socklen_t len;
struct sockaddr_storage addr;
char ipstr[INET6_ADDRSTRLEN];
int port;

len = sizeof addr;
getpeername(s, (struct sockaddr*)&addr, &len);

// deal with both IPv4 and IPv6:
if (addr.ss_family == AF_INET) {
    struct sockaddr_in *s = (struct sockaddr_in *)&addr;
    port = ntohs(s->sin_port);
    inet_ntop(AF_INET, &s->sin_addr, ipstr, sizeof ipstr);
} else { // AF_INET6
    struct sockaddr_in6 *s = (struct sockaddr_in6 *)&addr;
    port = ntohs(s->sin6_port);
    inet_ntop(AF_INET6, &s->sin6_addr, ipstr, sizeof ipstr);
}

printf("Peer IP address: %s\n", ipstr);
printf("Peer port      : %d\n", port);
```

### 関連項目 {.unnumbered .unlisted}

[`gethostname()`](#gethostnameman), [`gethostbyname()`](#gethostbynameman),
[`gethostbyaddr()`](#gethostbynameman)


[[manbreak]]
## `errno` {#errnoman}

[i[`errno` variable]i]

直前のシステムコールのエラーコードを保持する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <errno.h>

int errno;
```

### 説明 {.unnumbered .unlisted}

多くのシステムコールのエラー情報を保持する変数だ。覚えているだろう、`socket()` や `listen()` はエラー時に `-1` を返し、どのエラーかを示すよう `errno` に正確な値を設定する。

ヘッダ `errno.h` には `EADDRINUSE`、`EPIPE`、`ECONNREFUSED` などの定数シンボル名が並ぶ。ローカルのマンページで返りうるコードを確認し、実行時にエラーごとに処理を分けられる。

もっと一般的には [i[`perror()` function]] `perror()` や [i[`strerror()` function]] `strerror()` を呼んで、人間が読めるエラー文字列を得る。

マルチスレッド好きの人向け：`errno` は多くのシステムでスレッドセーフに定義されている（グローバル変数そのものではないが、シングルスレッド環境ではグローバル変数と同じように振る舞う）。

### 戻り値 {.unnumbered .unlisted}

変数の値は直近のエラーで、直前の操作が成功していれば "success" のコードかもしれない。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
s = socket(PF_INET, SOCK_STREAM, 0);
if (s == -1) {
    perror("socket"); // or use strerror()
}

tryagain:
if (select(n, &readfds, NULL, NULL) == -1) {
    // an error has occurred!!

    // if we were only interrupted, just restart the select() call:
    if (errno == EINTR) goto tryagain;  // AAAA! goto!!!

    // otherwise it's a more serious error:
    perror("select");
    exit(1);
}
```

### 関連項目 {.unnumbered .unlisted}

[`perror()`](#perrorman), [`strerror()`](#perrorman)


[[manbreak]]
## `fcntl()` {#fcntlman}

[i[`fcntl()` function]i]

ソケット記述子を制御する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/unistd.h>
#include <sys/fcntl.h>

int fcntl(int s, int cmd, long arg);
```

### 説明 {.unnumbered .unlisted}

この関数はファイルロックなどファイル向けの用途が典型だが、ソケット関連の機能もいくつかあり、たまに目にする。

パラメータ `s` は操作対象のソケット記述子、`cmd` は [i[`F_SETFL` macro]i] `F_SETFL` に設定し、`arg` は次のコマンドのいずれか。（`fcntl()` にはここで触れない部分ももっとあるが、ソケット向けに留める。）

| `cmd`        | 説明                                                |
|--------------|------------------------------------------------------------|
| [i[`O_NONBLOCK` macro]i]`O_NONBLOCK` | ソケットを非ブロッキングにする。詳細は [blocking](#blocking) の節を参照。|
| [i[`O_ASYNC` macro]i]`O_ASYNC`    | ソケットを非同期 I/O にする。ソケットで `recv()` 可能なデータが来ると [i[`SIGIO` signal]] `SIGIO` が上がる。あまり見ない用途で、ガイドの範囲外。特定システムでのみ利用可能かもしれない。|

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

`fcntl()` の用途によって返り値は異なるが、ここではソケット関連以外は触れていない。詳細はローカルの `fcntl()` マンページを参照。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int s = socket(PF_INET, SOCK_STREAM, 0);

fcntl(s, F_SETFL, O_NONBLOCK);  // set to non-blocking
fcntl(s, F_SETFL, O_ASYNC);     // set to asynchronous I/O
```

### 関連項目 {.unnumbered .unlisted}

[Blocking](#blocking), [`send()`](#sendman)


[[manbreak]]
## `htons()`, `htonl()`, `ntohs()`, `ntohl()` {#htonsman}

[i[`htons()` function]i]
[i[`htonl()` function]i]
[i[`ntohs()` function]i]
[i[`ntohl()` function]i]

マルチバイト整数型をホストバイト順からネットワークバイト順へ変換する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <netinet/in.h>

uint32_t htonl(uint32_t hostlong);
uint16_t htons(uint16_t hostshort);
uint32_t ntohl(uint32_t netlong);
uint16_t ntohs(uint16_t netshort);
```

### 説明 {.unnumbered .unlisted}

不快な話だが、マルチバイト整数（`char` より大きい整数）の内部バイト順はマシンごとに違う。Intel マシンから Mac（Intel 化前の話）へ 2 バイトの `short int` を `send()` すると、一方では `1`、もう一方では `256` と解釈される、ということが起きうる。

[i[Byte ordering]] 回避策は、Motorola と IBM が正しく Intel が変だった、とみんなで合意し、送る前にすべて "big-endian"（ビッグエンディアン）に揃えること。Intel は "little-endian" なので、政治的には "Network Byte Order"（ネットワークバイト順）と呼ぶ方が正しい。これらの関数はネイティブバイト順とネットワークバイト順を相互変換する。

（Intel ではバイトを入れ替え、PowerPC ではすでに Network Byte Order なので何もしない。でも Intel 上でもちゃんと動くよう、コードでは常に使うべき。）

型は 32 ビット（4 バイト、たぶん `int`）と 16 ビット（2 バイト、たぶん `short`）の数値。

64 ビット版はシステムによってある。`<endian.h>` があれば [flm[`htobe64()`|htobe64]] 関数族を確認（MacOS にはないらしい）。GCC には 128 ビットまで行く [fl[byte swapping built-ins|https://gcc.gnu.org/onlinedocs/gcc/Byte-Swapping-Builtins.html]] もある。[flx[自分で書くこともできる|htonll.c]] が、リトルエンディアンマシンのときだけ実際にスワップすればよい！

関数の名前の付け方：ホスト（自分のマシン）のバイト順 _から_ 変換するなら最初の文字は "h"。ネットワークバイト順 _から_ なら "n"。真ん中は常に "to"。最後から 2 番目の文字は変換 _先_ を示す。末尾はデータサイズで "s" は short、"l" は long。つまり：

| 関数  | 説明                   |
|-----------|-------------------------------|
| `htons()` | `h`ost `to` `n`etwork `s`hort |
| `htonl()` | `h`ost `to` `n`etwork `l`ong  |
| `ntohs()` | `n`etwork `to` `h`ost `s`hort |
| `ntohl()` | `n`etwork `to` `h`ost `l`ong  |

### 戻り値 {.unnumbered .unlisted}

各関数は変換後の値を返す。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
uint32_t some_long = 10;
uint16_t some_short = 20;

uint32_t network_byte_order;

// convert and send
network_byte_order = htonl(some_long);
send(s, &network_byte_order, sizeof(uint32_t), 0);

some_short == ntohs(htons(some_short)); // this expression is true
```


[[manbreak]]
## `inet_ntoa()`, `inet_aton()`, `inet_addr` {#inet_ntoaman}

[i[`inet_ntoa()` function]i]
[i[`inet_aton()` function]i]
[i[`inet_addr()` function]i]

ドット区切り数字の IP 文字列と `struct in_addr` を相互変換する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// ALL THESE ARE DEPRECATED!
// Use inet_pton() or inet_ntop() instead!

char *inet_ntoa(struct in_addr in);
int inet_aton(const char *cp, struct in_addr *inp);
in_addr_t inet_addr(const char *cp);
```

### 説明 {.unnumbered .unlisted}

_これらの関数は IPv6 を扱えないので非推奨！ [`inet_ntop()`](#inet_ntopman) か [`inet_pton()`](#inet_ntopman) を使え！ 野良コードにはまだ残っているのでここに載せている。_

これらは `struct in_addr`（たいてい `struct sockaddr_in` の一部）とドット区切り形式（例 "192.168.5.10"）の文字列を相互変換する。コマンドラインなどで IP 文字列が渡されたとき、`connect()` 先などに使う `struct in_addr` を得るいちばん簡単な方法。もっと力が要るなら `gethostbyname()` などの DNS 関数か、母国で _coup d'État_ を試みる。

`inet_ntoa()` は `struct in_addr` 内のネットワークアドレスをドット区切り文字列に変換する。"ntoa" の "n" は network、"a" は歴史的に ASCII（つまり "Network To ASCII"）。"toa" 接尾辞には C ライブラリの `atoi()`（ASCII 文字列を整数に）という仲間がいる。

`inet_aton()` はその逆で、ドット区切り文字列を `in_addr_t`（`struct in_addr` の `s_addr` フィールドの型）に変換する。

`inet_addr()` は `inet_aton()` とほぼ同じことをする古い関数。理論上は非推奨だが、よく見かける。使っても警察は来ない。

### 戻り値 {.unnumbered .unlisted}

`inet_aton()` はアドレスが有効なら非ゼロ、無効なら 0。

`inet_ntoa()` はドット区切り文字列を静的バッファに返す。呼ぶたびに上書きされる。

`inet_addr()` は `in_addr_t` としてアドレスを返す。エラー時は `-1`。（有効な IP である [i[`255.255.255.255`]] "`255.255.255.255`" を変換しようとした場合と同じ結果になる。だから `inet_aton()` の方がよい。）

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
struct sockaddr_in antelope;
char *some_addr;

inet_aton("10.0.0.1", &antelope.sin_addr); // store IP in antelope

some_addr = inet_ntoa(antelope.sin_addr); // return the IP
printf("%s\n", some_addr); // prints "10.0.0.1"

// and this call is the same as the inet_aton() call, above:
antelope.sin_addr.s_addr = inet_addr("10.0.0.1");
```

### 関連項目 {.unnumbered .unlisted}

[`inet_ntop()`](#inet_ntopman), [`inet_pton()`](#inet_ntopman),
[`gethostbyname()`](#gethostbynameman), [`gethostbyaddr()`](#gethostbynameman)


[[manbreak]]
## `inet_ntop()`, `inet_pton()` {#inet_ntopman}

[i[`inet_ntop()` function]i]
[i[`inet_pton()` function]i]

IP アドレスを人間が読める形式とバイナリ形式で相互変換する。

### 概要 {.unnumbered .unlisted}

```{.c}
#include <arpa/inet.h>

const char *inet_ntop(int af, const void *src,
                      char *dst, socklen_t size);

int inet_pton(int af, const char *src, void *dst);
```

### 説明 {.unnumbered .unlisted}

人間が読める IP アドレスを、各種関数やシステムコールで使うバイナリ表現に変換する（およびその逆）ための関数。"n" は "network"、"p" は "presentation"（または "text presentation"）。"printable" と考えてもよい。"ntop" は "network to printable"。分かった？

IP アドレスをバイナリの山で見たくないとき、`192.0.2.180` や `2001:db8:8714:3a90::12` のようなきれいな形式が欲しい——その場合は `inet_ntop()`。

`inet_ntop()` は `af` にアドレスファミリー（`AF_INET` か `AF_INET6`）を渡す。`src` は変換したいアドレスを持つ `struct in_addr` か `struct in6_addr` へのポインタ。`dst` と `size` は出力文字列のポインタと最大長。

`dst` の最大長は？ IPv4 と IPv6 で最大長は？ 助けになるマクロがある。最大長は `INET_ADDRSTRLEN` と `INET6_ADDRSTRLEN`。

逆に、読み取り可能な IP 文字列を `struct sockaddr_in` や `struct sockaddr_in6` に詰めたいなら、反対の `inet_pton()` を使う。

`inet_pton()` も `af` に `AF_INET` か `AF_INET6`。`src` は読み取り可能形式の IP 文字列へのポインタ。`dst` は結果の保存先で、たいてい `struct in_addr` か `struct in6_addr`。

これらの関数は DNS ルックアップはしない——それには `getaddrinfo()` が必要。

### 戻り値 {.unnumbered .unlisted}

`inet_ntop()` は成功時 `dst`、失敗時 `NULL`（`errno` が設定される）。

`inet_pton()` は成功時 `1`。エラー時 `-1`（`errno` 設定）、入力が有効な IP でない場合 `0`。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// IPv4 demo of inet_ntop() and inet_pton()

struct sockaddr_in sa;
char str[INET_ADDRSTRLEN];

// store this IP address in sa:
inet_pton(AF_INET, "192.0.2.33", &(sa.sin_addr));

// now get it back and print it
inet_ntop(AF_INET, &(sa.sin_addr), str, INET_ADDRSTRLEN);

printf("%s\n", str); // prints "192.0.2.33"
```

```{.c .numberLines}
// IPv6 demo of inet_ntop() and inet_pton()
// (basically the same except with a bunch of 6s thrown around)

struct sockaddr_in6 sa;
char str[INET6_ADDRSTRLEN];

// store this IP address in sa:
inet_pton(AF_INET6, "2001:db8:8714:3a90::12", &(sa.sin6_addr));

// now get it back and print it
inet_ntop(AF_INET6, &(sa.sin6_addr), str, INET6_ADDRSTRLEN);

printf("%s\n", str); // prints "2001:db8:8714:3a90::12"
```

```{.c .numberLines}
// Helper function you can use:

//Convert a struct sockaddr address to a string, IPv4 and IPv6:

char *get_ip_str(const struct sockaddr *sa, char *s, size_t maxlen)
{
    switch(sa->sa_family) {
        case AF_INET:
            inet_ntop(AF_INET,
                    &(((struct sockaddr_in *)sa)->sin_addr), s,
                    maxlen);
            break;

        case AF_INET6:
            inet_ntop(AF_INET6,
                    &(((struct sockaddr_in6 *)sa)->sin6_addr), s,
                    maxlen);
            break;

        default:
            strncpy(s, "Unknown AF", maxlen);
            return NULL;
    }

    return s;
}
```

### 関連項目 {.unnumbered .unlisted}

[`getaddrinfo()`](#getaddrinfoman)



[[manbreak]]
## `listen()` {#listenman}

[i[`listen()` function]i]

ソケットに入ってくる接続の待ち受けを指示する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>

int listen(int s, int backlog);
```

### 説明 {.unnumbered .unlisted}

`socket()` システムコールで作ったソケット記述子に、入ってくる接続の待ち受けを指示できる。これがサーバーとクライアントを分けるところだ。

`backlog` パラメータの意味はシステムによって少し違うが、おおまかには、カーネルが新しい接続を拒否し始める前にキューに載せられる保留中の接続数だ。接続が来たら `accept()` を素早く呼んで backlog が溢れないようにしよう。10 前後から始め、高負荷でクライアントが "Connection refused" になるなら上げる。

`listen()` の前に、サーバーは `bind()` で特定のポート番号に結び付けるべきだ。そのポート（サーバーの IP 上）がクライアントの接続先になる。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時は `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
struct addrinfo hints, *res;
int sockfd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_STREAM;
hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

getaddrinfo(NULL, "3490", &hints, &res);

// make a socket:

sockfd = socket(res->ai_family, res->ai_socktype,
    res->ai_protocol);

// bind it to the port we passed in to getaddrinfo():

bind(sockfd, res->ai_addr, res->ai_addrlen);

listen(sockfd, 10); // set sockfd up to be a server socket

// then have an accept() loop down here somewhere
```

### 関連項目 {.unnumbered .unlisted}

[`accept()`](#acceptman), [`bind()`](#bindman), [`socket()`](#socketman)


[[manbreak]]
## `perror()`, `strerror()` {#perrorman}

[i[`perror()` function]i]
[i[`strerror()` function]i]

エラーを人間が読める文字列として表示する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <stdio.h>
#include <string.h>   // for strerror()

void perror(const char *s);
char *strerror(int errnum);
```

### 説明 {.unnumbered .unlisted}

多くの関数がエラー時に `-1` を返し、[i[`errno` variable]] `errno` に番号を入れるので、それを分かりやすく表示できたら便利だ。

`perror()` がそれをやる。エラーの前にもう少し説明を付けたいなら、パラメータ `s` に文字列を指させる（`NULL` のままなら追加表示はない）。

要するに、この関数は `ECONNRESET` のような `errno` 値を "Connection reset by peer." のようにきれいに表示する。

`strerror()` は `perror()` に似ているが、与えた値（通常は `errno`）に対応するエラーメッセージ文字列へのポインタを返す。

### 戻り値 {.unnumbered .unlisted}

`strerror()` はエラーメッセージ文字列へのポインタを返す。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int s;

s = socket(PF_INET, SOCK_STREAM, 0);

if (s == -1) { // some error has occurred
    // prints "socket error: " + the error message:
    perror("socket error");
}

// similarly:
if (listen(s, 10) == -1) {
    // this prints "an error: " + the error message from errno:
    printf("an error: %s\n", strerror(errno));
}
```

### 関連項目 {.unnumbered .unlisted}

[`errno`](#errnoman)


[[manbreak]]
## `poll()` {#pollman}

[i[`poll()` function]i]

複数のソケットで同時にイベントを待つ

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/poll.h>

int poll(struct pollfd *ufds, unsigned int nfds, int timeout);
```

### 説明 {.unnumbered .unlisted}

`select()` と非常に似ていて、どちらもファイル記述子の集合を監視し、受信可能なデータ、`send()` 可能な状態、帯域外データの受信準備、エラーなどのイベントを見る。

基本は `ufds` に `nfds` 個の `struct pollfd` の配列を渡し、タイムアウトをミリ秒で指定する（1 秒は 1000 ミリ秒）。永久に待つなら `timeout` を負にできる。タイムアウトまでにどのソケット記述子でもイベントがなければ `poll()` は戻る。

`struct pollfd` の配列の各要素は 1 つのソケット記述子を表し、次のフィールドを持つ：

[i[`struct pollfd` type]i]

```{.c}
struct pollfd {
    int fd;         // the socket descriptor
    short events;   // bitmap of events we're interested in
    short revents;  // after return, bitmap of events that occurred
};
```

`poll()` の前に `fd` にソケット記述子を入れる（`fd` を負の数にするとこの `struct pollfd` は無視され `revents` は 0）。`events` は次のマクロをビット OR して構築する：

| マクロ     | 説明                                                  |
|-----------|--------------------------------------------------------------|
| `POLLIN`  | このソケットで `recv()` 可能なデータが来たら知らせて。      |
| `POLLOUT` | このソケットへブロックせず `send()` できるようになったら知らせて。|
| `POLLPRI` | このソケットで帯域外データを `recv()` できるようになったら知らせて。|

`poll()` から戻ると `revents` が上記フィールドのビット OR になり、どの記述子でどのイベントが起きたか分かる。加えて次のフィールドも現れることがある：

| マクロ      | 説明                                                 |
|------------|-------------------------------------------------------------|
| `POLLERR`  | このソケットでエラーが発生した。                       |
| `POLLHUP`  | 接続のリモート側が切断した。                  |
| `POLLNVAL` | ソケット記述子 `fd` に問題がある——未初期化？|

### 戻り値 {.unnumbered .unlisted}

イベントが起きた `ufds` 配列の要素数を返す。タイムアウトなら 0。エラー時 `-1`（`errno` が適切に設定される）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int s1, s2;
int rv;
char buf1[256], buf2[256];
struct pollfd ufds[2];

s1 = socket(PF_INET, SOCK_STREAM, 0);
s2 = socket(PF_INET, SOCK_STREAM, 0);

// pretend we've connected both to a server at this point
//connect(s1, ...)...
//connect(s2, ...)...

// set up the array of file descriptors.
//
// in this example, we want to know when there's normal or
// out-of-band (OOB) data ready to be recv()'d...

ufds[0].fd = s1;
ufds[0].events = POLLIN | POLLPRI; // check for normal or OOB

ufds[1].fd = s2;
ufds[1].events = POLLIN; // check for just normal data

// wait for events on the sockets, 3.5 second timeout
rv = poll(ufds, 2, 3500);

if (rv == -1) {
    perror("poll"); // error occurred in poll()
} else if (rv == 0) {
    printf("Timeout occurred! No data after 3.5 seconds.\n");
} else {
    // check for events on s1:
    if (ufds[0].revents & POLLIN) {
        recv(s1, buf1, sizeof buf1, 0); // receive normal data
    }
    if (ufds[0].revents & POLLPRI) {
        recv(s1, buf1, sizeof buf1, MSG_OOB); // out-of-band data
    }

    // check for events on s2:
    if (ufds[1].revents & POLLIN) {
        recv(s1, buf2, sizeof buf2, 0);
    }
}
```

### 関連項目 {.unnumbered .unlisted}

[`select()`](#selectman)


[[manbreak]]
## `recv()`, `recvfrom()` {#recvman}

[i[`recv()` function]i]
[i[`recvfrom()` function]i]

ソケットからデータを受信する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

ssize_t recv(int s, void *buf, size_t len, int flags);
ssize_t recvfrom(int s, void *buf, size_t len, int flags,
                 struct sockaddr *from, socklen_t *fromlen);
```

### 説明 {.unnumbered .unlisted}

ソケットが起動して接続されたら、リモート側からのデータは `recv()`（TCP [i[`SOCK_STREAM` macro]] `SOCK_STREAM` ソケット）と `recvfrom()`（UDP [i[`SOCK_DGRAM` macro]] `SOCK_DGRAM` ソケット）で読める。

両関数ともソケット記述子 `s`、バッファ `buf` へのポインタ、バッファサイズ（バイト）`len`、動作を制御する `flags` を取る。

さらに `recvfrom()` は [i[`struct sockaddr` type]] `struct sockaddr*` の `from` でデータの送信元を教え、`fromlen` に `struct sockaddr` のサイズを入れる。（`fromlen` は `from` または `struct sockaddr` のサイズで初期化する必要もある。）

渡せるフラグはいくつかあるが、ローカルのマンページで詳細とシステムでのサポートを確認してほしい。ビット OR するか、普通の `recv()` にしたければ `flags` を `0` にする。

| マクロ         | 説明                                              |
|---------------|----------------------------------------------------------|
| [i[Out-of-band data]][i[`MSG_OOB` macro]i]`MSG_OOB` | 帯域外データを受信。`send()` で `MSG_OOB` フラグ付きで送られたデータを受け取る方法。受信側では緊急データがあると [i[`SIGURG` macro]i] `SIGURG` が上がる。ハンドラ内でこの `MSG_OOB` 付き `recv()` を呼べる。|
| [i[`MSG_PEEK` macro]i]`MSG_PEEK`                    | `recv()` を「お試し」で呼びたいときに使う。次の本番 `recv()`（`MSG_PEEK` _なし_）の前にバッファに何があるか覗ける。次の `recv()` の予告編のようなもの。| 
| [i[`MSG_WAITALL` macro]i]`MSG_WAITALL`              | `len` で指定したバイト数が全部届くまで `recv()` を返さないよう指示。シグナルで呼び出しが中断されたり、エラーやリモート切断など極端な状況では従わないこともある。怒らないで。| 

`recv()` を呼ぶと、読めるデータがあるまでブロックする。ブロックしたくなければ、ソケットを非ブロッキングにするか、`select()` や `poll()` で受信データの有無を確認してから `recv()` や `recvfrom()` を呼ぶ。

### 戻り値 {.unnumbered .unlisted}

実際に受信したバイト数を返す（`len` より少ないこともある）。エラー時 `-1`（`errno` 設定）。

リモート側が接続を閉じると `recv()` は `0` を返す。リモート切断を判定する通常の方法だ。正常は良いこと、反逆はダメ！

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// stream sockets and recv()

struct addrinfo hints, *res;
int sockfd;
char buf[512];
int byte_count;

// get host info, make socket, and connect it
memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_STREAM;
getaddrinfo("www.example.com", "3490", &hints, &res);
sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
connect(sockfd, res->ai_addr, res->ai_addrlen);

// all right! now that we're connected, we can receive some data!
byte_count = recv(sockfd, buf, sizeof buf, 0);
printf("recv()'d %d bytes of data in buf\n", byte_count);
```

```{.c .numberLines}
// datagram sockets and recvfrom()

struct addrinfo hints, *res;
int sockfd;
int byte_count;
socklen_t fromlen;
struct sockaddr_storage addr;
char buf[512];
char ipstr[INET6_ADDRSTRLEN];

// get host info, make socket, bind it to port 4950
memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
hints.ai_socktype = SOCK_DGRAM;
hints.ai_flags = AI_PASSIVE;
getaddrinfo(NULL, "4950", &hints, &res);
sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
bind(sockfd, res->ai_addr, res->ai_addrlen);

// no need to accept(), just recvfrom():

fromlen = sizeof addr;
byte_count = recvfrom(sockfd, buf, sizeof buf, 0, &addr, &fromlen);

printf("recv()'d %d bytes of data in buf\n", byte_count);
printf("from IP address %s\n",
    inet_ntop(addr.ss_family,
        addr.ss_family == AF_INET?
            ((struct sockaddr_in *)&addr)->sin_addr:
            ((struct sockaddr_in6 *)&addr)->sin6_addr,
        ipstr, sizeof ipstr);
```

### 関連項目 {.unnumbered .unlisted}

[`send()`](#sendman), [`sendto()`](#sendman), [`select()`](#selectman),
[`poll()`](#pollman), [Blocking](#blocking)


[[manbreak]]
## `select()` {#selectman}

[i[`select()` function]i]

ソケット記述子が読み書き可能かどうかを調べる

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/select.h>

int select(int n, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout);

FD_SET(int fd, fd_set *set);
FD_CLR(int fd, fd_set *set);
FD_ISSET(int fd, fd_set *set);
FD_ZERO(fd_set *set);
```

### 説明 {.unnumbered .unlisted}

`select()` は複数のソケットを同時に調べ、どれかに `recv()` 待ちのデータがあるか、ブロックせず `send()` できるか、例外（エラー）が起きたかを知れる。

`FD_SET()` などのマクロでソケット記述子の集合を作り、次のパラメータのいずれかに渡す：`readfds` は集合内のどれかが `recv()` 可能か、`writefds` は `send()` 可能か、`exceptfds` は例外が必要か。関心のない種類は `NULL` でよい。`select()` から戻ると、集合の値は読み書き可能・例外のあったソケットを示すよう変更される。

第 1 パラメータ `n` は、集合内の最大のソケット記述子番号（`int` だ）に 1 を足した値。

最後の [i[`struct timeval` type]i] `struct timeval` `timeout` で、`select()` がどれだけ集合を調べるか指定する。タイムアウトかイベントのどちらか早い方で戻る。`struct timeval` は `tv_sec`（秒）と `tv_usec`（マイクロ秒、1 秒は 1,000,000 マイクロ秒）の 2 フィールド。

ヘルパーマクロの動作：

| マクロ                            | 説明                           |
|----------------------------------|---------------------------------------|
| [i[`FD_SET()` macro]i]`FD_SET(int fd, fd_set *set);`     | `fd` を `set` に追加。|
| [i[`FD_CLR()` macro]i]`FD_CLR(int fd, fd_set *set);`     | `fd` を `set` から削除。|
| [i[`FD_ISSET()` macro]i]`FD_ISSET(int fd, fd_set *set);` | `fd` が `set` にあれば真。|
| [i[`FD_ZERO()` macro]i]`FD_ZERO(fd_set *set);`           | `set` の全エントリをクリア。|

Linux ユーザー向け：Linux の `select()` は "ready-to-read" を返したのに実際には読めず、続く `read()` がブロックすることがある。この不具合の回避策は、受信ソケットに [i[`O_NONBLOCK` macro]] `O_NONBLOCK` を設定して `EWOULDBLOCK` でエラーにし、発生したら無視すること。非ブロッキング設定は [`fcntl()` man page](#fcntlman) を参照。

### 戻り値 {.unnumbered .unlisted}

成功時は集合内の記述子数、`0` はタイムアウト、`-1` はエラー（`errno` 設定）。集合もどのソケットが準備できたか示すよう変更される。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int s1, s2, n;
fd_set readfds;
struct timeval tv;
char buf1[256], buf2[256];

// pretend we've connected both to a server at this point
//s1 = socket(...);
//s2 = socket(...);
//connect(s1, ...)...
//connect(s2, ...)...

// clear the set ahead of time
FD_ZERO(&readfds);

// add our descriptors to the set
FD_SET(s1, &readfds);
FD_SET(s2, &readfds);

// since we got s2 second, it's the "greater", so we use that for
// the n param in select()
n = s2 + 1;

// wait until either socket has data ready to be recv()d
// (timeout 10.5 secs)
tv.tv_sec = 10;
tv.tv_usec = 500000;
rv = select(n, &readfds, NULL, NULL, &tv);

if (rv == -1) {
    perror("select"); // error occurred in select()
} else if (rv == 0) {
    printf("Timeout occurred! No data after 10.5 seconds.\n");
} else {
    // one or both of the descriptors have data
    if (FD_ISSET(s1, &readfds)) {
        recv(s1, buf1, sizeof buf1, 0);
    }
    if (FD_ISSET(s2, &readfds)) {
        recv(s2, buf2, sizeof buf2, 0);
    }
}
```

### 関連項目 {.unnumbered .unlisted}

[`poll()`](#pollman)


[[manbreak]]
## `setsockopt()`, `getsockopt()` {#setsockoptman}

[i[`setsockopt()` function]i]
[i[`getsockopt()` function]i]

ソケットの各種オプションを設定する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int getsockopt(int s, int level, int optname, void *optval,
               socklen_t *optlen);
int setsockopt(int s, int level, int optname, const void *optval,
               socklen_t optlen);
```

### 説明 {.unnumbered .unlisted}

ソケットはかなり設定可能だ。実際、全部はここでは触れない。システム依存の部分も多い。基本だけ話す。

当然、これらの関数はソケットの特定オプションを取得・設定する。Linux ではソケット情報は socket のセクション 7 マンページにある（"`man 7 socket`" と打てば全部出る）。

パラメータとして `s` は対象ソケット、`level` は [i[`SOL_SOCKET` macro]i] `SOL_SOCKET` に設定。`optname` に関心のある名前を設定。オプション一覧はマンページだが、よく使うものをいくつか：

| `optname`         | 説明                                          |
|-------------------|------------------------------------------------------|
| [i[`SO_BINDTODEVICE` macro]i]`SO_BINDTODEVICE` | IP アドレスへの `bind()` の代わりに、`eth0` のようなシンボルデバイス名にソケットを結び付ける。Unix で `ifconfig` を打てばデバイス名が見える。|
| [i[`SO_REUSEADDR` macro]i]`SO_REUSEADDR      ` | すでにそのポートでアクティブな待ち受けソケットがなければ、他のソケットも同じポートに `bind()` できる。クラッシュ後にサーバーを再起動するときの "Address already in use" を回避できる。|
| [i[`SO_BROADCAST` macro]i]`SO_BROADCAST`       | UDP データグラム（`SOCK_DGRAM`）ソケットがブロードキャストアドレス宛ての送受信を許可。TCP ストリームソケットには _何も_ しない！！ ハハハ！|

`optval` パラメータはたいてい値を示す `int` へのポインタ。真偽値では 0 が false、非ゼロが true。絶対の事実——システムによって違うかもしれないが。渡す値がなければ `optval` は `NULL` でよい。

最後の `optlen` は `optval` の長さで、たぶん `sizeof(int)` だがオプションによる。`getsockopt()` では `socklen_t` へのポインタで、`optval` に書き込む最大サイズ（バッファオーバーフロー防止）を指定する。`getsockopt()` は実際に設定したバイト数で `optlen` を更新する。

**警告**：一部システム（特に [i[SunOS]] [i[Solaris]] Sun や [i[Windows]] Windows）では、オプションが `int` ではなく `char` で、例えば `int` の `1` ではなく文字 `'1'` になる。詳細は "`man setsockopt`" と "`man 7 socket`" でローカルマンページを確認！

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時 `-1`（`errno` 設定）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int optval;
int optlen;
char *optval2;

// set SO_REUSEADDR on a socket to true (1):
optval = 1;
setsockopt(s1, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval);

// bind a socket to a device name (might not work on all systems):
optval2 = "eth1"; // 4 bytes long, so 4, below:
setsockopt(s2, SOL_SOCKET, SO_BINDTODEVICE, optval2, 4);

// see if the SO_BROADCAST flag is set:
getsockopt(s3, SOL_SOCKET, SO_BROADCAST, &optval, &optlen);
if (optval != 0) {
    print("SO_BROADCAST enabled on s3!\n");
}
```

### 関連項目 {.unnumbered .unlisted}

[`fcntl()`](#fcntlman)


[[manbreak]]
## `send()`, `sendto()` {#sendman}

[i[`send()` function]i]
[i[`sendto()` function]i]

ソケットからデータを送信する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

ssize_t send(int s, const void *buf, size_t len, int flags);
ssize_t sendto(int s, const void *buf, size_t len,
               int flags, const struct sockaddr *to,
               socklen_t tolen);
```

### 説明 {.unnumbered .unlisted}

これらの関数はソケットへデータを送る。一般に `send()` は TCP `SOCK_STREAM` の接続済みソケット向け、`sendto()` は UDP `SOCK_DGRAM` の未接続データグラム向け。未接続ソケットではパケットの行き先を送るたびに指定する必要があり、`sendto()` の末尾パラメータが宛先を定義する。

`send()` も `sendto()` も、パラメータ `s` はソケット、`buf` は送りたいデータへのポインタ、`len` は送るバイト数、`flags` は送信方法の追加情報。普通のデータなら `flags` は 0。よく使うフラグをいくつか（詳細はローカルの `send()` マンページ）：

| マクロ           | 説明                                            |
|-----------------|--------------------------------------------------------|
| [i[`MSG_OOB` macro]i]`MSG_OOB`             | [i[Out-of-band data]] 帯域外データとして送る。TCP がサポート。通常データより優先度が高いことを受信側に伝える。受信側は [i[`SIGURG` macro]i] `SIGURG` を受け取り、キュー内の通常データを全部受け取る前にこのデータを受信できる。|
| [i[`MSG_DONTROUTE` macro]i]`MSG_DONTROUTE` | ルータ経由にせずローカルに留める。|
| [i[`MSG_DONTWAIT` macro]i]`MSG_DONTWAIT`   | 送信が詰まって `send()` がブロックするなら [i[`EAGAIN` macro]] `EAGAIN` で返す。"この send だけ [i[Non-blocking sockets]] 非ブロッキング" のようなもの。詳細は [blocking](#blocking) の節。|
| [i[`MSG_NOSIGNAL` macro]i]`MSG_NOSIGNAL`   | もう `recv()` していないリモートへ `send()` すると通常 [i[`SIGPIPE` macro]] `SIGPIPE` が上がる。このフラグでそのシグナルを抑止。|

### 戻り値 {.unnumbered .unlisted}

実際に送ったバイト数、または `-1`（`errno` 設定）。要求したバイト数より少なく送られることもある！[partial `send()`s](#sendall) の節のヘルパー関数を参照。

また、どちらかの側がソケットを閉じると `send()` 側は `SIGPIPE` を受ける（`MSG_NOSIGNAL` 付きで呼ばない限り）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int spatula_count = 3490;
char *secret_message = "The Cheese is in The Toaster";

int stream_socket, dgram_socket;
struct sockaddr_in dest;
int temp;

// first with TCP stream sockets:

// assume sockets are made and connected
//stream_socket = socket(...
//connect(stream_socket, ...

// convert to network byte order
temp = htonl(spatula_count);
// send data normally:
send(stream_socket, &temp, sizeof temp, 0);

// send secret message out of band:
send(stream_socket, secret_message, strlen(secret_message)+1,
        MSG_OOB);

// now with UDP datagram sockets:
//getaddrinfo(...
//dest = ... // assume "dest" holds the address of the destination
//dgram_socket = socket(...

// send secret message normally:
sendto(dgram_socket, secret_message, strlen(secret_message)+1, 0, 
       (struct sockaddr*)&dest, sizeof dest);
```

### 関連項目 {.unnumbered .unlisted}

[`recv()`](#recvman), [`recvfrom()`](#recvman)


[[manbreak]]
## `shutdown()` {#shutdownman}

[i[`shutdown()` function]i]

ソケットでの以降の送受信を止める

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/socket.h>

int shutdown(int s, int how);
```

### 説明 {.unnumbered .unlisted}

もうたくさん！ このソケットではこれ以上 `send()` 禁止、でも `recv()` は続けたい！ またはその逆！ どうすれば？

ソケット記述子を `close()` すると読み書き両方が閉じ、記述子も解放される。片側だけ止めたいなら `shutdown()` を使う。

パラメータ `s` は対象ソケット、`how` で動作を指定。[i[`SHUT_RD` macro]i]`SHUT_RD` は以降の `recv()` を禁止、[i[`SHUT_WR` macro]i]`SHUT_WR` は `send()` を禁止、[i[`SHUT_RDWR` macro]i]`SHUT_RDWR` は両方。

`shutdown()` 自体はソケット記述子を解放しない。完全にシャットダウンしても、最終的には `close()` が必要。

あまり使われないシステムコールだ。

### 戻り値 {.unnumbered .unlisted}

成功時は 0、エラー時 `-1`（`errno` 設定）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
int s = socket(PF_INET, SOCK_STREAM, 0);

// ...do some send()s and stuff in here...

// and now that we're done, don't allow any more sends()s:
shutdown(s, SHUT_WR);
```

### 関連項目 {.unnumbered .unlisted}

[`close()`](#closeman)


[[manbreak]]
## `socket()` {#socketman}

[i[`socket()` function]i]

ソケット記述子を確保する

### 概要 {.unnumbered .unlisted}

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int socket(int domain, int type, int protocol);
```

### 説明 {.unnumbered .unlisted}

ソケットプログラムを書く長い道のりの、たいてい最初の呼び出しで返る新しいソケット記述子。以降 `listen()`、`bind()`、`accept()` などに使える。

通常、これらのパラメータ値は下の例のように `getaddrinfo()` から得る。本当に望むなら手で埋めてもよい。

| パラメータ  | 説明                                                 |
|------------|-------------------------------------------------------------|
| `domain`   | `domain` は欲しいソケットの種類。種類は実に広いが、このソケットガイドでは [i[`PF_INET` macro]i] `PF_INET`（IPv4）と `PF_INET6`（IPv6）が中心。|
| `type`     | `type` もいろいろあるが、たいてい [i[`SOCK_STREAM` macro]i] `SOCK_STREAM`（信頼性のある TCP、`send()`/`recv()`）か [i[`SOCK_DGRAM` macro]i] `SOCK_DGRAM`（信頼性のない高速 UDP、`sendto()`/`recvfrom()`）にする。（[i[`SOCK_RAW` macro]i] `SOCK_RAW` はパケットを手組みするタイプで、かなりクール。）| 
| `protocol` | `protocol` はソケット型に使うプロトコル。例えば `SOCK_STREAM` は TCP。幸い、`SOCK_STREAM` か `SOCK_DGRAM` なら `protocol` を 0 にして自動選択でよい。それ以外なら [i[`getprotobyname()` function]] `getprotobyname()` でプロトコル番号を調べる。|

### 戻り値 {.unnumbered .unlisted}

以降の呼び出しに使う新しいソケット記述子、または `-1`（`errno` 設定）。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
struct addrinfo hints, *res;
int sockfd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;     // AF_INET, AF_INET6, or AF_UNSPEC
hints.ai_socktype = SOCK_STREAM; // SOCK_STREAM or SOCK_DGRAM

getaddrinfo("www.example.com", "3490", &hints, &res);

// make a socket using the information gleaned from getaddrinfo():
sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
```

### 関連項目 {.unnumbered .unlisted}

[`accept()`](#acceptman), [`bind()`](#bindman),
[`getaddrinfo()`](#getaddrinfoman), [`listen()`](#listenman)


[[manbreak]]
## `struct sockaddr` と仲間たち {#structsockaddrman}

[i[`struct sockaddr` type]i]
[i[`struct sockaddr_in` type]i]
[i[`struct in_addr` type]i]
[i[`struct sockaddr_in6` type]i]
[i[`struct in6_addr` type]i]
[i[`struct sockaddr_storage` type]i]

インターネットアドレスを扱う構造体

### 概要 {.unnumbered .unlisted}

```{.c}
#include <netinet/in.h>

// All pointers to socket address structures are often cast to
// pointers to this type before use in various functions and system
// calls:

struct sockaddr {
    unsigned short    sa_family;    // address family, AF_xxx
    char              sa_data[14];  // 14 bytes of protocol address
};


// IPv4 AF_INET sockets:

struct sockaddr_in {
    short            sin_family;   // e.g. AF_INET, AF_INET6
    unsigned short   sin_port;     // e.g. htons(3490)
    struct in_addr   sin_addr;     // see struct in_addr, below
    char             sin_zero[8];  // zero this if you want to
};

struct in_addr {
    unsigned long s_addr;          // load with inet_pton()
};


// IPv6 AF_INET6 sockets:

struct sockaddr_in6 {
    u_int16_t       sin6_family;   // address family, AF_INET6
    u_int16_t       sin6_port;     // port number, network order
    u_int32_t       sin6_flowinfo; // IPv6 flow information
    struct in6_addr sin6_addr;     // IPv6 address
    u_int32_t       sin6_scope_id; // Scope ID
};

struct in6_addr {
    unsigned char   s6_addr[16];   // load with inet_pton()
};


// General socket address holding structure, big enough to hold
// either struct sockaddr_in or struct sockaddr_in6 data:

struct sockaddr_storage {
    sa_family_t  ss_family;     // address family

    // all this is padding, implementation specific, ignore it:
    char      __ss_pad1[_SS_PAD1SIZE];
    int64_t   __ss_align;
    char      __ss_pad2[_SS_PAD2SIZE];
};
```

### 説明 {.unnumbered .unlisted}

インターネットアドレスを扱うすべてのシステムコール・関数の基本構造体。多くの場合 `getaddrinfo()` でこれらを埋め、必要なときに読む。

メモリ上では `struct sockaddr_in` と `struct sockaddr_in6` は `struct sockaddr` と先頭構造を共有しており、一方のポインタを他方に自由にキャストしても害はない——宇宙の終わりを除いて。

宇宙の終わりの話は冗談……`struct sockaddr_in*` を `struct sockaddr*` にキャストして宇宙が終わるなら、純粋な偶然だから心配しないで。

覚えておいて：`struct sockaddr*` を取る関数には、`struct sockaddr_in*`、`struct sockaddr_in6*`、`struct sockaddr_storage*` を安全にキャストして渡せる。

`struct sockaddr_in` は IPv4 アドレス（例 "192.0.2.10"）用。アドレスファミリー（`AF_INET`）、ポート `sin_port`、IPv4 アドレス `sin_addr` を持つ。

`struct sockaddr_in` には `sin_zero` フィールドもあり、ゼロにしなければならないと主張する人もいる。主張しない人もいる（Linux ドキュメントは触れていない）。実際ゼロにしなくても動く。気が向けば `memset()` でゼロにしてよい。

`struct in_addr` はシステムごとに変わる。ときどき `#define` だらけの `union` だ。使うのは `s_addr` フィールドだけでよい。多くのシステムはそれしか実装していない。

`struct sockaddr_in6` と `struct in6_addr` は IPv6 版で、構造は似ている。

`struct sockaddr_storage` は `accept()` や `recvfrom()` に渡す IP 版非依存コード用。新しいアドレスが IPv4 か IPv6 か分からないとき、元の小さな `struct sockaddr` とは違い、どちらも載せられるほど大きい。

### 例 {.unnumbered .unlisted}

```{.c .numberLines}
// IPv4:

struct sockaddr_in ip4addr;
int s;

ip4addr.sin_family = AF_INET;
ip4addr.sin_port = htons(3490);
inet_pton(AF_INET, "10.0.0.1", &ip4addr.sin_addr);

s = socket(PF_INET, SOCK_STREAM, 0);
bind(s, (struct sockaddr*)&ip4addr, sizeof ip4addr);
```

```{.c .numberLines}
// IPv6:

struct sockaddr_in6 ip6addr;
int s;

ip6addr.sin6_family = AF_INET6;
ip6addr.sin6_port = htons(4950);
inet_pton(AF_INET6, "2001:db8:8714:3a90::12", &ip6addr.sin6_addr);

s = socket(PF_INET6, SOCK_STREAM, 0);
bind(s, (struct sockaddr*)&ip6addr, sizeof ip6addr);
```

### 関連項目 {.unnumbered .unlisted}

[`accept()`](#acceptman), [`bind()`](#bindman), [`connect()`](#connectman),
[`inet_aton()`](#inet_ntoaman), [`inet_ntoa()`](#inet_ntoaman)
