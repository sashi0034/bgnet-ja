# システムコール、本番

ここからは、Unix マシン（あるいは BSD、Windows、Linux、Mac など、ソケット API をサポートするマシンなら何でも）のネットワーク機能にアクセスするためのシステムコール（およびその他のライブラリコール）の話をする。これらの関数のどれかを呼ぶと、カーネルが引き受けて、魔法のように全部やってくれる。

多くの人がここでつまずくのは、これらをどんな順番で呼べばいいか、という点だ。`man` ページは（おそらく気づいただろう）その点では役に立たない。そんな悲惨な状況を少しでも助けるため、以下のセクションでは、プログラムで呼ぶ順番と（だいたい）同じ順番でシステムコールを並べた。

それに、あちこちに散らばったサンプルコード、ミルクとクッキー（残念ながら自分で用意してもらう）、そして生の根性と勇気があれば、ジョン・ポステルの息子のようにインターネット上をデータを飛ばせるようになる！

_（簡潔にするため、以下の多くのコード片には必要なエラーチェックを含めていない。また、`getaddrinfo()` の呼び出しが成功してリンクリストに有効なエントリを返すと、よく暗黙に仮定している。どちらも独立したプログラムではきちんと扱っているので、そちらを手本にしてほしい。）_


## `getaddrinfo()`——発射準備！

[i[`getaddrinfo()` function]] オプションがたくさんある実働的な関数だが、使い方自体はかなりシンプルだ。後で必要になる `struct` のセットアップを手伝ってくれる。

少し歴史：`gethostbyname()` で DNS ルックアップをしていた時代があった。得た情報を手で `struct sockaddr_in` に詰め、それを各種呼び出しに使っていた。

今はそんな必要はない、ありがたいことに。（IPv4 と IPv6 の両方で動くコードを書きたいなら、望ましくもない！）現代では `getaddrinfo()` があり、DNS やサービス名のルックアップに加え、必要な `struct` まで埋めてくれる。

見てみよう！

```{.c}
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

int getaddrinfo(const char *node,   // e.g. "www.example.com" or IP
                const char *service,  // e.g. "http" or port number
                const struct addrinfo *hints,
                struct addrinfo **res);
```

この関数には 3 つの入力パラメータを渡し、結果のリンクリスト `res` へのポインタが返る。

`node` パラメータは接続先のホスト名、または IP アドレスだ。

次が `service` パラメータで、ポート番号（"80" など）か、特定サービスの名前（[fl[The IANA Port
List|https://www.iana.org/assignments/port-numbers]] や Unix マシンの `/etc/services` にある "http"、"ftp"、"telnet"、"smtp" など）を指定できる。

最後に `hints` パラメータは、関連情報をすでに埋めた `struct addrinfo` を指す。

サーバー側で、ホストの IP アドレスの 3490 番ポートで待ち受けたい場合のサンプル呼び出しだ。実際に listen したりネットワークをセットアップするわけではなく、後で使う構造体を用意するだけであることに注意：

```{.c .numberLines}
int status;
struct addrinfo hints;
struct addrinfo *servinfo;  // will point to the results

memset(&hints, 0, sizeof hints); // make sure the struct is empty
hints.ai_family = AF_UNSPEC;     // don't care IPv4 or IPv6
hints.ai_socktype = SOCK_STREAM; // TCP stream sockets
hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

if ((status = getaddrinfo(NULL, "3490", &hints, &servinfo)) != 0) {
    fprintf(stderr, "gai error: %s\n", gai_strerror(status));
    exit(1);
}

// servinfo now points to a linked list of 1 or more
// struct addrinfos

// ... do everything until you don't need servinfo anymore ....

freeaddrinfo(servinfo); // free the linked-list
```

`ai_family` を `AF_UNSPEC` にしているのは、IPv4 でも IPv6 でもどちらでもいい、という意味だ。どちらか一方に限定したいなら `AF_INET` か `AF_INET6` に設定できる。

`AI_PASSIVE` フラグも入っている。これは `getaddrinfo()` にローカルホストのアドレスをソケット構造体に入れさせる。ハードコードしなくて済むので便利だ。（今 `NULL` にしている `getaddrinfo()` の第 1 引数に特定のアドレスを渡してもいい。）

呼び出す。エラーなら（`getaddrinfo()` が非ゼロを返す）、`gai_strerror()` で表示できる。うまくいけば `servinfo` は `struct addrinfo` のリンクリストを指し、各要素には後で使える何らかの `struct sockaddr` が入っている。便利だ！

最後に、`getaddrinfo()` が親切にも確保してくれたリンクリストを使い終わったら、`freeaddrinfo()` で（すべきだし）解放する。

クライアント側で "www.example.net" の 3490 番ポートなど、特定サーバーに接続したい場合のサンプル呼び出しだ。こちらも実際には接続せず、後で使う構造体をセットアップするだけ：

```{.c .numberLines}
int status;
struct addrinfo hints;
struct addrinfo *servinfo;  // will point to the results

memset(&hints, 0, sizeof hints); // make sure the struct is empty
hints.ai_family = AF_UNSPEC;     // don't care IPv4 or IPv6
hints.ai_socktype = SOCK_STREAM; // TCP stream sockets

// get ready to connect
status = getaddrinfo("www.example.net", "3490", &hints, &servinfo);

// servinfo now points to a linked list of 1 or more
// struct addrinfos

// etc.
```

`servinfo` はあらゆる種類のアドレス情報を持つリンクリストだと何度も言っている。デモプログラムでその情報を表示してみよう。[flx[この短いプログラム|showip.c]] は、コマンドラインで指定したホストの IP アドレスを表示する：

```{.c .numberLines}
/*
** showip.c
**
** show IP addresses for a host given on the command line
*/

#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>

int main(int argc, char *argv[])
{
    struct addrinfo hints, *res, *p;
    int status;
    char ipstr[INET6_ADDRSTRLEN];

    if (argc != 2) {
        fprintf(stderr,"usage: showip hostname\n");
        return 1;
    }

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;  // Either IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;

    if ((status = getaddrinfo(argv[1], NULL, &hints, &res)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(status));
        return 2;
    }

    printf("IP addresses for %s:\n\n", argv[1]);

    for(p = res;p != NULL; p = p->ai_next) {
        void *addr;
        char *ipver;
        struct sockaddr_in *ipv4;
        struct sockaddr_in6 *ipv6;

        // get the pointer to the address itself,
        // different fields in IPv4 and IPv6:
        if (p->ai_family == AF_INET) { // IPv4
            ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr = &(ipv4->sin_addr);
            ipver = "IPv4";
        } else { // IPv6
            ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
            ipver = "IPv6";
        }

        // convert the IP to a string and print it:
        inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
        printf("  %s: %s\n", ipver, ipstr);
    }

    freeaddrinfo(res); // free the linked list

    return 0;
}
```

ご覧のとおり、コマンドライン引数で `getaddrinfo()` を呼び、`res` のリンクリストを埋め、リストを走査して表示したり何でもできる。

（IP バージョンによって `struct sockaddr` の型が違うので、そこを掘り下げる少し醜い部分がある。すまない！もっと良い方法があるかはわからない。）

実行例！みんなスクリーンショットが好きだろ：

```
$ showip www.example.net
IP addresses for www.example.net:

  IPv4: 192.0.2.88

$ showip ipv6.example.com
IP addresses for ipv6.example.com:

  IPv4: 192.0.2.101
  IPv6: 2001:db8:8c00:22::171
```

これが片付いたら、`getaddrinfo()` の結果を他のソケット関数に渡し、ついにネットワーク接続を確立する！読み進めてくれ！


## `socket()`——ファイルディスクリプタを手に入れろ！ {#socket}

もう先延ばしできない——[i[`socket()` function]] `socket()` システムコールの話をしなければならない。概要はこうだ：

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int socket(int domain, int type, int protocol); 
```

引数は何を意味する？ どんなソケットが欲しいか（IPv4 か IPv6、ストリームかデータグラム、TCP か UDP）を指定できる。

昔はこれらの値をハードコードしていた。今でも全然できる。（`domain` は `PF_INET` か `PF_INET6`、`type` は `SOCK_STREAM` か `SOCK_DGRAM`、`protocol` は `0` にして与えられた `type` に適したプロトコルを選ばせる。または `getprotobyname()` で "tcp" や "udp" を調べる。）

（この `PF_INET` は、`struct sockaddr_in` の `sin_family` を初期化するときに使う [i[`AF_INET` macro]]
`AF_INET` の近い親戚だ。実際、値は同じで、多くのプログラマは `socket()` に第 1 引数として `PF_INET` ではなく `AF_INET` を渡す。さて、ミルクとクッキーの時間だ——昔話をしよう。ずっと昔、アドレスファミリー（"`AF_INET`" の "AF" が指すもの）が、プロトコルファミリー（"`PF_INET`" の "PF"）で呼ばれる複数のプロトコルをサポートするかも、と考えられていた。そうはならなかった。みんな幸せに暮らした、おしまい。だから正しいのは `struct sockaddr_in` では `AF_INET`、`socket()` の呼び出しでは `PF_INET` を使うことだ。）

とにかく、本当にやりたいのは `getaddrinfo()` の結果から得た値を `socket()` にそのまま渡すことだ：

```{.c .numberLines}
int s;
struct addrinfo hints, *res;

// do the lookup
// [pretend we already filled out the "hints" struct]
getaddrinfo("www.example.com", "http", &hints, &res);

// again, you should do error-checking on getaddrinfo(), and walk
// the "res" linked list looking for valid entries instead of just
// assuming the first one is good (like many of these examples do).
// See the section on client/server for real examples.

s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
```

`socket()` は後続のシステムコールで使う _ソケットディスクリプタ_ を返す。エラーなら `-1`。グローバル変数 `errno` にエラー値がセットされる（詳細は [`errno`](#errnoman) の man ページ、マルチスレッドでの `errno` についての短い注も参照）。

いい、いい、いい——でもこのソケット単体では何の役にも立たない。読み進めてさらにシステムコールを呼ばないと意味がない。


## `bind()`——俺は何番ポート？ {#bind}

[i[`bind()` function]] ソケットを手に入れたら、ローカルマシンの [i[Port]] ポートにそのソケットを関連付ける必要がある。（特定ポートで [i[`listen()` function]] `listen()` して着信接続を待つときによくやる——マルチプレイのネットワークゲームが「192.168.5.10 の 3490 番に接続して」と言うのと同じ。）ポート番号は、カーネルが着信パケットを特定プロセスのソケットディスクリプタに対応付けるために使う。クライアントとして [i[`connect()`] function] `connect()` だけするなら、たぶん不要だ。とにかく読んでおけ——暇つぶしに。

`bind()` システムコールの概要：

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int bind(int sockfd, struct sockaddr *my_addr, int addrlen);
```

`sockfd` は `socket()` が返したソケットファイルディスクリプタ。`my_addr` はアドレス情報、つまりポートと [i[IP address]] IP アドレスを含む `struct sockaddr` へのポインタ。`addrlen` はそのアドレスのバイト長。

ふう。一気に飲み込むには多い。プログラムが動いているホストの 3490 番ポートにソケットを bind する例：

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

sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

// bind it to the port we passed in to getaddrinfo():

bind(sockfd, res->ai_addr, res->ai_addrlen);
```

`AI_PASSIVE` フラグで、プログラムが動いているホストの IP に bind するよう指示している。特定のローカル IP に bind したいなら `AI_PASSIVE` を外し、`getaddrinfo()` の第 1 引数に IP アドレスを渡す。

`bind()` もエラーで `-1` を返し `errno` をセットする。

古いコードは `bind()` の前に手で `struct sockaddr_in` を詰めていた。IPv4 専用だが、IPv6 でも同じことはできる——ただし一般には `getaddrinfo()` の方が楽だ。古いコードはだいたいこんな感じ：

```{.c .numberLines}
// !!! THIS IS THE OLD WAY !!!

int sockfd;
struct sockaddr_in my_addr;

sockfd = socket(PF_INET, SOCK_STREAM, 0);

my_addr.sin_family = AF_INET;
my_addr.sin_port = htons(MYPORT);     // short, network byte order
my_addr.sin_addr.s_addr = inet_addr("10.12.110.57");
memset(my_addr.sin_zero, '\0', sizeof my_addr.sin_zero);

bind(sockfd, (struct sockaddr *)&my_addr, sizeof my_addr);
```

上のコードでは、上の `AI_PASSIVE` と同様にローカル IP に bind したければ `s_addr` に `INADDR_ANY` を代入してもいい。`INADDR_ANY` の IPv6 版は `struct sockaddr_in6` の `sin6_addr` に代入するグローバル変数 `in6addr_any` だ。（変数初期化子として使えるマクロ `IN6ADDR_ANY_INIT` もある。）

`bind()` を呼ぶときのもう 1 つの注意：ポート番号を使いすぎないこと。[i[Port]] 1024 未満のポートはすべて予約されている（スーパーユーザーでない限り）！ それより上なら 65535 まで（他のプログラムが使っていなければ）好きな番号が使える。

ときどき、サーバーを再実行すると `bind()` が失敗し、[i[Address already in use]] "Address already in use." と言うことがある。どういうこと？ 接続されていたソケットの断片がカーネルに残っていて、ポートを占有している。消えるまで待つ（1 分ほど）か、ポートを再利用できるようにコードを足す：

[i[`setsockopt()` function]]
 [i[`SO_REUSEADDR` macro]]

```{.c .numberLines}
int yes=1;
//char yes='1'; // Solaris people use this

// lose the pesky "Address already in use" error message
setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);
```

[i[`bind()` function]] `bind()` について、最後にもう 1 点：必ずしも呼ばなくていい場合がある。リモートマシンに [i[`connect()` function]] `connect()` するだけでローカルポートを気にしない場合（リモートポートだけ気にする `telnet` のように）、単に `connect()` を呼べば、ソケットが未 bind なら未使用のローカルポートに `bind()` してくれる。


## `connect()`——おい、そこの君！ {#connect}

[i[`connect()` function]] 数分だけ telnet アプリケーションのふりをしよう。ユーザー（映画 [i[TRON]] _TRON_ のように）がソケットファイルディスクリプタを取れと命じる。従って `socket()` を呼ぶ。次に "`10.12.110.57`" の "`23`" 番（標準 telnet ポート）に接続しろ、と言われた。どうする？

幸い、`connect()` のセクションを読んでいる——リモートホストへの接続方法だ。猛スピードで読み進めろ！ 時間がない！

`connect()` の呼び出しは次のとおり：

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int connect(int sockfd, struct sockaddr *serv_addr, int addrlen); 
```

`sockfd` は `socket()` が返したソケットファイルディスクリプタ。`serv_addr` は宛先ポートと IP アドレスを含む `struct sockaddr`。`addrlen` はサーバーアドレス構造体のバイト長。

この情報はすべて `getaddrinfo()` の結果から取れる。最高だ。

だんだんわかってきたか？ ここからは聞こえないので、そうだと信じるしかない。例として "`www.example.com`" の `3490` 番ポートへのソケット接続：

```{.c .numberLines}
struct addrinfo hints, *res;
int sockfd;

// first, load up address structs with getaddrinfo():

memset(&hints, 0, sizeof hints);
hints.ai_family = AF_UNSPEC;
hints.ai_socktype = SOCK_STREAM;

getaddrinfo("www.example.com", "3490", &hints, &res);

// make a socket:

sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

// connect!

connect(sockfd, res->ai_addr, res->ai_addrlen);
```

古いプログラムは `connect()` に渡す `struct sockaddr_in` を自分で詰めていた。やりたければできる。上の [`bind()` セクション](#bind) の同様の注を参照。

`connect()` の戻り値は必ず確認——エラーなら `-1` で `errno` がセットされる。

[i[`bind()` function-->implicit]]

`bind()` は呼んでいないことにも注意。基本的にローカルポートは気にせず、行き先（リモートポート）だけ気にする。カーネルがローカルポートを選び、接続先は自動的にその情報を受け取る。心配無用。


## `listen()`——誰か電話してくれ！ {#listen}

[i[`listen()` function]] さて、テンポを変えよう。リモートホストに接続したくないとする。例えば着信接続を待って何か処理したい。手順は 2 段階：まず `listen()`、それから [i[`accept()`
function]] `accept()`（下参照）。

`listen()` の呼び出しは比較的シンプルだが、少し説明が要る：

```{.c}
int listen(int sockfd, int backlog); 
```

`sockfd` は `socket()` システムコールの通常のソケットファイルディスクリプタ。[i[`listen()` function-->backlog]] `backlog` は着信キューに載せられる接続数の上限。どういう意味？ 着信接続は `accept()` するまで（下参照）このキューで待ち、この数が上限だ。多くのシステムは黙って 20 前後に制限する。`5` か `10` にしておけばだいたい大丈夫。

いつものように `listen()` はエラーで `-1`、`errno` をセットする。

想像のとおり、`listen()` の前に `bind()` が必要で、サーバーが特定ポートで動いている必要がある。（仲間にどのポートに接続すればいいか教えられないと！） 着信を待つなら、システムコールの順序は：

```{.c .numberLines}
getaddrinfo();
socket();
bind();
listen();
/* accept() goes here */ 
```

サンプルコードの代わりにこれだけ置いておく——だいたい自明だから。（下の `accept()` セクションのコードの方が完全だ。）本当にトリッキーなのは `accept()` の呼び出しだ。


## `accept()`——「3490 番端口にお電話ありがとうございます」

[i[`accept()` function]] 覚悟して——`accept()` の呼び出しはちょっと変だ！ こうなる：遠くの誰かが、あなたが `listen()` しているポートに `connect()` する。接続は `accept()` されるまでキューに並ぶ。`accept()` を呼んで保留中の接続を取る。_この 1 接続専用の、真新しいソケットファイルディスクリプタ_ が返る！ そう、いきなり _ソケットファイルディスクリプタが 2 つ_ 手に入る！ 元の方は引き続き新しい接続を待ち、新しく作られた方がついに `send()` と `recv()` の準備が整う。到達だ！

呼び出しは次のとおり：

```{.c}
#include <sys/types.h>
#include <sys/socket.h>

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen); 
```

`sockfd` は `listen()` 中のソケットディスクリプタ。簡単だ。`addr` は通常ローカルの `struct sockaddr_storage` へのポインタ。着信接続の情報が入り（どのホストのどのポートからかわかる）。`addrlen` は `accept()` に渡す前に `sizeof(struct sockaddr_storage)` にセットしておくローカル整数。`addr` に入れるバイト数はそれ以上にならない。少なければ `addrlen` の値を書き換える。

当たり前だが、エラーなら `accept()` は `-1` で `errno` をセットする。
当ててみろ。

前と同様、一気に多いのでサンプル断片：

```{.c .numberLines}
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#define MYPORT "3490"  // the port users will be connecting to
#define BACKLOG 10     // how many pending connections queue holds

int main(void)
{
    struct sockaddr_storage their_addr;
    socklen_t addr_size;
    struct addrinfo hints, *res;
    int sockfd, new_fd;

    // !! don't forget your error checking for these calls !!

    // first, load up address structs with getaddrinfo():

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;  // use IPv4 or IPv6, whichever
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;     // fill in my IP for me

    getaddrinfo(NULL, MYPORT, &hints, &res);

    // make a socket, bind it, and listen on it:

    sockfd = socket(res->ai_family, res->ai_socktype,
                                                 res->ai_protocol);
    bind(sockfd, res->ai_addr, res->ai_addrlen);
    listen(sockfd, BACKLOG);

    // now accept an incoming connection:

    addr_size = sizeof their_addr;
    new_fd = accept(sockfd, (struct sockaddr *)&their_addr,
                                                       &addr_size);

    // ready to communicate on socket descriptor new_fd!
    .
    .
    .
```

繰り返すが、すべての `send()` と `recv()` にはソケットディスクリプタ `new_fd` を使う。接続が 1 回だけなら、同じポートへの追加着信を防ぐために listen 用の `sockfd` を `close()` してもいい。


## `send()` と `recv()`——話しかけてよ、ベイベー！ {#sendrecv}

この 2 つはストリームソケット、または接続済みデータグラムソケットでの通信用だ。通常の非接続データグラムソケットなら、下の [`sendto()` と
`recvfrom()`](#sendtorecv) のセクションを見てほしい。

> [i[Blocking]] 新しいかもしれない点：これらは _ブロッキング_ 呼び出しだ。`recv()` は受信可能なデータがあるまで _ブロック_ する。「ブロックって何だよ？！」 そのシステムコールのところでプログラムが止まる、という意味だ。誰かが何か送るまで。（OS 技術者の用語では「止まる」は実際 _sleep_ なので、混ぜて使うかもしれない。）`send()` も送るデータが詰まっているとブロックすることがあるが、稀だ。この概念は[後で再訪](#blocking)し、必要なときの回避法も話す。

[i[`send()` function]] `send()` の呼び出し：

```{.c}
int send(int sockfd, const void *msg, int len, int flags); 
```

`sockfd` はデータを送るソケットディスクリプタ（`socket()` が返したものでも `accept()` で得たものでも）。`msg` は送りたいデータへのポインタ、`len` はそのバイト長。`flags` は `0` でいい。（フラグの詳細は `send()` の man ページ参照。）

サンプルコード：

```{.c .numberLines}
char *msg = "Beej was here!";
int len, bytes_sent;
.
.
.
len = strlen(msg);
bytes_sent = send(sockfd, msg, len, 0);
.
.
. 
```

`send()` は実際に送れたバイト数を返す——_指定した数より少ないことがある！_ 大量のデータを送れと言っても処理しきれないことがある。送れる分だけ送り、残りは後で送る前提だ。`send()` の戻り値が `len` と一致しなければ、残りの文字列を送るのは自分の責任だ。良いニュース：パケットが小さければ（1K 前後以下）だいたい一発で全部送れる。エラーなら `-1`、`errno` にエラー番号。

[i[`recv()` function]] `recv()` は多くの点で似ている：

```{.c}
int recv(int sockfd, void *buf, int len, int flags);
```

`sockfd` は読み取るソケットディスクリプタ、`buf` は読み込み先バッファ、`len` はバッファの最大長、`flags` は再び `0` でよい。（フラグは `recv()` の man ページ参照。）

`recv()` はバッファに実際に読み込んだバイト数を返す。エラーなら `-1`（`errno` もセット）。

待て！ `recv()` は `0` を返すことがある。意味は 1 つだけ：向こう側が接続を閉じた！ 戻り値 `0` はその通知だ。

簡単だったろ？ ストリームソケット上でデータを行き来できる！ やった！ Unix ネットワークプログラマーだ！

## `sendto()` と `recvfrom()`——DGRAM 流に話しかけて {#sendtorecv}

[i[`SOCK_DGRAM` macro]] 「いいのはわかるが、非接続データグラムソケットはどうなる？」 問題ない、相棒。ちょうどいいものがある。

データグラムソケットはリモートホストに接続していないので、パケットを送る前に何が必要か？ そう、宛先アドレスだ！ 概要：

```{.c}
int sendto(int sockfd, const void *msg, int len, unsigned int flags,
           const struct sockaddr *to, socklen_t tolen); 
```

ご覧のとおり、`send()` とほぼ同じで、情報が 2 つ増えている。`to` は宛先 [i[IP
address]] IP アドレスと [i[Port]] ポートを含む `struct sockaddr`（たぶん `struct sockaddr_in`、`struct sockaddr_in6`、`struct sockaddr_storage` のどれかを最後にキャスト）へのポインタ。`tolen` は `int` だが、`sizeof *to` か `sizeof(struct sockaddr_storage)` にすればよい。

宛先アドレス構造体は `getaddrinfo()`、下の `recvfrom()`、または手で詰める。

`send()` と同様、`sendto()` は実際に送ったバイト数（再び指定より少ないことがある）か、エラーで `-1` を返す。

同様に `recv()` と [i[`recvfrom()` function]]
`recvfrom()` も似ている。`recvfrom()` の概要：

```{.c}
int recvfrom(int sockfd, void *buf, int len, unsigned int flags,
             struct sockaddr *from, int *fromlen); 
```

再び `recv()` にフィールドが 2 つ足された形。`from` は送信元マシンの IP アドレスとポートを埋めるローカルの [i[`struct sockaddr` type]] `struct sockaddr_storage` へのポインタ。`fromlen` は `sizeof *from` か `sizeof(struct sockaddr_storage)` で初期化するローカル `int` へのポインタ。関数が返ると `fromlen` には `from` に実際に格納されたアドレス長が入る。

`recvfrom()` は受信バイト数、またはエラーで `-1`（`errno` もセット）を返す。

質問：なぜソケット型に `struct sockaddr_storage` を使う？ `struct sockaddr_in` ではないの？ IPv4 か IPv6 かに縛りたくないから。どちらにも十分大きい汎用の `struct sockaddr_storage` を使う。

（では `struct sockaddr` 自体はなぜどんなアドレスにも足りない？ 汎用の `struct sockaddr_storage` を汎用の `struct sockaddr` にキャストしているのに！ 余計で冗長に見えるだろ？ 答えは、単に足りなくて、今さら変えるのは面倒、という推測だ。だから新しい型が作られた。）

[i[`connect()` function-->on datagram sockets]]
データグラムソケットに `connect()` すれば、その後は単に `send()` と `recv()` だけで取引できる。ソケット自体はデータグラムのままでパケットは UDP だが、ソケットインターフェースが宛先と送信元情報を自動で付けてくれる。


## `close()` と `shutdown()`——あっち行け！

ふう！ 一日中 `send()` と `recv()` して、もう限界だ。ソケットディスクリプタの接続を閉じたい。簡単だ。普通の Unix ファイルディスクリプタ用の [i[`close()` function]] `close()` が使える：

```{.c}
close(sockfd); 
```

ソケットへの読み書きはこれ以上できなくなる。リモート側が読み書きしようとするとエラーになる。

閉じ方をもう少し制御したいなら [i[`shutdown()` function]] `shutdown()` がある。特定方向だけ、または両方向（`close()` と同様）通信を切れる。概要：

```{.c}
int shutdown(int sockfd, int how); 
```

`sockfd` は shutdown したいソケットファイルディスクリプタ。`how` は次のいずれか：

| `how` | 効果                                                     |
|:-----:|------------------------------------------------------------|
|  `0`  | 以降の受信を禁止                                           |
|  `1`  | 以降の送信を禁止                                           |
|  `2`  | 以降の送受信を禁止（`close()` と同様）                     |

`shutdown()` は成功で `0`、エラーで `-1`（`errno` もセット）。

非接続データグラムソケットに `shutdown()` を使うと、単にそのソケットでこれ以上 `send()` と `recv()` できなくなる（データグラムソケットを `connect()` していればこれらは使える）。

`shutdown()` はファイルディスクリプタを実際には閉じない——使える状態だけ変える。ソケットディスクリプタを解放するには `close()` が必要だ。

それだけ。

（[i[Windows]] Windows と [i[Winsock]] Winsock を使うなら [i[`closesocket()` function]]
`closesocket()` を `close()` の代わりに呼ぶことを忘れないで。）


## `getpeername()`——君は誰？

[i[`getpeername()` function]] この関数はとても簡単だ。

簡単すぎて、独立したセクションにするか迷った。でもここにある。

`getpeername()` は接続済みストリームソケットの向こう側が誰か教えてくれる。概要：

```{.c}
#include <sys/socket.h>

int getpeername(int sockfd, struct sockaddr *addr, int *addrlen); 
```

`sockfd` は接続済みストリームソケットのディスクリプタ。`addr` は接続の向こう側の情報を入れる `struct sockaddr`（または `struct sockaddr_in`）へのポインタ。`addrlen` は `sizeof *addr` か `sizeof(struct sockaddr)` で初期化する `int` へのポインタ。

エラーなら `-1`、`errno` をセット。

アドレスがわかれば [i[`inet_ntop()` function]]
`inet_ntop()`、[i[`getnameinfo()` function]] `getnameinfo()`、または
[i[`gethostbyaddr()` function]] `gethostbyaddr()` で表示や追加情報取得ができる。ログイン名は取れない。（向こうのマシンが ident デーモンを動かしていれば可能だが、この文書の範囲外だ。詳細は [flrfc[RFC 1413|1413]] を参照。）


## `gethostname()`——俺は誰？

[i[`gethostname()` function]] `getpeername()` よりさらに簡単なのが `gethostname()` だ。プログラムが動いているコンピュータの名前を返す。その名前を上の [i[`getaddrinfo()`
function]] `getaddrinfo()` に渡せば、ローカルマシンの [i[IP address]] IP アドレスがわかる。

他に何が楽しい？ いくつか思い浮かぶが、ソケットプログラミングとは関係ない。とにかく概要：

```{.c}
#include <unistd.h>

int gethostname(char *hostname, size_t size); 
```

引数はシンプル：`hostname` は関数が返るときにホスト名を入れる char 配列へのポインタ。`size` は `hostname` 配列のバイト長。

成功で `0`、エラーで `-1`、いつものように `errno` をセット。
